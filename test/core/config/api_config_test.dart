import 'package:flutter_test/flutter_test.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('uses the default base URL in tests', () {
      expect(ApiConfig.baseUrl, 'https://dev.keiyam.me');
    });

    test('routes local requests to the separate service ports', () {
      if (!ApiConfig.isLocal) return;
      expect(ApiConfig.userBaseUrl, 'http://localhost:8081/user/api/v1/user');
      expect(ApiConfig.foodBaseUrl, 'http://localhost:8082/food/api/v1/food');
      expect(ApiConfig.preferenceBaseUrl,
          'http://localhost:8080/preference/api/v1/preference');
    });

    test('builds derived service URLs from the base URL', () {
      if (ApiConfig.isLocal) return;
      expect(ApiConfig.userBaseUrl, '${ApiConfig.baseUrl}/api/v1/user');

      expect(
        ApiConfig.preferenceBaseUrl,
        '${ApiConfig.baseUrl}/api/v1/preference',
      );

      expect(
        ApiConfig.dietaryOptionsUrl,
        '${ApiConfig.baseUrl}/api/v1/preference/dietary/options',
      );

      expect(ApiConfig.foodBaseUrl, '${ApiConfig.baseUrl}/api/v1/food');
    });
  });
}
