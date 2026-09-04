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

    test('builds derived service URLs from the base URL', () {
      expect(ApiConfig.userBaseUrl, '${ApiConfig.baseUrl}/user');
      expect(ApiConfig.preferenceBaseUrl, '${ApiConfig.baseUrl}/preference');
      expect(
        ApiConfig.dietaryOptionsUrl,
        '${ApiConfig.baseUrl}/preference/dietary/options',
      );
      expect(ApiConfig.llmChatUrl, '${ApiConfig.baseUrl}/llm/chat');
    });
  });
}
