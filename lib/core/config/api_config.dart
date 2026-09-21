class ApiConfig {
  static const String _defaultBaseUrl = 'https://dev.keiyam.me';

  static const String _defaultLocalPreference =
      'http://localhost:8080/preference/api/v1';
  static const String _defaultLocalFood =
      'http://localhost:8082/food/api/v1/foods';
  static const String _defaultLocalUser =
      'http://localhost:8081/user/api/v1/users';

  static const bool isLocal = bool.fromEnvironment(
    'LOCAL_API',
    defaultValue: false,
  );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  // The development load balancer routes each service under its own prefix.
  // For example: /preference/api/v1/dietary/options.
  static const String _userServicePath = '$baseUrl/user/api/v1/users';
  static const String _preferenceServicePath = '$baseUrl/preference/api/v1';
  static const String _foodServicePath = '$baseUrl/food/api/v1/foods';

  static String get userBaseUrl =>
      isLocal ? _defaultLocalUser : _userServicePath;

  static String get preferenceBaseUrl =>
      isLocal ? _defaultLocalPreference : _preferenceServicePath;

  static String get foodBaseUrl =>
      isLocal ? _defaultLocalFood : _foodServicePath;

  static String get dietaryOptionsUrl => '$preferenceBaseUrl/dietary/options';
}
