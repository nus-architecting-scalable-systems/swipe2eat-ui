class ApiConfig {
  static const String _defaultBaseUrl = 'https://dev.keiyam.me';

  static const String _defaultLocalPreference =
      'http://localhost:8080/preference/api/v1/preference';
  static const String _defaultLocalFood =
      'http://localhost:8082/food/api/v1/food';
  static const String _defaultLocalUser =
      'http://localhost:8081/user/api/v1/user';

  static const bool isLocal = bool.fromEnvironment(
    'LOCAL_API',
    defaultValue: false,
  );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const String apiV1 = '$baseUrl/api/v1';

  static String get userBaseUrl => isLocal ? _defaultLocalUser : '$apiV1/user';

  static String get preferenceBaseUrl =>
      isLocal ? _defaultLocalPreference : '$apiV1/preference';

  static String get foodBaseUrl => isLocal ? _defaultLocalFood : '$apiV1/food';

  static String get dietaryOptionsUrl => '$preferenceBaseUrl/dietary/options';
}
