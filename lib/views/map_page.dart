import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_app/controllers/order_controller.dart';
import 'package:my_app/models/order.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart'; // Add this import
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';





class MapPage extends StatefulWidget {
  final Order order;

  MapPage({Key? key, required this.order}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final Marker _orderMarker;
  Marker? _userLocationMarker;
  final PopupController _popupController = PopupController();
  bool _isLoading = true;
  String _errorMessage = '';
  late StreamSubscription<Position> _positionStreamSubscription;
  double _distanceToOrder = 0.0;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _orderMarker = Marker(
      point: LatLng(widget.order.latitude ?? 0.0, widget.order.longitude ?? 0.0),
      width: 40,
      height: 40,
      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
    );
    _getUserLocation();
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
        _updateUserMarker(position);
        _startLocationTracking();
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

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _updateUserMarker(position);
      },
      onError: (e) {
        setState(() {
          _errorMessage = 'Error tracking location: $e';
        });
      },
    );
  }

  void _updateUserMarker(Position position) {
    setState(() {
      _userLocationMarker = Marker(
        point: LatLng(position.latitude, position.longitude),
        width: 40,
        height: 40,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
      );
      _isLoading = false;
    });
    _calculateRouteAndDistance(position);
  }

  Future<void> _calculateRouteAndDistance(Position userPosition) async {
    final apiKey = '5b3ce3597851110001cf62488e4d31a4aac44ee7b394bdf45448fd37'; // Replace with your actual API key
    final apiUrl = 'https://api.openrouteservice.org/v2/directions/driving-car';

    final response = await http.get(
      Uri.parse('$apiUrl?api_key=$apiKey&start=${userPosition.longitude},${userPosition.latitude}&end=${widget.order.longitude},${widget.order.latitude}'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final distanceInMeters = data['features'][0]['properties']['segments'][0]['distance'];
      final geometry = data['features'][0]['geometry']['coordinates'];

      setState(() {
        _distanceToOrder = distanceInMeters / 1000; // Convert to kilometers
        _routePoints = geometry.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
      });
    } else {
      print('Failed to calculate route: ${response.statusCode}');
      // Fallback to direct line if API call fails
      _calculateDirectDistanceAndLine(userPosition);
    }
  }

  void _calculateDirectDistanceAndLine(Position userPosition) {
    double distanceInMeters = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      widget.order.latitude ?? 0.0,
      widget.order.longitude ?? 0.0,
    );
    setState(() {
      _distanceToOrder = distanceInMeters / 1000; // Convert to kilometers
      _routePoints = [
        LatLng(userPosition.latitude, userPosition.longitude),
        LatLng(widget.order.latitude ?? 0.0, widget.order.longitude ?? 0.0),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order.id} Location'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Distance to order: ${_distanceToOrder.toStringAsFixed(2)} km',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(widget.order.latitude ?? 0.0, widget.order.longitude ?? 0.0),
                          initialZoom: 13.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.my_app',
                          ),
                          if (_routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: Colors.blue,
                                  strokeWidth: 4.0,
                                ),
                              ],
                            ),
                          PopupMarkerLayer(
                            options: PopupMarkerLayerOptions(
                              popupController: _popupController,
                              markers: [_orderMarker, if (_userLocationMarker != null) _userLocationMarker!],
                              popupDisplayOptions: PopupDisplayOptions(
                                builder: (BuildContext context, Marker marker) {
                                  if (marker == _orderMarker) {
                                    return OrderPopup(order: widget.order);
                                  } else {
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text("Your Location"),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                onTap: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getUserLocation,
        child: Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription.cancel();
    super.dispose();
  }
}
class OrderPopup extends StatelessWidget {
  final Order order;

  const OrderPopup({Key? key, required this.order}) : super(key: key);

  Future<void> _launchUrl() async {
    final Uri _url = Uri.parse('tel:${order.phone}');
    if (!await launchUrl(_url)) {
      throw Exception('Could not launch $_url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 300, // Maximum width of the popup
        maxHeight: 400, // Maximum height of the popup
      ),
      child: Card(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Order #${order.id}', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: 8),
                Text('Name: ${order.firstName} ${order.lastName}', style: Theme.of(context).textTheme.bodyMedium),
                SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Phone: ${order.phone}', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _launchUrl,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text('Call'),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text('Address: ${order.email}', style: Theme.of(context).textTheme.bodyMedium),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Scan:', style: Theme.of(context).textTheme.titleMedium),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BarcodeScannerPage(),
                          ),
                        );
                      },
                      icon: Icon(Icons.qr_code_scanner, size: 18),
                      label: Text('Scan QR Code', style: TextStyle(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({Key? key}) : super(key: key);

  @override
  _BarcodeScannerPageState createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  final OrderController _orderController = Get.find<OrderController>();
  bool isFlashOn = false;
  double zoomLevel = 0.0;
  final GlobalKey _scannerKey = GlobalKey();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scane')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            key: _scannerKey,
            controller: cameraController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Stack(
                children: [
                  Positioned(top: 0, left: 0, child: _cornerBox()),
                  Positioned(top: 0, right: 0, child: _cornerBox()),
                  Positioned(bottom: 0, left: 0, child: _cornerBox()),
                  Positioned(bottom: 0, right: 0, child: _cornerBox()),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      isFlashOn = !isFlashOn;
                      cameraController.toggleTorch();
                    });
                  },
                ),
                Expanded(
                  child: Slider(
                    value: zoomLevel,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      setState(() {
                        zoomLevel = value;
                        cameraController.setZoomScale(value);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final List<Barcode> barcodes = capture.barcodes;
      for (final barcode in barcodes) {
        if (true /* _isBarcodeInsideSquare(barcode) */) {
          await _handleValidBarcode(barcode.rawValue);
          break;  // Process only the first valid barcode
        }
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleValidBarcode(String? barcodeValue) async {
    if (barcodeValue != null) {
      debugPrint('Valid barcode found inside square: $barcodeValue');
      
      String? orderId = _parseOrderId(barcodeValue);
      
      if (orderId != null) {
        Fluttertoast.showToast(
          msg: "Attempting to complete order: $orderId",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0
        );
        
        bool success = await _orderController.completeOrder(orderId);
        
        if (success) {
          await cameraController.stop();
          Get.offNamed('/orders');
        } else {

          // If completion fails, allow scanning to continue
          setState(() {
            _isProcessing = false;
            
          });
         

        }
      } else {
        setState(() {
          _isProcessing = false;
        });
         await cameraController.stop();
          Get.offNamed('/orders');
                     Get.snackbar('Error', 'Invalid QR code format');
      }
    }
  }

  String? _parseOrderId(String qrCodeData) {
    RegExp regExp = RegExp(r'^order/(\d+)/customer//date/');
    Match? match = regExp.firstMatch(qrCodeData);
    
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    
    return null;
  }

  Widget _cornerBox() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.blue, width: 4),
          left: BorderSide(color: Colors.blue, width: 4),
        ),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}