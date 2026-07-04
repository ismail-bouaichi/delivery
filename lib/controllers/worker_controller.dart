import 'dart:convert';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/constants/constant.dart';

/// Delivery-worker status values understood by the backend.
class WorkerStatus {
  static const available = 'available';
  static const onDelivery = 'on_delivery';
  static const offline = 'offline';
}

class WorkerController extends GetxController {
  final box = GetStorage();

  final profile = Rxn<Map<String, dynamic>>();
  final status = ''.obs;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${box.read('token')}',
      };

  int? get workerId => box.read('delivery_worker_id');

  @override
  void onInit() {
    super.onInit();
    if (box.read('token') != null) {
      fetchProfile().then((_) => setStatus(WorkerStatus.available));
    }
  }

  /// GET /api/delivery-worker/me — worker profile, status, current order.
  Future<void> fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${url}delivery-worker/me'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final worker = data['delivery_worker'] ?? data['worker'] ?? data;
        profile.value = Map<String, dynamic>.from(worker);
        if (worker['id'] != null) {
          box.write('delivery_worker_id', worker['id']);
        }
        if (worker['status'] != null) status.value = worker['status'];
      } else if (response.statusCode == 401) {
        _handleUnauthorized();
      }
    } catch (e) {
      print('fetchProfile error: $e');
    }
  }

  /// PUT /api/delivery-worker/{id}/status
  /// Call with: available (app opened / delivery done),
  /// on_delivery (order accepted), offline (logout / shift end).
  Future<bool> setStatus(String newStatus) async {
    final id = workerId;
    if (id == null) {
      // Profile not loaded yet — try once, then retry.
      await fetchProfile();
      if (workerId == null) return false;
    }
    try {
      final response = await http.put(
        Uri.parse('${url}delivery-worker/${workerId}/status'),
        headers: _headers,
        body: json.encode({'status': newStatus}),
      );
      if (response.statusCode == 200) {
        status.value = newStatus;
        return true;
      }
      if (response.statusCode == 401) _handleUnauthorized();
      print('setStatus failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      print('setStatus error: $e');
      return false;
    }
  }

  /// GET /api/delivery-worker/verify-order/{orderId}
  /// Confirms the authenticated worker is assigned to the order.
  Future<bool> verifyOrderAssignment(int orderId) async {
    try {
      final response = await http.get(
        Uri.parse('${url}delivery-worker/verify-order/$orderId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _handleUnauthorized() {
    box.remove('token');
    box.remove('delivery_worker_id');
    Get.offAllNamed('/login');
    Get.snackbar('Session expired', 'Please log in again');
  }
}
