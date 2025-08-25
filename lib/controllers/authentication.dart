import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:my_app/constants/constant.dart';
import 'package:get_storage/get_storage.dart';
import 'package:my_app/views/login_page.dart';
import 'package:my_app/models/user.dart';

class AuthenticationController extends GetxController {

  final isLoading=false.obs;
  final token=''.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final box=GetStorage();

  @override
  void onInit() {
    super.onInit();
    // Try to load user data if token exists
    final savedToken = box.read('token');
    if (savedToken != null) {
      token.value = savedToken;
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final response = await http.get(
        Uri.parse('${url}user/profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${token.value}',
        },
      );
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        currentUser.value = User.fromJson(userData['user'] ?? userData);
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future register({required String name,required String email,required String username,required String password})async{
    
   try {
      isLoading.value=true;
    var data={
      'name':name,
      'username':username,
       'email':email,
      'password':password,
    };
    var response = await http.post(
      Uri.parse('${url}register_delivery'),
      headers: {
        'Accept':'application/json',
      },
      body: data,
    );

    if (response.statusCode==200) {
    isLoading.value=false;
       token.value=json.decode(response.body)['token'];
    box.write('token', token.value);
    
    // Load user data if available in the response
    final responseData = json.decode(response.body);
    if (responseData['user'] != null) {
      currentUser.value = User.fromJson(responseData['user']);
    } else {
      // Load user data with a separate call
      await _loadUserData();
    }
    
    Get.toNamed('/home');
    }else{
       isLoading.value=false;
       Get.snackbar(
        'Error',
        json.decode(response.body)['message'],
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white
       );
       print(json.decode(response.body));
    }
   } catch (e) {
    isLoading.value=false;
     print(e.toString());
   }
  }

 Future login({required String email, required String password}) async {
  try {
    isLoading.value = true;
    var data = {
      'email': email,
      'password': password,
    };
    var response = await http.post(
      Uri.parse('${url}login_delivery'),
      headers: {
        'Accept': 'application/json',
      },
      body: data,
    );

    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.body.isNotEmpty) {
      var decodedResponse = json.decode(response.body);
      if (response.statusCode == 200) {
        token.value = decodedResponse['token'];
        box.write('token', token.value);
        
        // Load user data if available in the response
        if (decodedResponse['user'] != null) {
          currentUser.value = User.fromJson(decodedResponse['user']);
        } else {
          // Load user data with a separate call
          await _loadUserData();
        }
        
        Get.toNamed('/home');
      } else {
        Get.snackbar(
          'Error',
          decodedResponse['message'] ?? 'An error occurred',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white
        );
      }
    } else {
      Get.snackbar(
        'Error',
        'Empty response from server',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white
      );
    }
  } catch (e) {
    print('Error: ${e.toString()}');
    Get.snackbar(
      'Error',
      'An unexpected error occurred',
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.red,
      colorText: Colors.white
    );
  } finally {
    isLoading.value = false;
  }
}
  Future<void> logout() async {
    try {
      // Clear the token from storage
      await box.remove('token');
      
      // Reset the token and user values in the controller
      token.value = '';
      currentUser.value = null;

      // Redirect to the login page
      Get.offAll(() => const LoginPage()); // Replace LoginPage with your actual login page widget
    } catch (e) {
      print('Logout error: ${e.toString()}');
      Get.snackbar(
        'Error',
        'Failed to logout. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white
      );
    }
  }
  
}
