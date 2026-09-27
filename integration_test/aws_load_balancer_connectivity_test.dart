import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('AWS load balancer serves the UI dietary-options endpoint', () async {
    const expectedHost =
        'nus-archss-alb-dev-126330082.ap-southeast-1.elb.amazonaws.com';
    final uri = Uri.parse(ApiConfig.dietaryOptionsUrl);

    expect(uri.scheme, 'http');
    expect(uri.host, expectedHost);
    expect(uri.path, '/api/v1/preference/dietary/options');

    final response = await http.get(uri).timeout(const Duration(seconds: 15));

    expect(
      response.statusCode,
      200,
      reason: 'GET $uri returned ${response.statusCode}',
    );
    expect(response.headers['content-type'], contains('application/json'));

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    expect(payload['dietType'], isA<List<dynamic>>());
    expect(payload['dietType'], isNotEmpty);
    expect(payload['allergens'], isA<List<dynamic>>());
    expect(payload['allergens'], isNotEmpty);
  });
}
