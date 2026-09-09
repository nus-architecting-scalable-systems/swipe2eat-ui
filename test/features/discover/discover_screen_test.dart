import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/core/state/favorites_store.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';
import 'package:swipe2eat_ui/features/discover/discover_screen.dart';
import 'package:swipe2eat_ui/features/favorites/food_detail_screen.dart';

import '../../test_helpers/http_test_overrides.dart';

void main() {
  group('DiscoverScreen', () {
    late HttpTestOverrides httpOverrides;
    late void Function(FlutterErrorDetails details)? oldOnError;

    final transparentPng = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
    );

    String createToken(Map<String, dynamic> payload) {
      final encodedPayload = base64Url
          .encode(utf8.encode(jsonEncode(payload)))
          .replaceAll('=', '');
      return 'e30.$encodedPayload.sig';
    }

    Map<String, dynamic> foodJson({
      required String id,
      required String name,
      required String restaurant,
      double rating = 4.8,
      double price = 9.5,
      List<String> cuisines = const ['Malay'],
      String description = 'Rich coconut broth',
    }) {
      return {
        'id': id,
        'name': name,
        'restaurantName': restaurant,
        'imageKey': '',
        'rating': rating,
        'price': price,
        'description': description,
        'cuisine': cuisines,
      };
    }

    void stubImageTraffic() {
      final backendHost = Uri.parse(ApiConfig.baseUrl).host;
      httpOverrides.addHandler(
        matcher: (request) =>
            request.method == 'GET' && request.uri.host != backendHost,
        handler: (_) => StubHttpResponse(
          statusCode: 200,
          bodyBytes: transparentPng,
          headers: const {HttpHeaders.contentTypeHeader: 'image/png'},
        ),
      );
    }

    Future<void> saveSession({
      Map<String, dynamic>? tokenPayload,
      String userId = 'user-123',
    }) {
      return TokenStorage.saveTokens(
        idToken: createToken(
          tokenPayload ?? {'name': 'Taylor', 'custom:City': 'Singapore'},
        ),
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: userId,
        email: 'user@example.com',
      );
    }

    Future<void> pumpDiscover(
      WidgetTester tester, {
      bool showBottomNav = true,
    }) async {
      tester.view.physicalSize = const Size(1400, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(0.8)),
            child: child!,
          ),
          home: Scaffold(body: DiscoverScreen(showBottomNav: showBottomNav)),
        ),
      );
      await settleUi(tester);
    }

    void seedPreferences({
      List<String> cuisines = const ['Thai', 'Japanese'],
      String budget = 'medium',
      String spice = 'Hot',
      String dietType = 'Vegetarian',
      List<String> allergens = const ['Peanut'],
    }) {
      SharedPreferences.setMockInitialValues({
        'prefs.cuisines': cuisines,
        'prefs.budget': budget,
        'prefs.spice': spice,
        'prefs.dietType': dietType,
        'prefs.allergens': allergens,
      });
    }

    CapturedHttpRequest? requestFor(TestHttpMatcher matcher) {
      return httpOverrides.lastRequestMatching(matcher);
    }

    setUp(() {
      oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.exceptionAsString();
        if (message.contains('A RenderFlex overflowed')) {
          return;
        }
        if (message.contains("Looking up a deactivated widget's ancestor")) {
          return;
        }
        oldOnError?.call(details);
      };
      seedPreferences();
      FavoritesStore.instance.clear();
      httpOverrides = HttpTestOverrides();
      HttpOverrides.global = httpOverrides;
      stubImageTraffic();
    });

    tearDown(() {
      FavoritesStore.instance.clear();
      FlutterError.onError = oldOnError;
      HttpOverrides.global = null;
    });

    testWidgets(
      'loads bootstrap state, renders the card, and opens food details',
      (tester) async {
        await saveSession();
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.foodBaseUrl}?userId=user-123',
          response: StubHttpResponse.json([
            foodJson(
              id: '11111111-1111-4111-8111-111111111111',
              name: 'Laksa',
              restaurant: 'Spice House',
            ),
          ]),
        );

        await pumpDiscover(tester);

        expect(find.text('Swipe2Eat'), findsOneWidget);
        expect(find.text('Singapore'), findsOneWidget);
        expect(find.text('Laksa'), findsOneWidget);
        expect(find.text('Spice House'), findsOneWidget);
        expect(find.text('Malay'), findsOneWidget);
        expect(find.text('\$9.50'), findsOneWidget);

        await tester.tap(find.text('Laksa'));
        await settleUi(tester);

        expect(find.byType(FoodDetailScreen), findsOneWidget);
        expect(find.text('Rich coconut broth'), findsOneWidget);
      },
    );

    testWidgets('shows the fetch error state and retries successfully', (
      tester,
    ) async {
      await saveSession();
      var calls = 0;
      httpOverrides.addHandler(
        matcher: (request) =>
            request.method == 'GET' &&
            request.uri.toString() ==
                '${ApiConfig.foodBaseUrl}?userId=user-123',
        handler: (_) {
          calls++;
          if (calls == 1) {
            return const StubHttpResponse(statusCode: 500, body: '{}');
          }
          return StubHttpResponse.json([
            foodJson(
              id: '22222222-2222-4222-8222-222222222222',
              name: 'Ramen',
              restaurant: 'Noodle Bar',
              cuisines: const ['Japanese'],
            ),
          ]);
        },
      );

      await pumpDiscover(tester);

      expect(find.text("Couldn't load foods"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await settleUi(tester);

      expect(find.text('Ramen'), findsOneWidget);
      expect(find.text("Couldn't load foods"), findsNothing);
    });

    testWidgets('shows the invalid-data empty state when foods are dropped', (
      tester,
    ) async {
      httpOverrides.addHandler(
        matcher: (request) =>
            request.method == 'GET' &&
            request.uri.path.endsWith('/food') &&
            request.uri.queryParameters['budget'] == 'medium' &&
            _listEquals(request.uri.queryParametersAll['cuisines'], const [
              'Thai',
              'Japanese',
            ]) &&
            request.uri.queryParameters['spiceLevel'] == '3',
        handler: (_) => StubHttpResponse.json([
          {
            'id': 'not-a-uuid',
            'name': 'Broken Dish',
            'restaurantName': 'Bad Data',
            'imageKey': '',
            'price': 10,
            'rating': 4.1,
          },
        ]),
      );

      await pumpDiscover(tester);

      expect(find.text('No dishes available'), findsOneWidget);
      expect(
        find.text(
          'Skipped 1 dishes because of invalid data. Please try again shortly.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'like swipe adds a favorite, reaches the exhausted state, and refreshes',
      (tester) async {
        await saveSession();
        var calls = 0;
        httpOverrides.addHandler(
          matcher: (request) =>
              request.method == 'GET' &&
              request.uri.toString() ==
                  '${ApiConfig.foodBaseUrl}?userId=user-123',
          handler: (_) {
            calls++;
            if (calls == 1) {
              return StubHttpResponse.json([
                foodJson(
                  id: '33333333-3333-4333-8333-333333333333',
                  name: 'Laksa',
                  restaurant: 'Spice House',
                ),
              ]);
            }
            return StubHttpResponse.json([
              foodJson(
                id: '44444444-4444-4444-8444-444444444444',
                name: 'Satay',
                restaurant: 'Grill Town',
                cuisines: const ['Malay'],
              ),
            ]);
          },
        );
        httpOverrides.addResponse(
          method: 'POST',
          url: '${ApiConfig.baseUrl}/preference/food/swipe',
          response: const StubHttpResponse(statusCode: 204, body: '{}'),
        );

        await pumpDiscover(tester);

        await tester.tap(find.byIcon(Icons.favorite_rounded));
        await settleUi(tester);

        expect(
          FavoritesStore.instance.contains(
            '33333333-3333-4333-8333-333333333333',
          ),
          isTrue,
        );
        expect(find.text('No more dishes 🎉'), findsOneWidget);
        expect(find.text('Refresh dishes'), findsOneWidget);

        await tester.tap(find.text('Refresh dishes'));
        await settleUi(tester);

        expect(find.text('Satay'), findsOneWidget);
      },
    );

    testWidgets(
      'failed nope swipe still advances the deck and keeps favorites empty',
      (tester) async {
        await saveSession();
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.foodBaseUrl}?userId=user-123',
          response: StubHttpResponse.json([
            foodJson(
              id: '55555555-5555-4555-8555-555555555555',
              name: 'Kimchi Fried Rice',
              restaurant: 'Seoul Kitchen',
              cuisines: const ['Korean'],
            ),
          ]),
        );
        httpOverrides.addResponse(
          method: 'POST',
          url: '${ApiConfig.baseUrl}/preference/food/swipe',
          response: const StubHttpResponse(statusCode: 500, body: '{}'),
        );

        await pumpDiscover(tester, showBottomNav: false);

        expect(find.text('Discover'), findsNothing);

        await tester.tap(find.byIcon(Icons.close_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('No more dishes 🎉'), findsOneWidget);
        expect(FavoritesStore.instance.favorites.value, isEmpty);
      },
    );

    testWidgets('dragging the card past the threshold triggers a like swipe', (
      tester,
    ) async {
      await saveSession();
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.foodBaseUrl}?userId=user-123',
        response: StubHttpResponse.json([
          foodJson(
            id: '66666666-6666-4666-8666-666666666666',
            name: 'Pad Thai',
            restaurant: 'Thai House',
            cuisines: const ['Thai'],
          ),
        ]),
      );
      httpOverrides.addResponse(
        method: 'POST',
        url: '${ApiConfig.baseUrl}/preference/food/swipe',
        response: const StubHttpResponse(statusCode: 204, body: '{}'),
      );

      await pumpDiscover(tester);

      await tester.drag(find.text('Pad Thai'), const Offset(220, 0));
      await settleUi(tester);

      expect(
        FavoritesStore.instance.contains(
          '66666666-6666-4666-8666-666666666666',
        ),
        isTrue,
      );
      expect(find.text('No more dishes 🎉'), findsOneWidget);
    });

    testWidgets(
      'quick preferences editor syncs successfully and persists locally',
      (tester) async {
        await saveSession();
        httpOverrides.addHandler(
          matcher: (request) =>
              request.method == 'GET' &&
              request.uri.toString() ==
                  '${ApiConfig.foodBaseUrl}?userId=user-123',
          handler: (_) => StubHttpResponse.json([
            foodJson(
              id: '77777777-7777-4777-8777-777777777777',
              name: 'Pho',
              restaurant: 'Hanoi Bowl',
              cuisines: const ['Vietnamese'],
            ),
          ]),
        );
        httpOverrides.addResponse(
          method: 'PUT',
          url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
          response: const StubHttpResponse(statusCode: 204, body: '{}'),
        );

        await pumpDiscover(tester);

        await tester.tap(find.byIcon(Icons.tune_rounded).first);
        await settleUi(tester);
        await tester.tap(find.text('Edit preferences'));
        await settleUi(tester);

        expect(find.text('Quick Preferences'), findsOneWidget);

        await tester.tap(find.text('Japanese'));
        await settleUi(tester);
        await tester.tap(find.text('Korean'));
        await settleUi(tester);
        await tester.tap(find.text('Budget Friendly'));
        await settleUi(tester);
        await tester.tap(find.text('Mild'));
        await settleUi(tester);
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await settleUi(tester);

        expect(find.text('Preferences updated.'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('prefs.cuisines'),
          equals(['Korean', 'Thai']),
        );
        expect(prefs.getString('prefs.budget'), 'low');
        expect(prefs.getString('prefs.spice'), 'Mild');

        final request = requestFor(
          (request) =>
              request.method == 'PUT' &&
              request.uri.toString() ==
                  '${ApiConfig.preferenceBaseUrl}/users/user-123',
        );
        expect(request, isNotNull);
        expect(
          jsonDecode(request!.body),
          equals({
            'cuisines': ['Korean', 'Thai'],
            'budget': 'low',
            'spiceLevel': 1,
          }),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'quick preferences editor falls back to local save when sync fails',
      (tester) async {
        await saveSession();
        httpOverrides.addHandler(
          matcher: (request) =>
              request.method == 'GET' &&
              request.uri.toString() ==
                  '${ApiConfig.foodBaseUrl}?userId=user-123',
          handler: (_) => StubHttpResponse.json([
            foodJson(
              id: '88888888-8888-4888-8888-888888888888',
              name: 'Bibimbap',
              restaurant: 'Seoul Kitchen',
              cuisines: const ['Korean'],
            ),
          ]),
        );
        httpOverrides.addResponse(
          method: 'PUT',
          url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
          response: const StubHttpResponse(statusCode: 500, body: '{}'),
        );

        await pumpDiscover(tester);

        await tester.tap(find.byIcon(Icons.tune_rounded).first);
        await settleUi(tester);
        await tester.tap(find.text('Edit preferences'));
        await settleUi(tester);

        await tester.tap(find.text('Japanese'));
        await settleUi(tester);
        await tester.tap(find.text('Premium'));
        await settleUi(tester);
        await tester.tap(find.text('Mild'));
        await settleUi(tester);
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await settleUi(tester);

        expect(
          find.text('Preferences saved locally (sync failed).'),
          findsOneWidget,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('prefs.cuisines'), equals(['Thai']));
        expect(prefs.getString('prefs.budget'), 'high');
        expect(prefs.getString('prefs.spice'), 'Mild');

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}

bool _listEquals(List<String>? actual, List<String> expected) {
  if (actual == null || actual.length != expected.length) {
    return false;
  }
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] != expected[i]) {
      return false;
    }
  }
  return true;
}

Future<void> settleUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump(const Duration(milliseconds: 250));
}
