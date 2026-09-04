import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/features/auth/services/user_auth_service.dart';

void main() {
  group('UserAuthService', () {
    test('signUp posts profile fields to the backend user service', () async {
      final client = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(
          request.url.toString(),
          equals('${ApiConfig.userBaseUrl}/register'),
        );
        expect(request.headers['Content-Type'], equals('application/json'));

        expect(
          jsonDecode(request.body),
          equals({
            'username': 'user123',
            'password': 'Password123!',
            'name': 'Taylor Lim',
            'city': 'Singapore',
            'gender': 'female',
            'dateOfBirth': '1995-04-12',
          }),
        );

        return http.Response(
          jsonEncode({
            'user': {'id': 'user-123', 'username': 'user123'},
            'accessToken': 'issued-token',
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final result = await UserAuthService.signUp(
        username: 'user123',
        password: 'Password123!',
        name: 'Taylor Lim',
        city: 'Singapore',
        gender: 'female',
        dateOfBirth: DateTime(1995, 4, 12),
        client: client,
      );

      expect(result['success'], isTrue);
      expect(result['accessToken'], equals('issued-token'));
      expect(result['userId'], equals('user-123'));
      expect(result['username'], equals('user123'));
    });

    test('signIn extracts common token response fields', () async {
      final client = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(
          request.url.toString(),
          equals('${ApiConfig.userBaseUrl}/login'),
        );
        expect(
          jsonDecode(request.body),
          equals({'username': 'user123', 'password': 'Password123!'}),
        );

        return http.Response(
          jsonEncode({'id': 'user-123', 'accessToken': 'access-token'}),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final result = await UserAuthService.signIn(
        username: 'user123',
        password: 'Password123!',
        client: client,
      );

      expect(result['success'], isTrue);
      expect(result['accessToken'], equals('access-token'));
      expect(result['idToken'], equals('access-token'));
      expect(result['userId'], equals('user-123'));
    });

    test('signIn fails when the response has no access token', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'message': 'OK'}), 200),
      );

      final result = await UserAuthService.signIn(
        username: 'user123',
        password: 'Password123!',
        client: client,
      );

      expect(result['success'], isFalse);
      expect(
        result['error'],
        equals('Authentication response did not include an access token.'),
      );
    });

    test('maps backend errors to user-facing error text', () async {
      final client = MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': 'Bad credentials'}), 401),
      );

      final result = await UserAuthService.signIn(
        username: 'user123',
        password: 'wrong',
        client: client,
      );

      expect(result['success'], isFalse);
      expect(result['error'], equals('Bad credentials'));
      expect(result['statusCode'], equals(401));
    });

    test(
      'does not call unsupported refresh or password reset endpoints',
      () async {
        final client = MockClient((_) async {
          fail('unsupported user-service auth endpoints should not be called');
        });

        final refresh = await UserAuthService.refreshSession(
          refreshToken: 'refresh-token',
          client: client,
        );
        final forgot = await UserAuthService.forgotPassword(
          email: 'user@example.com',
          client: client,
        );
        final reset = await UserAuthService.confirmForgotPassword(
          email: 'user@example.com',
          confirmationCode: '123456',
          newPassword: 'Password123!',
          client: client,
        );

        expect(refresh['success'], isFalse);
        expect(
          refresh['error'],
          equals('Session refresh is not supported by the user service.'),
        );
        expect(forgot['success'], isFalse);
        expect(
          forgot['error'],
          equals('Password reset is not supported by the user service.'),
        );
        expect(reset['success'], isFalse);
        expect(
          reset['error'],
          equals('Password reset is not supported by the user service.'),
        );
      },
    );
  });
}
