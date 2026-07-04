# Changes — wiring the app to the GT Management delivery API

## New files
- `lib/services/location_tracking_service.dart` — GPS upload loop. POSTs to
  `delivery-worker/location` every 8s (order_id, worker_id, lat, lng, accuracy,
  speed, heading) using an Android foreground service / iOS background mode so
  it survives backgrounding. Auto-stops on 403 (not assigned).
- `lib/controllers/worker_controller.dart` — `delivery-worker/me` profile,
  `PUT delivery-worker/{id}/status` (available / on_delivery / offline),
  `verify-order/{id}`.

## Rewritten
- `lib/controllers/order_controller.dart` — added `acceptOrder()`
  (POST `delivery-worker/orders/{id}` → sets worker on_delivery + starts GPS),
  `failOrder(id, reason)`, cleanup after complete/fail (stop GPS, worker back
  to available), resumes tracking on app restart if an order is on_progress,
  401 → logout everywhere.
- `lib/controllers/authentication.dart` — register now sends
  `name, email, password, phone, vehicle_type`; profile via
  `delivery-worker/me`; stores `delivery_worker_id` from login/register;
  sets status available on login and offline on logout; `Get.offAllNamed`.
- `lib/models/order.dart` — tolerant of both `orderDetails`/`order_details`
  and `amount`/`quantity`; address/city/zip at order level with detail-level
  fallback; `OrderStatus` constants; `fullAddress` helper.
- `lib/views/map_page.dart` — Accept / Delivered (QR) / Failed action bar
  driven by order status, live-tracking indicator, failure-reason dialog,
  QR must match the current order id, ORS key moved to `--dart-define`,
  fixed the "Address: email" bug.
- `lib/views/orders_page.dart` — status chips, Accept button, address line,
  pull-to-refresh.
- `lib/views/register_page.dart` — phone field + vehicle type dropdown.
- `lib/views/profile_page.dart` — now reads `delivery-worker/me` with the
  Bearer token (old `user/edit/{id}` endpoints don't exist on this backend)
  and adds an availability toggle.
- `lib/views/home.dart` — stats now filter on `paid` / `complete`.
- `lib/constants/constant.dart` — API URL and ORS key via `--dart-define`.
- `lib/main.dart` — registers LocationTrackingService + WorkerController.

## Platform
- `android/.../AndroidManifest.xml` — INTERNET, fine/coarse location,
  FOREGROUND_SERVICE(_LOCATION), POST_NOTIFICATIONS, CAMERA, CALL_PHONE,
  `usesCleartextTraffic` (needed while the API is plain http), tel: query.
- `ios/Runner/Info.plist` — location + camera usage strings, background
  location mode.
- geolocator 14 API fix: `desiredAccuracy` → `locationSettings` (the old code
  wouldn't compile against the locked 14.0.2).

## Run it
```
flutter pub get
flutter run --dart-define=API_URL=http://192.168.100.19:8080/api/ --dart-define=ORS_API_KEY=your_key
```

## Things to verify against the real backend
1. `delivery-worker/orders` response shape — the model tolerates both doc
   variants, but paste one real JSON response and I'll lock it down.
2. `delivery-worker/me` response keys (`delivery_worker` vs `worker`) — both handled.
3. **Failed delivery**: the doc only documents fail on the admin API. The app
   calls `POST delivery-worker/orders/fail/{id}` with `{reason}` — the backend
   needs to expose that route (mirroring the admin one) or the button will
   show a "not available" message.
4. `complete` response — the app accepts `status == 'complete'`,
   `order.status == 'complete'`, or `success: true`.
5. Rotate the OpenRouteService key that was committed in the repo history.
