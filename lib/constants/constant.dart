/// API configuration.
///
/// Override at build time with:
///   flutter run --dart-define=API_URL=http://192.168.100.19:8080/api/
///   flutter build apk --dart-define=API_URL=https://your-domain.com/api/ --dart-define=ORS_API_KEY=xxx
const String url = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://192.168.100.13/api/',
);

/// OpenRouteService key for route drawing on the map.
/// Do NOT commit a real key — pass it with --dart-define=ORS_API_KEY=...
const String orsApiKey = String.fromEnvironment('ORS_API_KEY', defaultValue: '');
