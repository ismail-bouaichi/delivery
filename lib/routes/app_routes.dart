import 'package:get/get.dart';
import 'package:my_app/views/home.dart';
import 'package:my_app/views/login_page.dart';
import 'package:my_app/views/map_page.dart';
import 'package:my_app/views/all_orders_map.dart';
import 'package:my_app/views/orders_page.dart';
import 'package:my_app/views/profile_page.dart';
import 'package:my_app/views/register_page.dart';
import 'package:my_app/models/order.dart';

class AppRoutes {
  static final routes = [
    GetPage(
      name: '/login',
      page: () => LoginPage(),
    ),
    GetPage(
      name: '/register',
      page: () => RegisterPage(),
    ),
    GetPage(
      name: '/home',
      page: () => HomePage(),
    ),
    GetPage(
      name: '/orders',
      page: () => OrdersPage(),
    ),
    GetPage(
      name: '/all-orders-map',
      page: () => AllOrdersMapPage(),
    ),
    GetPage(
      name: '/profile',
      page: () {
        final userId = Get.arguments as int;
        return ProfilePage(userId: userId);
      },
    ),
    GetPage(
      name: '/map',
      page: () {
        final order = Get.arguments as Order;
        return MapPage(order: order);
      },
    ),
  ];
}