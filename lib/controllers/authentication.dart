import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:my_app/constants/constant.dart';
import 'package:get_storage/get_storage.dart';
import 'package:my_app/controllers/worker_controller.dart';
import 'package:my_app/models/user.dart';
import 'package:my_app/services/location_tracking_service.dart';

class AuthenticationController extends GetxController {
  final isLoading = false.obs;
  final token = ''.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final box = GetStorage();

  @override
  void onInit() {
    super.onInit();
    final savedToken = box.read('token');
    if (savedToken != null) {
      token.value = savedToken;
      _loadUserData();
    }
  }

  /// GET /api/delivery-worker/me — profile of the authenticated worker.
  Future<void> _loadUserData() async {
    try {
      final response = await http.get(
        Uri.parse('${url}delivery-worker/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${token.value}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['user'] != null) {
          currentUser.value = User.fromJson(data['user']);
        }
        final worker = data['delivery_worker'] ?? data['worker'];
        if (worker != null && worker['id'] != null) {
          box.write('delivery_worker_id', worker['id']);
        }
      } else if (response.statusCode == 401) {
        await box.remove('token');
        token.value = '';
        Get.offAllNamed('/login');
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _storeSession(Map<String, dynamic> data) {
    token.value = data['token'];
    box.write('token', token.value);

    if (data['user'] != null) {
      currentUser.value = User.fromJson(data['user']);
    }
    // The API returns the delivery_worker record on login/register —
    // its id is required for status updates and GPS payloads.
    final worker = data['delivery_worker'] ?? data['worker'];
    if (worker != null && worker['id'] != null) {
      box.write('delivery_worker_id', worker['id']);
    }
  }

  /// POST /api/register_delivery
  /// Required by the backend: name, email, password, phone, vehicle_type.
  Future register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String vehicleType,
  }) async {
    try {
      isLoading.value = true;
      final response = await http.post(
        Uri.parse('${url}register_delivery'),
        headers: {'Accept': 'application/json'},
        body: {
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'vehicle_type': vehicleType,
        },
      );

      final decoded = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _storeSession(decoded);
        if (currentUser.value == null) await _loadUserData();
        Get.find<WorkerController>().setStatus(WorkerStatus.available);
        Get.offAllNamed('/home');
      } else {
        Get.snackbar(
          'Error',
          decoded['message'] ?? 'Registration failed',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        print(decoded);
      }
    } catch (e) {
      print(e.toString());
      Get.snackbar('Error', 'An unexpected error occurred',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// POST /api/login_delivery
  Future login({required String email, required String password}) async {
    try {
      isLoading.value = true;
      final response = await http.post(
        Uri.parse('${url}login_delivery'),
        headers: {'Accept': 'application/json'},
        body: {'email': email, 'password': password},
      );

      if (response.body.isNotEmpty) {
        final decoded = json.decode(response.body);
        if (response.statusCode == 200) {
          _storeSession(decoded);
          if (currentUser.value == null) await _loadUserData();
          // Driver just opened a session -> available.
          Get.find<WorkerController>().setStatus(WorkerStatus.available);
          Get.offAllNamed('/home');
        } else {
          Get.snackbar(
            'Error',
            decoded['message'] ?? 'An error occurred',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      } else {
        Get.snackbar('Error', 'Empty response from server',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red,
            colorText: Colors.white);
      }
    } catch (e) {
      print('Error: ${e.toString()}');
      Get.snackbar('Error', 'An unexpected error occurred',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      // Best effort: mark the worker offline and stop any GPS loop
      // before dropping the token.
      await Get.find<LocationTrackingService>().stop();
      await Get.find<WorkerController>().setStatus(WorkerStatus.offline);

      await box.remove('token');
      await box.remove('delivery_worker_id');
      token.value = '';
      currentUser.value = null;

      Get.offAllNamed('/login');
    } catch (e) {
      print('Logout error: ${e.toString()}');
      Get.snackbar('Error', 'Failed to logout. Please try again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white);
    }
  }
}
