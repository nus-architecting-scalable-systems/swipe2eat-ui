import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';

String _jwtWithExp(DateTime expiresAt) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final exp = expiresAt.millisecondsSinceEpoch ~/ 1000;
  return '${encode({'alg': 'none'})}.${encode({'sub': 'user-123', 'exp': exp})}.signature';
}

void main() {
  group('TokenStorage.isLoggedIn', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns true for valid stored tokens', () async {
      final token = _jwtWithExp(DateTime.now().add(const Duration(hours: 1)));
      await TokenStorage.saveTokens(
        idToken: token,
        accessToken: token,
        refreshToken: 'refresh-token',
      );

      expect(await TokenStorage.isLoggedIn(), isTrue);
    });

    test('returns false for expired stored tokens', () async {
      final token = _jwtWithExp(
        DateTime.now().subtract(const Duration(minutes: 1)),
      );
      await TokenStorage.saveTokens(
        idToken: token,
        accessToken: token,
        refreshToken: 'refresh-token',
      );

      expect(await TokenStorage.isLoggedIn(), isFalse);
    });
  });

  group('TokenStorage.clearTokens', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('clears auth tokens and the per-user backend-created flag', () async {
      SharedPreferences.setMockInitialValues({
        'auth.idToken': 'id-token',
        'auth.accessToken': 'access-token',
        'auth.refreshToken': 'refresh-token',
        'auth.idTokenExpiresAt': DateTime.now().toIso8601String(),
        'auth.accessTokenExpiresAt': DateTime.now().toIso8601String(),
        'auth.userId': 'user-123',
        'auth.email': 'user@example.com',
        'user.backendCreated.user-123': true,
      });

      await TokenStorage.clearTokens();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth.idToken'), isNull);
      expect(prefs.getString('auth.accessToken'), isNull);
      expect(prefs.getString('auth.refreshToken'), isNull);
      expect(prefs.getString('auth.idTokenExpiresAt'), isNull);
      expect(prefs.getString('auth.accessTokenExpiresAt'), isNull);
      expect(prefs.getString('auth.userId'), isNull);
      expect(prefs.getString('auth.email'), isNull);
      expect(prefs.getBool('user.backendCreated.user-123'), isNull);
    });

    test('also clears legacy auth keys', () async {
      SharedPreferences.setMockInitialValues({
        'cognito.idToken': 'id-token',
        'cognito.accessToken': 'access-token',
        'cognito.refreshToken': 'refresh-token',
        'cognito.userId': 'user-123',
        'user.backendCreated.user-123': true,
      });

      await TokenStorage.clearTokens();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cognito.idToken'), isNull);
      expect(prefs.getString('cognito.accessToken'), isNull);
      expect(prefs.getString('cognito.refreshToken'), isNull);
      expect(prefs.getString('cognito.userId'), isNull);
      expect(prefs.getBool('user.backendCreated.user-123'), isNull);
    });
  });
}
