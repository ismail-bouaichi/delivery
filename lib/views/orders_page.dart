import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:my_app/controllers/order_controller.dart';
import 'package:my_app/models/order.dart';

class OrdersPage extends StatelessWidget {
  final OrderController orderController = Get.put(OrderController());

  OrdersPage({Key? key}) : super(key: key);

  Color _statusColor(String status) {
    switch (status) {
      case OrderStatus.paid:
        return Colors.orange;
      case OrderStatus.onProgress:
        return Colors.blue;
      case OrderStatus.complete:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case OrderStatus.paid:
        return 'New';
      case OrderStatus.onProgress:
        return 'Delivering';
      case OrderStatus.complete:
        return 'Delivered';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: Obx(() {
        if (orderController.status.value.isLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (orderController.status.value.isError) {
          return Center(
              child: Text(
                  'Error: ${orderController.status.value.errorMessage}'));
        } else if (orderController.orders.isEmpty) {
          return const Center(child: Text('No orders assigned'));
        }

        return RefreshIndicator(
          onRefresh: orderController.getOrders,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: orderController.orders.length,
            itemBuilder: (context, index) {
              final order = orderController.orders[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('Order #${order.id} — '
                      '${order.firstName} ${order.lastName}'),
                  subtitle: Text(order.fullAddress),
                  trailing: order.isPending
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () =>
                              orderController.acceptOrder(order.id),
                          child: const Text('Accept'),
                        )
                      : Chip(
                          label: Text(
                            _statusLabel(order.status),
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _statusColor(order.status),
                        ),
                  onTap: () => Get.toNamed('/map', arguments: order),
                ),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh),
        onPressed: orderController.getOrders,
      ),
    );
  }
}
