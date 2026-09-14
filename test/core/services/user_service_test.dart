import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/core/services/user_service.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';

void main() {
  group('UserService.createUserInBackend', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'marks authenticated backend-registered user as created locally',
      () async {
        await TokenStorage.saveTokens(
          idToken: 'id-token',
          accessToken: 'access-token',
          userId: 'user-123',
        );

        final created = await UserService.createUserInBackend();

        final prefs = await SharedPreferences.getInstance();
        expect(created, isTrue);
        expect(prefs.getBool('user.backendCreated.user-123'), isTrue);
      },
    );

    test('returns false when access token is unavailable', () async {
      await TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: '',
        userId: 'user-123',
      );

      expect(await UserService.createUserInBackend(), isFalse);
    });
  });

  group('UserService.logoutCurrentUser', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('posts access token to backend logout endpoint', () async {
      await TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-123',
      );

      final client = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(
          request.url.toString(),
          equals('${ApiConfig.userBaseUrl}/logout'),
        );
        expect(request.headers['Authorization'], equals('Bearer access-token'));
        expect(request.headers['Content-Type'], equals('application/json'));

        return http.Response('', 204);
      });

      final loggedOut = await UserService.logoutCurrentUser(client: client);

      expect(loggedOut, isTrue);
    });

    test('returns false when access token is unavailable', () async {
      await TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: '',
        refreshToken: 'refresh-token',
        userId: 'user-123',
      );

      final loggedOut = await UserService.logoutCurrentUser();

      expect(loggedOut, isFalse);
    });

    test('returns false after backend rejects logout', () async {
      await TokenStorage.saveTokens(
        idToken: 'old-id-token',
        accessToken: 'expired-access-token',
        refreshToken: 'refresh-token',
        userId: 'user-123',
      );

      var logoutCalls = 0;
      final logoutClient = MockClient((request) async {
        logoutCalls++;
        expect(request.method, equals('POST'));
        expect(
          request.url.toString(),
          equals('${ApiConfig.userBaseUrl}/logout'),
        );

        expect(
          request.headers['Authorization'],
          equals('Bearer expired-access-token'),
        );
        return http.Response(
          '{"message":"Invalid or expired token","error":"Unauthorized"}',
          401,
        );
      });

      final loggedOut = await UserService.logoutCurrentUser(
        client: logoutClient,
      );

      expect(loggedOut, isFalse);
      expect(logoutCalls, equals(1));
      expect(await TokenStorage.getIdToken(), equals('old-id-token'));
      expect(
        await TokenStorage.getAccessToken(),
        equals('expired-access-token'),
      );
      expect(await TokenStorage.getRefreshToken(), equals('refresh-token'));
    });
  });

  group('UserService.deleteCurrentUserInBackend', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('treats 404 as success during account deletion', () async {
      await TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-123',
      );

      final client = MockClient((request) async {
        expect(request.method, equals('DELETE'));
        expect(
          request.url.toString(),
          equals('${ApiConfig.userBaseUrl}/user-123'),
        );
        expect(request.headers['Authorization'], equals('Bearer access-token'));
        expect(request.headers['X-Id-Token'], equals('id-token'));

        return http.Response('', 404);
      });

      final deleted = await UserService.deleteCurrentUserInBackend(
        client: client,
      );

      expect(deleted, isTrue);
    });

    test('returns false when user identity is unavailable', () async {
      await TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );

      final deleted = await UserService.deleteCurrentUserInBackend();

      expect(deleted, isFalse);
    });
  });
}
