import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_app/constants/constant.dart';
import 'package:my_app/controllers/order_controller.dart';
import 'package:my_app/models/order.dart';
import 'package:my_app/services/location_tracking_service.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
  final OrderController _orderController = Get.find<OrderController>();
  final LocationTrackingService _tracker = Get.find<LocationTrackingService>();

  bool _isLoading = true;
  String _errorMessage = '';
  StreamSubscription<Position>? _positionStreamSubscription;
  double _distanceToOrder = 0.0;
  List<LatLng> _routePoints = [];

  /// Local copy so the buttons update after accept/complete/fail.
  late String _status;

  @override
  void initState() {
    super.initState();
    _status = widget.order.status;
    _orderMarker = Marker(
      point:
          LatLng(widget.order.latitude ?? 0.0, widget.order.longitude ?? 0.0),
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
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
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
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(
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
    // No ORS key configured -> fall back to a straight line.
    if (orsApiKey.isEmpty) {
      _calculateDirectDistanceAndLine(userPosition);
      return;
    }

    const apiUrl = 'https://api.openrouteservice.org/v2/directions/driving-car';

    try {
      final response = await http.get(
        Uri.parse(
            '$apiUrl?api_key=$orsApiKey&start=${userPosition.longitude},${userPosition.latitude}&end=${widget.order.longitude},${widget.order.latitude}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final distanceInMeters =
            data['features'][0]['properties']['segments'][0]['distance'];
        final geometry = data['features'][0]['geometry']['coordinates'];

        setState(() {
          _distanceToOrder = distanceInMeters / 1000;
          _routePoints = geometry
              .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
              .toList();
        });
      } else {
        _calculateDirectDistanceAndLine(userPosition);
      }
    } catch (_) {
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
      _distanceToOrder = distanceInMeters / 1000;
      _routePoints = [
        LatLng(userPosition.latitude, userPosition.longitude),
        LatLng(widget.order.latitude ?? 0.0, widget.order.longitude ?? 0.0),
      ];
    });
  }

  // ---------------------------------------------------------------------
  // Delivery actions
  // ---------------------------------------------------------------------

  Future<void> _acceptOrder() async {
    final ok = await _orderController.acceptOrder(widget.order.id);
    if (ok && mounted) {
      setState(() => _status = OrderStatus.onProgress);
    }
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BarcodeScannerPage(orderId: widget.order.id),
      ),
    );
  }

  Future<void> _markFailed() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark delivery as failed'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Customer unreachable, wrong address…',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark failed'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = reasonController.text.trim().isEmpty
          ? 'Delivery failed'
          : reasonController.text.trim();
      final ok = await _orderController.failOrder(widget.order.id, reason);
      if (ok && mounted) Get.offAllNamed('/orders');
    }
  }

  Widget _buildActionBar() {
    if (_status == OrderStatus.paid) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Accept order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _acceptOrder,
            ),
          ),
        ),
      );
    }

    if (_status == OrderStatus.onProgress) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _openScanner,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Failed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _markFailed,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.order.id} Location'),
        actions: [
          // Live indicator when GPS is being sent to the backend.
          Obx(() => _tracker.isTracking.value &&
                  _tracker.activeOrderId.value == widget.order.id
              ? const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.gps_fixed, color: Colors.green),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Distance to order: ${_distanceToOrder.toStringAsFixed(2)} km',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(widget.order.latitude ?? 0.0,
                              widget.order.longitude ?? 0.0),
                          initialZoom: 13.0,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                              markers: [
                                _orderMarker,
                                if (_userLocationMarker != null)
                                  _userLocationMarker!
                              ],
                              popupDisplayOptions: PopupDisplayOptions(
                                builder:
                                    (BuildContext context, Marker marker) {
                                  if (marker == _orderMarker) {
                                    return OrderPopup(order: widget.order);
                                  } else {
                                    return const Card(
                                      child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text('Your Location'),
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
                    _buildActionBar(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getUserLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    // Only cancels the map's local stream — the background upload loop in
    // LocationTrackingService keeps running until the delivery ends.
    _positionStreamSubscription?.cancel();
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
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
      child: Card(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Order #${order.id}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Name: ${order.firstName} ${order.lastName}',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('Phone: ${order.phone}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _launchUrl,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                      child: const Text('Call'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Address: ${order.fullAddress}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BarcodeScannerPage extends StatefulWidget {
  /// The order the driver is delivering. The scanned QR must match it.
  final int? orderId;

  const BarcodeScannerPage({Key? key, this.orderId}) : super(key: key);

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
      appBar: AppBar(title: const Text('Scan package QR')),
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
    setState(() => _isProcessing = true);

    try {
      final List<Barcode> barcodes = capture.barcodes;
      for (final barcode in barcodes) {
        await _handleValidBarcode(barcode.rawValue);
        break;
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleValidBarcode(String? barcodeValue) async {
    if (barcodeValue == null) return;

    final orderId = _parseOrderId(barcodeValue);
    if (orderId == null) {
      Fluttertoast.showToast(
        msg: 'Unrecognized QR code',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    // Guard: the scanned package must belong to the current order.
    if (widget.orderId != null && orderId != widget.orderId.toString()) {
      Fluttertoast.showToast(
        msg: 'This QR belongs to order #$orderId, not #${widget.orderId}',
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    Fluttertoast.showToast(
      msg: 'Completing order #$orderId…',
      backgroundColor: Colors.green,
      textColor: Colors.white,
    );

    final success = await _orderController.completeOrder(orderId);
    if (success) {
      await cameraController.stop();
      Get.offAllNamed('/orders');
    }
  }

  /// Accepts plain ids ("42"), order numbers, or JSON payloads
  /// like {"order_id": 42}.
  String? _parseOrderId(String value) {
    final trimmed = value.trim();
    if (int.tryParse(trimmed) != null) return trimmed;
    try {
      final decoded = json.decode(trimmed);
      if (decoded is Map && decoded['order_id'] != null) {
        return decoded['order_id'].toString();
      }
      if (decoded is Map && decoded['id'] != null) {
        return decoded['id'].toString();
      }
    } catch (_) {}
    final match = RegExp(r'(\d+)').firstMatch(trimmed);
    return match?.group(1);
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
