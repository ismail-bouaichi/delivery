import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_app/controllers/order_controller.dart';
import 'package:my_app/models/order.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class AllOrdersMapPage extends StatefulWidget {
  const AllOrdersMapPage({Key? key}) : super(key: key);

  @override
  _AllOrdersMapPageState createState() => _AllOrdersMapPageState();
}

class _AllOrdersMapPageState extends State<AllOrdersMapPage> {
  final OrderController _orderController = Get.find<OrderController>(); // Use Get.find instead of Get.put
  final PopupController _popupController = PopupController();
  
  Marker? _userLocationMarker;
  LatLng? _userLocation;
  bool _isLoading = true;
  String _errorMessage = '';
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getUserLocation();
    _startLocationTracking();
  }

  Future<void> _getUserLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      var status = await Permission.location.request();
      if (status.isGranted) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _updateUserLocation(position);
      } else {
        setState(() {
          _errorMessage = 'Location permission denied';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting user location: $e';
        _isLoading = false;
      });
    }
  }

  void _updateUserLocation(Position position) {
    setState(() {
      _userLocation = LatLng(position.latitude, position.longitude);
      _userLocationMarker = Marker(
        point: LatLng(position.latitude, position.longitude),
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(
            Icons.my_location, 
            color: Colors.white, 
            size: 20
          ),
        ),
      );
      _isLoading = false;
    });
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings
    ).listen(
      (Position position) {
        _updateUserLocation(position);
      },
      onError: (e) {
        setState(() {
          _errorMessage = 'Error tracking location: $e';
        });
      },
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Colors.orange;
      case 'onprogress':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  LatLng _calculateMapCenter(List<Order> orders) {
    if (_userLocation != null) {
      return _userLocation!;
    }
    
    if (orders.isNotEmpty) {
      double totalLat = 0;
      double totalLng = 0;
      int validOrdersCount = 0;
      
      for (Order order in orders) {
        if (order.latitude != null && order.longitude != null) {
          totalLat += order.latitude!;
          totalLng += order.longitude!;
          validOrdersCount++;
        }
      }
      
      if (validOrdersCount > 0) {
        return LatLng(totalLat / validOrdersCount, totalLng / validOrdersCount);
      }
    }
    
    // Default location (you can change this to your city)
    return const LatLng(33.5731, -7.5898); // Casablanca, Morocco
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Get.back();
          },
        ),
        title: const Text('All Orders Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _orderController.getOrders();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeMap,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Status Legend
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildLegendItem('Paid', Colors.orange),
                          _buildLegendItem('In Progress', Colors.blue),
                          _buildLegendItem('Your Location', Colors.blue),
                        ],
                      ),
                    ),
                    // Orders Summary - Using GetBuilder instead of Obx
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      child: GetBuilder<OrderController>(
                        builder: (controller) {
                          return Text(
                            'Total Orders: ${controller.orders.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    // Map - Using GetBuilder for proper state management
                    Expanded(
                      child: GetBuilder<OrderController>(
                        builder: (controller) {
                          // Build markers directly in the builder where we have access to observable
                          List<Marker> orderMarkers = [];
                          
                          for (Order order in controller.orders) {
                            if (order.latitude != null && order.longitude != null) {
                              orderMarkers.add(
                                Marker(
                                  point: LatLng(order.latitude!, order.longitude!),
                                  width: 50,
                                  height: 50,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _getOrderStatusColor(order.status),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        order.id.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                          
                          return FlutterMap(
                            options: MapOptions(
                              initialCenter: _calculateMapCenter(controller.orders),
                              initialZoom: 12.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.my_app',
                              ),
                              PopupMarkerLayer(
                                options: PopupMarkerLayerOptions(
                                  popupController: _popupController,
                                  markers: [
                                    ...orderMarkers,
                                    if (_userLocationMarker != null) _userLocationMarker!,
                                  ],
                                  popupDisplayOptions: PopupDisplayOptions(
                                    builder: (BuildContext context, Marker marker) {
                                      if (marker == _userLocationMarker) {
                                        return Card(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: const Text("Your Location"),
                                          ),
                                        );
                                      } else {
                                        // Find the corresponding order
                                        Order? order;
                                        for (Order o in controller.orders) {
                                          if (o.latitude != null && 
                                              o.longitude != null &&
                                              marker.point.latitude == o.latitude &&
                                              marker.point.longitude == o.longitude) {
                                            order = o;
                                            break;
                                          }
                                        }
                                        
                                        if (order != null) {
                                          return OrderMapPopup(order: order);
                                        } else {
                                          return Card(
                                            child: Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child: const Text("Order Details"),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getUserLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }
}

class OrderMapPopup extends StatelessWidget {
  final Order order;

  const OrderMapPopup({Key? key, required this.order}) : super(key: key);

  Future<void> _launchUrl() async {
    final Uri url = Uri.parse('tel:${order.phone}');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 250,
        maxHeight: 300,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Order #${order.id}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('${order.firstName} ${order.lastName}'),
              const SizedBox(height: 4),
              Text('Status: ${order.status}'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text('Phone: ${order.phone}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone, size: 20),
                    onPressed: _launchUrl,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to detailed map page
                      Get.toNamed('/map', arguments: order);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text('Navigate', style: TextStyle(fontSize: 12)),
                  ),
                  Text(
                    '\$${order.shippingCost.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
