import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/core/navigation/main_shell.dart';
import 'package:swipe2eat_ui/core/state/favorites_store.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';

import '../../test_helpers/http_test_overrides.dart';

void main() {
  group('MainShell', () {
    late HttpTestOverrides httpOverrides;

    final transparentPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
    );

    String createToken(Map<String, dynamic> payload) {
      final encodedPayload = base64Url
          .encode(utf8.encode(jsonEncode(payload)))
          .replaceAll('=', '');
      return 'e30.$encodedPayload.sig';
    }

    void stubImageTraffic() {
      httpOverrides.addHandler(
        matcher: (request) =>
            request.method == 'GET' &&
            request.uri.host != Uri.parse(ApiConfig.baseUrl).host,
        handler: (_) => StubHttpResponse(
          statusCode: 200,
          bodyBytes: transparentPng,
          headers: const {HttpHeaders.contentTypeHeader: 'image/png'},
        ),
      );
    }

    Map<String, dynamic> discoverFood() {
      return {
        'id': '11111111-1111-4111-8111-111111111111',
        'name': 'Laksa',
        'restaurantName': 'Spice House',
        'imageKey': '',
        'rating': 4.8,
        'price': 9.5,
        'description': 'Rich coconut broth',
        'cuisine': ['Malay'],
      };
    }

    Map<String, dynamic> favoriteFood() {
      return {
        'id': '22222222-2222-4222-8222-222222222222',
        'name': 'Sushi Roll',
        'restaurantName': 'Sushi Club',
        'imageKey': '',
        'rating': 4.7,
        'price': 12.5,
        'description': 'Fresh and tasty',
        'cuisine': ['Japanese'],
      };
    }

    Future<void> seedShellBootstrap() async {
      SharedPreferences.setMockInitialValues({
        'prefs.cuisines': ['Thai'],
        'prefs.budget': 'low',
        'prefs.spice': 'Medium',
      });
      FavoritesStore.instance.clear();

      final token = createToken({'name': 'Taylor', 'custom:City': 'Singapore'});
      await TokenStorage.saveTokens(
        idToken: token,
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-123',
      );

      stubImageTraffic();
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.baseUrl}/food/?userId=user-123',
        response: StubHttpResponse.json([discoverFood()]),
      );
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.baseUrl}/preference/food/users/user-123',
        response: StubHttpResponse.json({
          'foods': [favoriteFood()],
        }),
      );
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.baseUrl}/user/user-123',
        response: StubHttpResponse.json({
          'gender': 'female',
          'dateOfBirth': '1995-04-12',
        }),
      );
    }

    Future<void> pumpShell(
      WidgetTester tester, {
      MainTab initialTab = MainTab.discover,
    }) async {
      await seedShellBootstrap();
      await tester.pumpWidget(
        MaterialApp(home: MainShell(initialTab: initialTab)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    Color? navLabelColor(WidgetTester tester, String label) {
      return tester.widget<Text>(find.text(label).last).style?.color;
    }

    setUp(() {
      httpOverrides = HttpTestOverrides();
      HttpOverrides.global = httpOverrides;
    });

    tearDown(() {
      FavoritesStore.instance.clear();
      HttpOverrides.global = null;
    });

    testWidgets('defaults to the discover tab with active styling', (
      tester,
    ) async {
      await pumpShell(tester);

      expect(find.text('Swipe2Eat'), findsOneWidget);
      expect(find.text('Singapore'), findsOneWidget);
      expect(navLabelColor(tester, 'Discover'), const Color(0xFFFF6B4A));
      expect(navLabelColor(tester, 'Favorites'), const Color(0xFF9CA3AF));
      expect(find.text('Ask AI'), findsNothing);
    });

    testWidgets('supports favorites as an initial tab', (tester) async {
      await pumpShell(tester, initialTab: MainTab.favorites);
      expect(find.text('1 dishes saved'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(navLabelColor(tester, 'Favorites'), const Color(0xFFFF6B4A));
      expect(navLabelColor(tester, 'Discover'), const Color(0xFF9CA3AF));
    });

    testWidgets('supports profile as an initial tab', (tester) async {
      await pumpShell(tester, initialTab: MainTab.profile);
      expect(find.text('Personal Info'), findsOneWidget);
      expect(navLabelColor(tester, 'Profile'), const Color(0xFFFF6B4A));
    });

    testWidgets('switches tabs and updates the active nav item', (
      tester,
    ) async {
      await pumpShell(tester);

      await tester.tap(find.text('Favorites').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('1 dishes saved'), findsOneWidget);
      expect(navLabelColor(tester, 'Favorites'), const Color(0xFFFF6B4A));
      expect(navLabelColor(tester, 'Discover'), const Color(0xFF9CA3AF));

      await tester.tap(find.text('Profile').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Personal Info'), findsOneWidget);
      expect(navLabelColor(tester, 'Profile'), const Color(0xFFFF6B4A));

      await tester.tap(find.text('Discover').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Swipe2Eat'), findsOneWidget);
      expect(navLabelColor(tester, 'Discover'), const Color(0xFFFF6B4A));
    });
  });
}
