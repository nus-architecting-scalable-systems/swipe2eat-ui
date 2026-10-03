import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/core/state/favorites_store.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';
import 'package:swipe2eat_ui/features/favorites/favorites_screen.dart';
import 'package:swipe2eat_ui/features/favorites/food_detail_screen.dart';

import '../test/test_helpers/http_test_overrides.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('favorite location link flow', () {
    late HttpTestOverrides httpOverrides;

    final transparentPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      FavoritesStore.instance.clear();
      httpOverrides = HttpTestOverrides();
      HttpOverrides.global = httpOverrides;

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

      await TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-123',
        email: 'test@example.com',
      );
    });

    tearDown(() {
      FavoritesStore.instance.clear();
      HttpOverrides.global = null;
    });

    testWidgets(
      'reloaded favorite details preserve and display the map location link',
      (tester) async {
        const address = '1 NUS Drive, Singapore';
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
          response: StubHttpResponse.json({
            'foods': [
              {
                'id': '77777777-7777-4777-8777-777777777777',
                'name': 'Chicken Rice',
                'restaurantName': 'Campus Canteen',
                'imageKey': '',
                'rating': 4.6,
                'price': 6.5,
                'description': 'Poached chicken with fragrant rice',
                'cuisine': ['Chinese'],
                'address': address,
              },
            ],
          }),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: FavoritesScreen(showBottomNav: false)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 dishes saved'), findsOneWidget);
        expect(find.text('Chicken Rice'), findsOneWidget);
        expect(FavoritesStore.instance.favorites.value.single.address, address);

        await tester.tap(find.text('Chicken Rice'));
        await tester.pumpAndSettle();

        expect(find.byType(FoodDetailScreen), findsOneWidget);
        expect(find.byIcon(Icons.location_on), findsOneWidget);
        expect(find.text(address), findsOneWidget);

        final addressText = tester.widget<Text>(find.text(address));
        expect(addressText.style?.color, const Color(0xFF2563EB));
        expect(addressText.style?.decoration, TextDecoration.underline);
      },
    );

    testWidgets(
      'favorite details use restaurant name as map link when address is missing',
      (tester) async {
        const restaurant = 'Dunman Food Centre';
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
          response: StubHttpResponse.json({
            'foods': [
              {
                'id': '88888888-8888-4888-8888-888888888888',
                'name': 'Thai Fried Rice',
                'restaurantName': restaurant,
                'imageKey': '',
                'rating': 4.1,
                'price': 5.93,
                'description':
                    'Thai Fried Rice is a Thai favorite from Dunman Food Centre.',
                'cuisine': ['Thai'],
              },
            ],
          }),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: FavoritesScreen(showBottomNav: false)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 dishes saved'), findsOneWidget);
        expect(find.text('Thai Fried Rice'), findsOneWidget);
        expect(FavoritesStore.instance.favorites.value.single.address, isNull);

        await tester.tap(find.text('Thai Fried Rice'));
        await tester.pumpAndSettle();

        expect(find.byType(FoodDetailScreen), findsOneWidget);
        expect(find.byIcon(Icons.location_on), findsOneWidget);
        expect(
          find.byKey(const ValueKey('food-detail-map-location-link')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('food-detail-map-location-link')),
            matching: find.text(restaurant),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
