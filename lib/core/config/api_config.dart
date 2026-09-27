class ApiConfig {
  static const String _defaultBaseUrl = 'https://dev.keiyam.me';

  static const String _defaultLocalPreference =
      'http://localhost:8080/api/v1/preference';
  static const String _defaultLocalFood =
      'http://localhost:8082/api/v1/food';
  static const String _defaultLocalUser =
      'http://localhost:8081/api/v1/user';

  static const bool isLocal = bool.fromEnvironment(
    'LOCAL_API',
    defaultValue: false,
  );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const String _userServicePath = '$baseUrl/api/v1/user';
  static const String _preferenceServicePath = '$baseUrl/api/v1/preference';
  static const String _foodServicePath = '$baseUrl/api/v1/food';

  static String get userBaseUrl =>
      isLocal ? _defaultLocalUser : _userServicePath;

  static String get preferenceBaseUrl =>
      isLocal ? _defaultLocalPreference : _preferenceServicePath;

  static String get foodBaseUrl =>
      isLocal ? _defaultLocalFood : _foodServicePath;

  static String get dietaryOptionsUrl => '$preferenceBaseUrl/dietary/options';
}
