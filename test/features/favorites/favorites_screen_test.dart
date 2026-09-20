import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/core/state/favorites_store.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';
import 'package:swipe2eat_ui/features/favorites/favorites_screen.dart';
import 'package:swipe2eat_ui/features/favorites/food_detail_screen.dart';

import '../../test_helpers/http_test_overrides.dart';

void main() {
  group('FavoritesScreen', () {
    late HttpTestOverrides httpOverrides;

    final transparentPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
    );

    Map<String, dynamic> foodJson({
      required String id,
      required String name,
      required String restaurant,
      required List<String> cuisines,
      String? address,
    }) {
      final json = {
        'id': id,
        'name': name,
        'restaurantName': restaurant,
        'imageKey': '',
        'rating': 4.5,
        'price': 12.99,
        'description': '$name description',
        'cuisine': cuisines,
      };
      if (address != null) {
        json['address'] = address;
      }
      return json;
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

    Future<void> saveSession() {
      return TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-123',
      );
    }

    Future<void> pumpFavorites(
      WidgetTester tester, {
      bool showBottomNav = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FavoritesScreen(showBottomNav: showBottomNav)),
        ),
      );
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FavoritesStore.instance.clear();
      httpOverrides = HttpTestOverrides();
      HttpOverrides.global = httpOverrides;
      stubImageTraffic();
    });

    tearDown(() {
      FavoritesStore.instance.clear();
      HttpOverrides.global = null;
    });

    testWidgets('shows a loading skeleton while favorites are being fetched', (
      tester,
    ) async {
      await saveSession();
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
        response: StubHttpResponse.json(
          const <Object>[],
          delay: const Duration(milliseconds: 200),
        ),
      );

      await pumpFavorites(tester);
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text("Couldn't load favorites"), findsNothing);
      expect(
        find.text('No favorites yet.\nGo like some food 😄'),
        findsNothing,
      );
      expect(find.byType(TextField), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
    });

    testWidgets('shows an error state when the user id is missing', (
      tester,
    ) async {
      await pumpFavorites(tester);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load favorites"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retries after a failed response and then loads favorites', (
      tester,
    ) async {
      await saveSession();
      var calls = 0;
      httpOverrides.addHandler(
        matcher: (request) =>
            request.method == 'GET' &&
            request.uri.toString() ==
                '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
        handler: (_) {
          calls++;
          if (calls == 1) {
            return const StubHttpResponse(statusCode: 500, body: '{}');
          }
          return StubHttpResponse.json({
            'foods': [
              foodJson(
                id: '11111111-1111-4111-8111-111111111111',
                name: 'Pad Thai',
                restaurant: 'Thai House',
                cuisines: ['Thai'],
              ),
            ],
          });
        },
      );

      await pumpFavorites(tester);
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load favorites"), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 dishes saved'), findsOneWidget);
      expect(find.text('Pad Thai'), findsOneWidget);
      expect(
        FavoritesStore.instance.contains(
          '11111111-1111-4111-8111-111111111111',
        ),
        isTrue,
      );
    });

    testWidgets(
      'loads favorites from nested food payloads and updates the store count',
      (tester) async {
        await saveSession();
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
          response: StubHttpResponse.json({
            'data': [
              {
                'food': foodJson(
                  id: '22222222-2222-4222-8222-222222222222',
                  name: 'Sushi Roll',
                  restaurant: 'Sushi Club',
                  cuisines: ['Japanese'],
                ),
              },
            ],
          }),
        );

        await pumpFavorites(tester);
        await tester.pumpAndSettle();

        expect(find.text('1 dishes saved'), findsOneWidget);
        expect(find.text('Sushi Roll'), findsOneWidget);
        expect(FavoritesStore.instance.favorites.value, hasLength(1));
        expect(
          FavoritesStore.instance.favorites.value.single.name,
          'Sushi Roll',
        );
      },
    );

    testWidgets('shows the empty state when no favorites are returned', (
      tester,
    ) async {
      await saveSession();
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
        response: StubHttpResponse.json(const <Object>[]),
      );

      await pumpFavorites(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('No favorites yet.\nGo like some food 😄'),
        findsOneWidget,
      );
    });

    testWidgets('filters favorites by dish name, restaurant, and tag', (
      tester,
    ) async {
      await saveSession();
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
        response: StubHttpResponse.json([
          foodJson(
            id: '33333333-3333-4333-8333-333333333333',
            name: 'Pad Thai',
            restaurant: 'Thai House',
            cuisines: ['Thai'],
          ),
          foodJson(
            id: '44444444-4444-4444-8444-444444444444',
            name: 'Sushi Roll',
            restaurant: 'Sushi Club',
            cuisines: ['Japanese'],
          ),
          foodJson(
            id: '55555555-5555-4555-8555-555555555555',
            name: 'Kimchi Fried Rice',
            restaurant: 'Seoul Kitchen',
            cuisines: ['Korean'],
          ),
        ]),
      );

      await pumpFavorites(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'pad thai');
      await tester.pumpAndSettle();
      expect(find.text('Pad Thai'), findsOneWidget);
      expect(find.text('Sushi Roll'), findsNothing);

      await tester.enterText(find.byType(TextField), 'sushi club');
      await tester.pumpAndSettle();
      expect(find.text('Sushi Roll'), findsOneWidget);
      expect(find.text('Pad Thai'), findsNothing);

      await tester.enterText(find.byType(TextField), 'korean');
      await tester.pumpAndSettle();
      expect(find.text('Kimchi Fried Rice'), findsOneWidget);
      expect(find.text('Sushi Roll'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(
        find.text('No favorites yet.\nGo like some food 😄'),
        findsOneWidget,
      );
    });

    testWidgets('opens the food detail screen when a tile is tapped', (
      tester,
    ) async {
      await saveSession();
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
        response: StubHttpResponse.json({
          'foods': [
            foodJson(
              id: '66666666-6666-4666-8666-666666666666',
              name: 'Ramen',
              restaurant: 'Noodle Bar',
              cuisines: ['Japanese'],
            ),
          ],
        }),
      );

      await pumpFavorites(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ramen'));
      await tester.pumpAndSettle();

      expect(find.byType(FoodDetailScreen), findsOneWidget);
      expect(find.text('Ramen description'), findsOneWidget);
    });

    testWidgets(
      'preserves favorite address so reopened details show the map link',
      (tester) async {
        await saveSession();
        const address = '1 NUS Drive, Singapore';
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
          response: StubHttpResponse.json({
            'foods': [
              foodJson(
                id: '77777777-7777-4777-8777-777777777777',
                name: 'Chicken Rice',
                restaurant: 'Campus Canteen',
                cuisines: ['Chinese'],
                address: address,
              ),
            ],
          }),
        );

        await pumpFavorites(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Chicken Rice'));
        await tester.pumpAndSettle();

        expect(find.byType(FoodDetailScreen), findsOneWidget);
        expect(find.byIcon(Icons.location_on), findsOneWidget);
        expect(find.text(address), findsOneWidget);
        expect(FavoritesStore.instance.favorites.value.single.address, address);
      },
    );

    testWidgets(
      'shows and pops the close button only when bottom nav is enabled',
      (tester) async {
        await saveSession();
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
          response: StubHttpResponse.json(const <Object>[]),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const Scaffold(
                          body: FavoritesScreen(showBottomNav: true),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Favorites'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Favorites'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Open Favorites'), findsOneWidget);

        await saveSession();
        httpOverrides.clear();
        stubImageTraffic();
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/foods/users/user-123',
          response: StubHttpResponse.json(const <Object>[]),
        );
        await pumpFavorites(tester);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.close_rounded), findsNothing);
      },
    );
  });
}
