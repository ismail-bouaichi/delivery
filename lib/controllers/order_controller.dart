import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/constants/constant.dart';
import 'package:my_app/controllers/worker_controller.dart';
import 'package:my_app/models/order.dart';
import 'package:my_app/services/location_tracking_service.dart';

class OrderController extends GetxController {
  final orders = <Order>[].obs;
  final status = RxStatus.empty().obs;
  final box = GetStorage();
  final isLoading = false.obs;
  final Set<String> _processingOrders = <String>{};

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${box.read('token')}',
      };

  @override
  void onInit() {
    getOrders();
    super.onInit();
  }

  /// GET /api/delivery-worker/orders — orders assigned to this worker
  /// (status: paid or on_progress).
  Future<void> getOrders() async {
    try {
      status.value = RxStatus.loading();

      final response = await http.get(
        Uri.parse('${url}delivery-worker/orders'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List content =
            decoded is List ? decoded : (decoded['orders'] ?? []);
        orders.assignAll(
            content.map<Order>((item) => Order.fromJson(item)).toList());
        status.value = RxStatus.success();

        // If an order is already on_progress (e.g. app restarted mid-delivery),
        // resume GPS tracking for it.
        Order? active;
        for (final o in orders) {
          if (o.isInProgress) {
            active = o;
            break;
          }
        }
        final tracker = Get.find<LocationTrackingService>();
        if (active != null && !tracker.isTracking.value) {
          tracker.start(active.id);
        }
      } else if (response.statusCode == 401) {
        _handleUnauthorized();
      } else {
        status.value = RxStatus.error('Failed to load orders');
        print(response.body);
      }
    } catch (e) {
      status.value = RxStatus.error('An error occurred: ${e.toString()}');
      print(e.toString());
    }
  }

  /// POST /api/delivery-worker/orders/{orderId} — accept an order.
  /// Moves the order to on_progress, sets the worker to on_delivery,
  /// and starts the GPS tracking loop.
  Future<bool> acceptOrder(int orderId) async {
    try {
      isLoading.value = true;
      final response = await http.post(
        Uri.parse('${url}delivery-worker/orders/$orderId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        Get.snackbar('Accepted', 'Order #$orderId is now in progress');

        // Worker is now delivering.
        Get.find<WorkerController>().setStatus(WorkerStatus.onDelivery);

        // Start sending GPS to the backend.
        await Get.find<LocationTrackingService>().start(orderId);

        await getOrders();
        return true;
      }
      if (response.statusCode == 401) {
        _handleUnauthorized();
        return false;
      }
      final body = _safeDecode(response.body);
      Get.snackbar('Error', body?['message'] ?? 'Could not accept the order');
      return false;
    } catch (e) {
      Get.snackbar('Error', 'An error occurred while accepting the order');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// POST /api/delivery-worker/orders/complete/{orderId} — mark delivered.
  /// Backend sets order -> complete, fulfillment -> delivered, generates the
  /// invoice, and emails the customer. We stop GPS and free the worker.
  Future<bool> completeOrder(String orderId) async {
    if (_processingOrders.contains(orderId)) {
      print('Order $orderId is already being processed');
      return false;
    }

    _processingOrders.add(orderId);
    try {
      isLoading.value = true;

      final response = await http.post(
        Uri.parse('${url}delivery-worker/orders/complete/$orderId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final responseBody = _safeDecode(response.body);
        final newStatus = responseBody?['status'] ??
            responseBody?['order']?['status'];

        if (newStatus == 'complete' || responseBody?['success'] == true) {
          Get.snackbar('Success',
              responseBody?['message'] ?? 'Order delivered successfully');
          await _finishDelivery();
          return true;
        }
        Get.snackbar('Error', 'Unexpected response from server');
        return false;
      } else if (response.statusCode == 401) {
        _handleUnauthorized();
        return false;
      } else {
        final responseBody = _safeDecode(response.body);
        Get.snackbar(
            'Error', responseBody?['message'] ?? 'Failed to complete order');
        return false;
      }
    } catch (e) {
      print('Error: ${e.toString()}');
      Get.snackbar('Error', 'An error occurred while completing the order');
      return false;
    } finally {
      isLoading.value = false;
      _processingOrders.remove(orderId);
    }
  }

  /// Mark a delivery as failed with a reason so admins can redispatch.
  ///
  /// NOTE: the API doc only documents fail on the admin side
  /// (POST /api/admin/delivery-orders/{id}/fail). This calls the equivalent
  /// worker route — if the backend hasn't exposed it yet, it needs:
  ///   POST /api/delivery-worker/orders/fail/{orderId}  { "reason": "..." }
  Future<bool> failOrder(int orderId, String reason) async {
    try {
      isLoading.value = true;
      final response = await http.post(
        Uri.parse('${url}delivery-worker/orders/fail/$orderId'),
        headers: _headers,
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        Get.snackbar('Marked failed', 'The dispatcher can now redispatch it');
        await _finishDelivery();
        return true;
      }
      if (response.statusCode == 401) {
        _handleUnauthorized();
        return false;
      }
      if (response.statusCode == 404) {
        Get.snackbar('Not available',
            'Failed-delivery endpoint is missing on the backend — ask an admin to mark it failed');
        return false;
      }
      final body = _safeDecode(response.body);
      Get.snackbar('Error', body?['message'] ?? 'Could not mark as failed');
      return false;
    } catch (e) {
      Get.snackbar('Error', 'An error occurred');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Common cleanup after a delivery ends (delivered or failed):
  /// stop GPS, set worker back to available, refresh the list.
  Future<void> _finishDelivery() async {
    await Get.find<LocationTrackingService>().stop();
    Get.find<WorkerController>().setStatus(WorkerStatus.available);
    await getOrders();
  }

  Map<String, dynamic>? _safeDecode(String body) {
    try {
      final decoded = json.decode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  void _handleUnauthorized() {
    box.remove('token');
    box.remove('delivery_worker_id');
    Get.offAllNamed('/login');
    Get.snackbar('Session expired', 'Please log in again');
  }
}
