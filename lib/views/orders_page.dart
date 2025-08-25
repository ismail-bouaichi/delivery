import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_app/controllers/order_controller.dart';
import 'package:my_app/views/main_layout.dart';

class OrdersPage extends StatelessWidget {
  final OrderController orderController = Get.put(OrderController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Orders'),
      ),
      body: Obx(() {
        if (orderController.status.value.isLoading) {
          return Center(child: CircularProgressIndicator());
        } else if (orderController.status.value.isError) {
          return Center(child: Text('Error: ${orderController.status.value.errorMessage}'));
        } else if (orderController.orders.isEmpty) {
          return Center(child: Text('No orders found'));
        } else {
          return ListView.builder(
            itemCount: orderController.orders.length,
            itemBuilder: (context, index) {
              final order = orderController.orders[index];
              return ListTile(
                title: Text('Order #${order.id}'),
                subtitle: Text('${order.firstName} ${order.lastName}'),
                trailing: Text(order.status),
                onTap: () {
                  Get.toNamed('/map', arguments: order);
                },
              );
            },
          );
        }
      }),
       floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: orderController.getOrders,
      ),
    );
  }
}