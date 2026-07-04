import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/constants/constant.dart';

/// Sends the driver's GPS position to the backend every [interval]
/// while a delivery is in progress, as required by the API:
///
///   POST /api/delivery-worker/location
///   { order_id, delivery_worker_id, latitude, longitude,
///     accuracy, speed, heading }
///
/// Uses an Android foreground service (via geolocator) so tracking keeps
/// running when the app is in the background.
class LocationTrackingService extends GetxService {
  static LocationTrackingService get to => Get.find();

  final box = GetStorage();

  final isTracking = false.obs;
  final activeOrderId = RxnInt();

  Timer? _timer;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;

  static const Duration interval = Duration(seconds: 8);

  /// Start tracking for [orderId]. Returns false if permissions were denied.
  Future<bool> start(int orderId) async {
    if (isTracking.value && activeOrderId.value == orderId) return true;
    await stop();

    final hasPermission = await _ensurePermissions();
    if (!hasPermission) return false;

    activeOrderId.value = orderId;
    isTracking.value = true;

    // Keep a fresh position via a stream. On Android this runs a
    // foreground service so it survives backgrounding the app.
    final settings = _platformSettings();
    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) => _lastPosition = pos, onError: (_) {});

    // Send immediately, then on a fixed cadence.
    await _sendCurrentPosition(orderId);
    _timer = Timer.periodic(interval, (_) => _sendCurrentPosition(orderId));
    return true;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _positionSub?.cancel();
    _positionSub = null;
    _lastPosition = null;
    isTracking.value = false;
    activeOrderId.value = null;
  }

  LocationSettings _platformSettings() {
    if (GetPlatform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: interval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Delivery in progress',
          notificationText: 'Sharing your location with the customer',
          enableWakeLock: true,
        ),
      );
    }
    if (GetPlatform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  Future<bool> _ensurePermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      Get.snackbar('Location', 'Please enable location services');
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      Get.snackbar('Location', 'Location permission is required for tracking');
      return false;
    }
    return true;
  }

  Future<void> _sendCurrentPosition(int orderId) async {
    try {
      final pos = _lastPosition ??
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final workerId = box.read('delivery_worker_id');
      final token = box.read('token');
      if (token == null) return;

      final response = await http.post(
        Uri.parse('${url}delivery-worker/location'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'order_id': orderId,
          if (workerId != null) 'delivery_worker_id': workerId,
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'accuracy': pos.accuracy,
          'speed': pos.speed,
          'heading': pos.heading,
        }),
      );

      // 403 => worker not assigned to this order; stop hammering the API.
      if (response.statusCode == 403) {
        await stop();
        Get.snackbar('Tracking stopped', 'You are not assigned to this order');
      }
    } catch (_) {
      // Network hiccups are expected on the road — just try again next tick.
    }
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
