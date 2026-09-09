import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';
import 'package:swipe2eat_ui/features/discover/services/food_service.dart';

import '../../test_helpers/http_test_overrides.dart';

void main() {
  group('FoodService.fetchFoods', () {
    late HttpTestOverrides httpOverrides;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      httpOverrides = HttpTestOverrides();
      HttpOverrides.global = httpOverrides;
    });

    tearDown(() {
      HttpOverrides.global = null;
    });

    test('returns personalized foods before fallback query', () async {
      await TokenStorage.saveTokens(
        idToken: 'id-token',
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
        userId: 'user-123',
      );

      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.foodBaseUrl}?userId=user-123',
        response: StubHttpResponse.json([
          {
            'id': '11111111-1111-4111-8111-111111111111',
            'name': 'Laksa',
            'restaurantName': 'Spice House',
            'imageKey': 'laksa.png',
            'rating': 4.8,
            'price': 9.5,
            'description': 'Rich coconut broth',
            'cuisine': ['Malay'],
          },
        ]),
      );

      final foods = await FoodService.fetchFoods(
        cuisines: const ['Thai', 'Japanese'],
        budget: 'medium',
        spiceLevel: 'Hot',
      );

      expect(foods, hasLength(1));
      expect(foods.single.name, 'Laksa');
      expect(httpOverrides.requests, hasLength(1));
      expect(
        httpOverrides.requests.single.headers['authorization'],
        'Bearer access-token',
      );
    });

    test(
      'falls back to cuisine and spice filters when personalized data is empty',
      () async {
        await TokenStorage.saveTokens(
          idToken: 'id-token',
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          userId: 'user-123',
        );

        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.foodBaseUrl}?userId=user-123',
          response: StubHttpResponse.json(const <Object>[]),
        );
        httpOverrides.addResponse(
          method: 'GET',
          url:
              '${ApiConfig.foodBaseUrl}?budget=medium&cuisines=Thai&cuisines=Japanese&spiceLevel=3',
          response: StubHttpResponse.json({
            'foods': [
              {
                'id': '22222222-2222-4222-8222-222222222222',
                'name': 'Tom Yum',
                'restaurantName': 'Thai Express',
                'imageKey': 'tom-yum.png',
                'rating': '4.3',
                'price': '13.20',
                'description': 'Tangy soup',
              },
            ],
          }),
        );

        final foods = await FoodService.fetchFoods(
          cuisines: const ['Thai', 'Japanese'],
          budget: 'medium',
          spiceLevel: 'Hot',
        );

        expect(foods, hasLength(1));
        expect(foods.single.name, 'Tom Yum');
        expect(httpOverrides.requests, hasLength(2));
        expect(
          httpOverrides.requests[1].uri.query,
          'budget=medium&cuisines=Thai&cuisines=Japanese&spiceLevel=3',
        );
      },
    );

    test(
      'parses list responses from raw list, data, and foods containers',
      () async {
        const validIdA = '33333333-3333-4333-8333-333333333333';
        const validIdB = '44444444-4444-4444-8444-444444444444';
        const validIdC = '55555555-5555-4555-8555-555555555555';
        final urls = <String>[
          '${ApiConfig.foodBaseUrl}?budget=low&spiceLevel=1',
          '${ApiConfig.foodBaseUrl}?budget=medium&spiceLevel=2',
          '${ApiConfig.foodBaseUrl}?budget=high&spiceLevel=3',
        ];
        final payloads = <Object>[
          [
            {
              'id': validIdA,
              'name': 'Congee',
              'restaurantName': 'Breakfast Club',
            },
          ],
          {
            'data': [
              {
                'id': validIdB,
                'name': 'Bibimbap',
                'restaurantName': 'Seoul Kitchen',
              },
            ],
          },
          {
            'foods': [
              {
                'id': validIdC,
                'name': 'Steak',
                'restaurantName': 'Prime Grill',
              },
            ],
          },
        ];

        for (var i = 0; i < urls.length; i++) {
          httpOverrides.addResponse(
            method: 'GET',
            url: urls[i],
            response: StubHttpResponse.json(payloads[i]),
          );
        }

        final first = await FoodService.fetchFoods(
          cuisines: const [],
          budget: 'low',
          spiceLevel: 'Mild',
        );
        final second = await FoodService.fetchFoods(
          cuisines: const [],
          budget: 'medium',
          spiceLevel: 'Medium',
        );
        final third = await FoodService.fetchFoods(
          cuisines: const [],
          budget: 'high',
          spiceLevel: 'Hot',
        );

        expect(first.single.id, validIdA);
        expect(second.single.id, validIdB);
        expect(third.single.id, validIdC);
      },
    );

    test(
      'drops invalid ids and applies JSON fallbacks for missing fields',
      () async {
        final droppedBefore = FoodService.invalidFoodIdDropCount;

        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.foodBaseUrl}?budget=medium&spiceLevel=2',
          response: StubHttpResponse.json([
            {'id': 'not-a-uuid', 'name': 'Ignore me'},
            {'name': 'Missing ID'},
            {'id': '66666666-6666-4666-8666-666666666666', 'price': '25.75'},
          ]),
        );

        final foods = await FoodService.fetchFoods(
          cuisines: const [],
          budget: 'medium',
          spiceLevel: 'Medium',
        );

        expect(foods, hasLength(1));
        final item = foods.single;
        expect(item.name, 'Unknown Dish');
        expect(item.restaurant, 'Unknown');
        expect(item.description, 'A delicious pick based on your preferences.');
        expect(item.imageUrl, contains('pexels-photo-1640777'));
        expect(item.rating, 4.5);
        expect(item.price, 25.75);
        expect(item.budgetLevel, 3);
        expect(item.spiceLevel, 2);
        expect(item.tags, isEmpty);
        expect(FoodService.lastInvalidFoodIdDropCount, 2);
        expect(FoodService.invalidFoodIdDropCount, droppedBefore + 2);
      },
    );

    test('throws when the backend response is not successful', () async {
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.foodBaseUrl}?budget=low&spiceLevel=1',
        response: const StubHttpResponse(statusCode: 503, body: 'unavailable'),
      );

      expect(
        () => FoodService.fetchFoods(
          cuisines: const [],
          budget: 'low',
          spiceLevel: 'Mild',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
