import 'dart:convert';

List<Order> ordersFromJson(String str) {
  final decoded = json.decode(str);
  final list = decoded is List ? decoded : (decoded['orders'] ?? []);
  return List<Order>.from(list.map((x) => Order.fromJson(x)));
}

/// Order statuses used by the backend delivery-worker API:
///   paid         -> assigned, waiting for the driver to accept
///   on_progress  -> accepted, driver is delivering
///   complete     -> delivered
class OrderStatus {
  static const paid = 'paid';
  static const onProgress = 'on_progress';
  static const complete = 'complete';
}

class Order {
  final int id;
  final String firstName;
  final String lastName;
  final String? email;
  final String phone;
  final String status;
  final String? address;
  final String? city;
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final double shippingCost;
  final List<OrderDetail> orderDetails;

  Order({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    required this.phone,
    required this.status,
    this.address,
    this.city,
    this.zipCode,
    this.latitude,
    this.longitude,
    this.shippingCost = 0,
    this.orderDetails = const [],
  });

  bool get isPending => status == OrderStatus.paid;
  bool get isInProgress => status == OrderStatus.onProgress;
  bool get isComplete => status == OrderStatus.complete;

  /// Human-readable delivery address, built from whatever the API sent.
  String get fullAddress {
    final parts = [address, city, zipCode]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.join(', ');
    // Fall back to address stored on the first order detail (older API shape).
    if (orderDetails.isNotEmpty) {
      final d = orderDetails.first;
      final dParts = [d.address, d.city, d.zipCode]
          .where((p) => p != null && p.trim().isNotEmpty)
          .toList();
      if (dParts.isNotEmpty) return dParts.join(', ');
    }
    return 'No address';
  }

  static double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  factory Order.fromJson(Map<String, dynamic> json) {
    // The API doc uses "orderDetails"; some responses use "order_details".
    final rawDetails =
        (json['orderDetails'] ?? json['order_details'] ?? []) as List;
    return Order(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'],
      phone: json['phone']?.toString() ?? '',
      status: json['status'] ?? '',
      address: json['address'],
      city: json['city'],
      zipCode: json['zip_code'],
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      shippingCost: _toDouble(json['shipping_cost']) ?? 0,
      orderDetails: rawDetails
          .map<OrderDetail>((x) => OrderDetail.fromJson(x))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'status': status,
        'address': address,
        'city': city,
        'zip_code': zipCode,
        'latitude': latitude,
        'longitude': longitude,
        'shipping_cost': shippingCost.toStringAsFixed(2),
        'order_details':
            List<dynamic>.from(orderDetails.map((x) => x.toJson())),
      };
}

class OrderDetail {
  final int? id;
  final int? orderId;
  final int productId;
  final double totalPrice;

  /// Quantity — API doc calls this "amount", older shape calls it "quantity".
  final int quantity;
  final String? city;
  final String? address;
  final String? zipCode;

  OrderDetail({
    this.id,
    this.orderId,
    required this.productId,
    required this.totalPrice,
    required this.quantity,
    this.city,
    this.address,
    this.zipCode,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) => OrderDetail(
        id: json['id'],
        orderId: json['order_id'],
        productId: json['product_id'],
        totalPrice: Order._toDouble(json['total_price']) ?? 0,
        quantity: json['amount'] ?? json['quantity'] ?? 0,
        city: json['city'],
        address: json['address'],
        zipCode: json['zip_code'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'total_price': totalPrice.toStringAsFixed(2),
        'quantity': quantity,
        'city': city,
        'address': address,
        'zip_code': zipCode,
      };
}
