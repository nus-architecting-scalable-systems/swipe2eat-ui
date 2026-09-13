/// API configuration for the application.
/// Contains base URLs and common API endpoints.
class ApiConfig {
  static const String _defaultBaseUrl = 'https://dev.keiyam.me';

  /// Base URL for all backend services deployed on AWS.
  ///
  /// Override at build time with:
  /// `--dart-define=API_BASE_URL=https://api.example.com`
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const String apiV1 = '$baseUrl/api/v1';

  static String get userBaseUrl => '$apiV1/user';

  static String get preferenceBaseUrl => '$apiV1/preference';

  static String get dietaryOptionsUrl => '$preferenceBaseUrl/dietary/options';

  static String get foodBaseUrl => '$apiV1/food';
}
