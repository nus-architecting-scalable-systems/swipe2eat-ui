import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/features/auth/services/auth_session.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';

String _jwtWithExp(DateTime expiresAt, {String sub = 'user-123'}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final exp = expiresAt.millisecondsSinceEpoch ~/ 1000;
  return '${encode({'alg': 'none'})}.${encode({'sub': sub, 'exp': exp})}.sig';
}

void main() {
  group('AuthSession.ensureFreshSession', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('does not refresh when tokens are fresh', () async {
      final freshToken = _jwtWithExp(
        DateTime.now().add(const Duration(minutes: 30)),
      );
      await TokenStorage.saveTokens(
        idToken: freshToken,
        accessToken: freshToken,
        refreshToken: 'refresh-token',
      );

      final client = MockClient((_) async {
        fail('refresh should not be called for fresh tokens');
      });

      final result = await AuthSession.ensureFreshSession(
        authClient: client,
        redirectOnFailure: false,
      );

      expect(result, isTrue);
    });

    test(
      'keeps access-token-only sessions inside the refresh buffer',
      () async {
        final staleToken = _jwtWithExp(
          DateTime.now().add(const Duration(minutes: 2)),
        );
        await TokenStorage.saveTokens(
          idToken: staleToken,
          accessToken: staleToken,
        );

        final client = MockClient((_) async {
          fail('refresh should not be called without a refresh token');
        });

        final result = await AuthSession.ensureFreshSession(
          authClient: client,
          redirectOnFailure: false,
        );

        expect(result, isTrue);
        expect(await TokenStorage.getIdToken(), equals(staleToken));
      },
    );

    test('clears access-token-only sessions when tokens are expired', () async {
      final expiredToken = _jwtWithExp(
        DateTime.now().subtract(const Duration(minutes: 1)),
      );
      await TokenStorage.saveTokens(
        idToken: expiredToken,
        accessToken: expiredToken,
      );

      final client = MockClient((_) async {
        fail('refresh should not be called without a refresh token');
      });

      final result = await AuthSession.ensureFreshSession(
        authClient: client,
        redirectOnFailure: true,
      );

      expect(result, isFalse);
      expect(await TokenStorage.getIdToken(), isNull);
      expect(await TokenStorage.getAccessToken(), isNull);
      expect(await TokenStorage.getRefreshToken(), isNull);
    });
  });
}
