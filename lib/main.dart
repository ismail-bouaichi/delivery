import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:my_app/controllers/worker_controller.dart';
import 'package:my_app/routes/app_routes.dart';
import 'package:my_app/services/location_tracking_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // App-wide services: GPS tracking loop + worker status/profile.
  Get.put(LocationTrackingService(), permanent: true);
  Get.put(WorkerController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final box = GetStorage();
    final token = box.read('token');
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Delivery App',
      initialRoute: token == null ? '/login' : '/home',
      getPages: AppRoutes.routes,
    );
  }
}
