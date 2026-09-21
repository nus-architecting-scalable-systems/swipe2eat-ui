import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/core/services/preferences_service.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';

import '../../test_helpers/http_test_overrides.dart';

void main() {
  Future<void> saveSession({String userId = 'user-123'}) {
    return TokenStorage.saveTokens(
      idToken: 'id-token',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      userId: userId,
    );
  }

  group('PreferencesService', () {
    late HttpTestOverrides httpOverrides;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      PreferencesService.preferencesUpdated.value = 0;
      httpOverrides = HttpTestOverrides();
      HttpOverrides.global = httpOverrides;
    });

    tearDown(() {
      HttpOverrides.global = null;
    });

    test('saveLocalPreferences stores cuisines and budget', () async {
      await PreferencesService.saveLocalPreferences(
        cuisines: ['Thai', 'Japanese', 'Indian'],
        budget: 'medium',
      );

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('prefs.cuisines') ?? [];
      final budgetStored = prefs.getString('prefs.budget');

      expect(stored, equals(['Thai', 'Japanese', 'Indian']));
      expect(budgetStored, equals('medium'));
    });

    test('getLocalPreferences returns saved preferences', () async {
      await PreferencesService.saveLocalPreferences(
        cuisines: ['Chinese', 'Western'],
        budget: 'low',
      );

      final prefs = await PreferencesService.getLocalPreferences();

      expect(prefs['cuisines'], equals(['Chinese', 'Western']));
      expect(prefs['budget'], equals('low'));
    });

    test(
      'getLocalPreferences returns defaults when no preferences stored',
      () async {
        final prefs = await PreferencesService.getLocalPreferences();

        expect(prefs['cuisines'], equals(['Chinese', 'Thai', 'Western']));
        expect(prefs['budget'], equals('low'));
        expect(prefs['spiceLevel'], equals('Medium'));
        expect(prefs['dietType'], equals('None'));
        expect(prefs['allergens'], isEmpty);
      },
    );

    test(
      'preferencesUpdated notifier increments when preferences change',
      () async {
        var notificationCount = 0;
        void listener() {
          notificationCount++;
        }

        PreferencesService.preferencesUpdated.addListener(listener);
        addTearDown(() {
          PreferencesService.preferencesUpdated.removeListener(listener);
        });

        await PreferencesService.saveLocalPreferences(
          cuisines: ['Thai'],
          budget: 'high',
        );

        expect(notificationCount, greaterThan(0));
      },
    );

    test('saveLocalPreferences with empty cuisines', () async {
      await PreferencesService.saveLocalPreferences(
        cuisines: const [],
        budget: 'low',
      );

      final prefs = await PreferencesService.getLocalPreferences();
      expect(prefs['cuisines'], isEmpty);
    });

    test('saveLocalPreferences updates existing preferences', () async {
      await PreferencesService.saveLocalPreferences(
        cuisines: ['Thai'],
        budget: 'low',
      );
      await PreferencesService.saveLocalPreferences(
        cuisines: ['Japanese', 'Indian'],
        budget: 'high',
      );

      final prefs = await PreferencesService.getLocalPreferences();
      expect(prefs['cuisines'], equals(['Japanese', 'Indian']));
      expect(prefs['budget'], equals('high'));
    });

    test('budget values map correctly', () async {
      for (final value in const ['low', 'medium', 'high']) {
        SharedPreferences.setMockInitialValues({});
        await PreferencesService.saveLocalPreferences(
          cuisines: ['Thai'],
          budget: value,
        );

        final prefs = await PreferencesService.getLocalPreferences();
        expect(prefs['budget'], equals(value));
      }
    });

    test('multiple cuisine selections are preserved', () async {
      const cuisines = [
        'Thai',
        'Chinese',
        'Japanese',
        'Italian',
        'Indian',
        'Vietnamese',
      ];

      await PreferencesService.saveLocalPreferences(
        cuisines: cuisines,
        budget: 'medium',
      );

      final prefs = await PreferencesService.getLocalPreferences();
      expect(prefs['cuisines'], equals(cuisines));
    });

    test('saveLocalPreferences stores normalized spice level', () async {
      await PreferencesService.saveLocalPreferences(
        cuisines: ['Thai'],
        budget: 'medium',
        spiceLevel: 'hot',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('prefs.spice'), equals('Hot'));
    });

    test(
      'saveLocalPreferences does not overwrite spice when omitted',
      () async {
        await PreferencesService.saveLocalPreferences(
          cuisines: ['Thai'],
          budget: 'low',
          spiceLevel: 'mild',
        );
        await PreferencesService.saveLocalPreferences(
          cuisines: ['Japanese'],
          budget: 'high',
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('prefs.spice'), equals('Mild'));
      },
    );

    test(
      'saveLocalDietaryPreferences stores diet type and sorted allergens',
      () async {
        await PreferencesService.saveLocalDietaryPreferences(
          dietType: 'Vegetarian',
          allergens: const ['Soy', 'Peanut'],
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('prefs.dietType'), equals('Vegetarian'));
        expect(
          prefs.getStringList('prefs.allergens'),
          equals(['Peanut', 'Soy']),
        );
      },
    );

    test('getLocalPreferences returns saved dietary preferences', () async {
      await PreferencesService.saveLocalDietaryPreferences(
        dietType: 'Vegan',
        allergens: const ['Gluten'],
      );

      final prefs = await PreferencesService.getLocalPreferences();

      expect(prefs['dietType'], equals('Vegan'));
      expect(prefs['allergens'], equals(['Gluten']));
    });

    test('fetchDietaryOptions returns parsed values', () async {
      await saveSession();
      httpOverrides.addResponse(
        method: 'GET',
        url: ApiConfig.dietaryOptionsUrl,
        response: StubHttpResponse.json({
          'dietType': ['Omnivore', 'Vegan'],
          'allergens': ['Soy', 'Gluten'],
        }),
      );

      final options = await PreferencesService.fetchDietaryOptions();

      expect(options.dietType, equals(['Omnivore', 'Vegan']));
      expect(options.allergens, equals(['Soy', 'Gluten']));
      expect(
        httpOverrides.requests.single.headers['authorization'],
        'Bearer access-token',
      );
    });

    test('fetchDietaryOptions throws on non-200 response', () async {
      httpOverrides.addResponse(
        method: 'GET',
        url: ApiConfig.dietaryOptionsUrl,
        response: const StubHttpResponse(statusCode: 500, body: '{}'),
      );

      expect(PreferencesService.fetchDietaryOptions, throwsA(isA<Exception>()));
    });

    test('hasUserPreferences returns false when not logged in', () async {
      expect(await PreferencesService.hasUserPreferences(), isFalse);
      expect(httpOverrides.requests, isEmpty);
    });

    test(
      'hasUserPreferences returns true for a complete backend payload',
      () async {
        await saveSession();
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
          response: StubHttpResponse.json({
            'cuisines': ['Thai'],
            'budget': 'medium',
            'spiceLevel': 2,
          }),
        );

        expect(await PreferencesService.hasUserPreferences(), isTrue);
      },
    );

    test('hasUserPreferences returns false for incomplete payload', () async {
      await saveSession();
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
        response: StubHttpResponse.json({
          'cuisines': const [],
          'budget': 'medium',
          'spiceLevel': 2,
        }),
      );

      expect(await PreferencesService.hasUserPreferences(), isFalse);
    });

    test(
      'hasUserPreferences returns false for invalid JSON, 404, and exceptions',
      () async {
        await saveSession(userId: 'invalid-json');
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/users/invalid-json',
          response: const StubHttpResponse(statusCode: 200, body: 'not-json'),
        );

        expect(await PreferencesService.hasUserPreferences(), isFalse);

        await saveSession(userId: 'missing');
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/users/missing',
          response: const StubHttpResponse(statusCode: 404, body: '{}'),
        );
        expect(await PreferencesService.hasUserPreferences(), isFalse);

        await saveSession(userId: 'throws');
        expect(await PreferencesService.hasUserPreferences(), isFalse);
      },
    );

    test(
      'updatePreferences sends normalized spice level and returns true on success statuses',
      () async {
        await saveSession();

        for (final statusCode in const [200, 204]) {
          httpOverrides.clear();
          httpOverrides.addResponse(
            method: 'PUT',
            url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
            response: StubHttpResponse(statusCode: statusCode, body: '{}'),
          );

          final updated = await PreferencesService.updatePreferences(
            cuisines: const ['Thai', 'Japanese'],
            budget: 'high',
            spiceLevel: 'spicy',
          );

          expect(updated, isTrue);
          expect(
            jsonDecode(httpOverrides.requests.single.body),
            equals({
              'cuisines': ['Thai', 'Japanese'],
              'budget': 'high',
              'spiceLevel': 3,
            }),
          );
        }
      },
    );

    test(
      'updatePreferences returns false when user or request fails',
      () async {
        expect(
          await PreferencesService.updatePreferences(
            cuisines: const ['Thai'],
            budget: 'low',
          ),
          isFalse,
        );

        await saveSession();
        httpOverrides.addResponse(
          method: 'PUT',
          url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
          response: const StubHttpResponse(statusCode: 500, body: '{}'),
        );

        expect(
          await PreferencesService.updatePreferences(
            cuisines: const ['Thai'],
            budget: 'low',
          ),
          isFalse,
        );
      },
    );

    test(
      'updateDietaryPreferences sends allergies payload and handles failure',
      () async {
        await saveSession();
        httpOverrides.addResponse(
          method: 'PUT',
          url: '${ApiConfig.preferenceBaseUrl}/dietary/users/user-123',
          response: const StubHttpResponse(statusCode: 204, body: '{}'),
        );

        expect(
          await PreferencesService.updateDietaryPreferences(
            dietType: 'Vegan',
            allergens: const ['Soy', 'Peanut'],
          ),
          isTrue,
        );
        expect(
          jsonDecode(httpOverrides.requests.single.body),
          equals({
            'dietType': 'Vegan',
            'allergies': ['Soy', 'Peanut'],
          }),
        );

        httpOverrides.clear();
        httpOverrides.addResponse(
          method: 'PUT',
          url: '${ApiConfig.preferenceBaseUrl}/dietary/users/user-123',
          response: const StubHttpResponse(statusCode: 500, body: '{}'),
        );
        expect(
          await PreferencesService.updateDietaryPreferences(
            dietType: 'Vegan',
            allergens: const ['Soy'],
          ),
          isFalse,
        );
      },
    );

    test(
      'fetchPreferencesFromBackend parses array cuisines and saves normalized spice level',
      () async {
        await saveSession();
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
          response: StubHttpResponse.json({
            'cuisines': ['Thai', 'Japanese'],
            'budget': 'medium',
            'spiceLevel': 1,
          }),
        );

        final result = await PreferencesService.fetchPreferencesFromBackend();

        expect(
          result,
          equals({
            'cuisines': ['Thai', 'Japanese'],
            'budget': 'medium',
            'spiceLevel': 'Mild',
          }),
        );

        final prefs = await PreferencesService.getLocalPreferences();
        expect(prefs['cuisines'], equals(['Thai', 'Japanese']));
        expect(prefs['spiceLevel'], equals('Mild'));
      },
    );

    test(
      'fetchPreferencesFromBackend handles string cuisines and null-on-error cases',
      () async {
        await saveSession(userId: 'single');
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/users/single',
          response: StubHttpResponse.json({
            'cuisines': 'Korean',
            'budget': 'high',
            'spice': 'hot',
          }),
        );

        final single = await PreferencesService.fetchPreferencesFromBackend();
        expect(
          single,
          equals({
            'cuisines': ['Korean'],
            'budget': 'high',
            'spiceLevel': 'Hot',
          }),
        );

        await saveSession(userId: 'bad-status');
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/users/bad-status',
          response: const StubHttpResponse(statusCode: 500, body: '{}'),
        );
        expect(await PreferencesService.fetchPreferencesFromBackend(), isNull);

        await saveSession(userId: 'throws');
        expect(await PreferencesService.fetchPreferencesFromBackend(), isNull);
      },
    );

    test(
      'sendSwipePreference returns false when user is unavailable',
      () async {
        expect(
          await PreferencesService.sendSwipePreference(
            foodId: 'food-1',
            liked: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'sendSwipePreference accepts 200, 201, and 204 success responses',
      () async {
        await saveSession();

        for (final statusCode in const [200, 201, 204]) {
          httpOverrides.clear();
          httpOverrides.addResponse(
            method: 'POST',
            url: '${ApiConfig.preferenceBaseUrl}/foods/swipe',
            response: StubHttpResponse(statusCode: statusCode, body: '{}'),
          );

          final sent = await PreferencesService.sendSwipePreference(
            foodId: 'food-1',
            liked: true,
          );

          expect(sent, isTrue);
          expect(
            jsonDecode(httpOverrides.requests.single.body),
            equals({'userId': 'user-123', 'foodId': 'food-1', 'status': true}),
          );
        }
      },
    );

    test(
      'sendSwipePreference returns false for failed responses and exceptions',
      () async {
        await saveSession();
        httpOverrides.addResponse(
          method: 'POST',
          url: '${ApiConfig.preferenceBaseUrl}/foods/swipe',
          response: const StubHttpResponse(statusCode: 500, body: '{}'),
        );

        expect(
          await PreferencesService.sendSwipePreference(
            foodId: 'food-1',
            liked: false,
          ),
          isFalse,
        );

        httpOverrides.clear();
        expect(
          await PreferencesService.sendSwipePreference(
            foodId: 'food-1',
            liked: false,
          ),
          isFalse,
        );
      },
    );

    test('queueSwipePreference preserves backend submission order', () async {
      await saveSession();
      final order = <String>[];
      final blocker = Completer<void>();
      var callCount = 0;

      httpOverrides.addHandler(
        matcher: (request) =>
            request.method == 'POST' &&
            request.uri.toString() ==
                '${ApiConfig.preferenceBaseUrl}/foods/swipe',
        handler: (request) async {
          callCount++;
          order.add(jsonDecode(request.body)['foodId'] as String);
          if (callCount == 1) {
            await blocker.future;
          }
          return const StubHttpResponse(statusCode: 204, body: '{}');
        },
      );

      final first = PreferencesService.queueSwipePreference(
        foodId: 'first',
        liked: true,
      );
      final second = PreferencesService.queueSwipePreference(
        foodId: 'second',
        liked: false,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(order, equals(['first']));

      blocker.complete();

      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(order, equals(['first', 'second']));
    });

    test('queueSwipePreference resolves false when sync fails', () async {
      await saveSession();

      final result = await PreferencesService.queueSwipePreference(
        foodId: 'food-1',
        liked: true,
      );

      expect(result, isFalse);
    });
  });
}
