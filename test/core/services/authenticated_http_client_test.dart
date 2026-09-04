import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/services/authenticated_http_client.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';

String _jwtWithExp(DateTime expiresAt) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final exp = expiresAt.millisecondsSinceEpoch ~/ 1000;
  return '${encode({'alg': 'none'})}.${encode({'sub': 'user-123', 'exp': exp})}.sig';
}

void main() {
  group('AuthenticatedHttpClient', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'returns 401 when authenticated request cannot be refreshed',
      () async {
        final oldToken = _jwtWithExp(
          DateTime.now().add(const Duration(hours: 1)),
        );
        await TokenStorage.saveTokens(idToken: oldToken, accessToken: oldToken);

        var backendCalls = 0;
        final backendClient = MockClient((request) async {
          backendCalls++;
          expect(request.headers['Authorization'], equals('Bearer $oldToken'));
          return http.Response('unauthorized', 401);
        });

        final authClient = MockClient((_) async {
          fail('refresh should not be called without a refresh token');
        });

        final response = await AuthenticatedHttpClient.get(
          Uri.parse('https://example.com/protected'),
          client: backendClient,
          authClient: authClient,
        );

        expect(response.statusCode, equals(401));
        expect(backendCalls, equals(1));
      },
    );

    test('does not retry unauthenticated requests', () async {
      var backendCalls = 0;
      final backendClient = MockClient((request) async {
        backendCalls++;
        expect(request.headers['Authorization'], isNull);
        return http.Response('unauthorized', 401);
      });

      final response = await AuthenticatedHttpClient.get(
        Uri.parse('https://example.com/public'),
        tokenType: AuthTokenType.none,
        client: backendClient,
      );

      expect(response.statusCode, equals(401));
      expect(backendCalls, equals(1));
    });
  });
}
