/// API configuration for the application.
/// Contains base URLs and common API endpoints.
class ApiConfig {
  static const String _defaultBaseUrl =
      'http://nus-archss-alb-dev-126330082.ap-southeast-1.elb.amazonaws.com';

  /// Base URL for all backend services.
  ///
  /// Override at build time with:
  /// `--dart-define=API_BASE_URL=https://api.example.com`
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static String get userBaseUrl => '$baseUrl/user';

  static String get preferenceBaseUrl => '$baseUrl/preference';

  static String get dietaryOptionsUrl => '$preferenceBaseUrl/dietary/options';
}
