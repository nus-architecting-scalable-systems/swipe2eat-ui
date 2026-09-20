import 'package:flutter_test/flutter_test.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('uses the default base URL in tests', () {
      expect(
        ApiConfig.baseUrl,
        'http://nus-archss-alb-dev-126330082.ap-southeast-1.elb.amazonaws.com',
      );
    });

    test('routes local requests to the separate service ports', () {
      if (!ApiConfig.isLocal) return;
      expect(ApiConfig.userBaseUrl, 'http://localhost:8081/user/api/v1/users');
      expect(ApiConfig.foodBaseUrl, 'http://localhost:8082/food/api/v1/foods');
      expect(
        ApiConfig.preferenceBaseUrl,
        'http://localhost:8080/preference/api/v1',
      );
    });

    test('builds derived service URLs from the base URL', () {
      if (ApiConfig.isLocal) return;
      expect(ApiConfig.userBaseUrl, '${ApiConfig.baseUrl}/user/api/v1/users');

      expect(
        ApiConfig.preferenceBaseUrl,
        '${ApiConfig.baseUrl}/preference/api/v1',
      );

      expect(
        ApiConfig.dietaryOptionsUrl,
        '${ApiConfig.baseUrl}/preference/api/v1/dietary/options',
      );

      expect(ApiConfig.foodBaseUrl, '${ApiConfig.baseUrl}/food/api/v1/foods');
    });
  });
}
