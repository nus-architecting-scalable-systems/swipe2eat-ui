import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/core/config/api_config.dart';
import 'package:swipe2eat_ui/core/services/preferences_service.dart';
import 'package:swipe2eat_ui/core/state/favorites_store.dart';
import 'package:swipe2eat_ui/features/auth/services/token_storage.dart';
import 'package:swipe2eat_ui/features/profile/profile_screen.dart';
import 'package:swipe2eat_ui/models/food_item.dart';

import '../../test_helpers/http_test_overrides.dart';

void main() {
  group('ProfileScreen', () {
    late HttpTestOverrides httpOverrides;

    String createToken(Map<String, dynamic> payload) {
      final encodedPayload = base64Url
          .encode(utf8.encode(jsonEncode(payload)))
          .replaceAll('=', '');
      return 'e30.$encodedPayload.sig';
    }

    Future<void> saveSession({
      Map<String, dynamic>? tokenPayload,
      String accessToken = 'access-token',
      String refreshToken = 'refresh-token',
      String userId = 'user-123',
    }) async {
      await TokenStorage.saveTokens(
        idToken: createToken(tokenPayload ?? {'name': 'Taylor'}),
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        email: 'user@example.com',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user.backendCreated.$userId', true);
    }

    void seedLocalPreferences({
      List<String> cuisines = const ['Thai', 'Japanese'],
      String? budget = 'medium',
      String? budgetLabel,
      String spice = 'Hot',
      String dietType = 'Vegetarian',
      List<String> allergens = const ['Peanut'],
    }) {
      final values = <String, Object>{
        'prefs.cuisines': cuisines,
        'prefs.spice': spice,
        'prefs.dietType': dietType,
        'prefs.allergens': allergens,
      };

      if (budget != null) {
        values['prefs.budget'] = budget;
      }
      if (budgetLabel != null) {
        values['prefs.budgetLabel'] = budgetLabel;
      }

      SharedPreferences.setMockInitialValues(values);
    }

    void stubProfileSequence(List<Map<String, dynamic>> responses) {
      var index = 0;
      httpOverrides.addHandler(
        matcher: (request) =>
            request.method == 'GET' &&
            request.uri.toString() == '${ApiConfig.userBaseUrl}/user-123',
        handler: (_) {
          final current =
              responses[index < responses.length
                  ? index
                  : responses.length - 1];
          index++;
          return StubHttpResponse.json(current);
        },
      );
    }

    CapturedHttpRequest? requestFor(String method, String url) {
      return httpOverrides.lastRequestMatching(
        (request) =>
            request.method == method.toUpperCase() &&
            request.uri.toString() == url,
      );
    }

    Future<void> pumpProfile(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/sign-in': (_) => const Scaffold(body: Text('Sign In Screen')),
          },
          home: const Scaffold(body: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openAction(WidgetTester tester, String label) async {
      final target = find.text(label).first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    FoodItem sampleFavorite({
      String id = 'food-1',
      String name = 'Pad Thai',
      String restaurant = 'Thai House',
    }) {
      return FoodItem(
        id: id,
        name: name,
        restaurant: restaurant,
        imageUrl: 'https://example.com/pad-thai.jpg',
        rating: 4.7,
        price: 12.5,
        description: 'Noodles',
        spiceLevel: 2,
        budgetLevel: 2,
        tags: const ['Thai'],
      );
    }

    setUp(() {
      seedLocalPreferences();
      PreferencesService.preferencesUpdated.value = 0;
      FavoritesStore.instance.clear();
      httpOverrides = HttpTestOverrides();
      HttpOverrides.global = httpOverrides;
    });

    tearDown(() {
      FavoritesStore.instance.clear();
      HttpOverrides.global = null;
    });

    testWidgets(
      'loads display name, backend profile, and local preferences on startup',
      (tester) async {
        seedLocalPreferences(budget: null, budgetLabel: 'Premium');
        await saveSession(tokenPayload: {'given_name': 'Casey'});
        FavoritesStore.instance.add(sampleFavorite());
        FavoritesStore.instance.add(
          sampleFavorite(
            id: 'food-2',
            name: 'Laksa',
            restaurant: 'Spice House',
          ),
        );
        stubProfileSequence([
          {'gender': 'non-binary', 'dateOfBirth': '1992-03-04'},
        ]);

        await pumpProfile(tester);

        expect(find.text('Casey'), findsOneWidget);
        expect(find.text('2 favorites saved'), findsOneWidget);
        expect(find.text('Thai, Japanese'), findsOneWidget);
        expect(find.text('Hot'), findsOneWidget);
        expect(find.text(r'$$$'), findsOneWidget);
        expect(find.text('non-binary'), findsOneWidget);
        expect(find.text('1992-03-04'), findsOneWidget);
      },
    );

    testWidgets('updates profile info and refreshes the displayed values', (
      tester,
    ) async {
      await saveSession();
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
        {'gender': 'male', 'dateOfBirth': '1990-01-02'},
      ]);
      httpOverrides.addResponse(
        method: 'PUT',
        url: '${ApiConfig.userBaseUrl}/me',
        response: const StubHttpResponse(statusCode: 200, body: '{}'),
      );

      await pumpProfile(tester);
      await openAction(tester, 'Edit Profile Info');

      await tester.tap(find.text('female').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('male').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Profile updated successfully'), findsOneWidget);
      expect(find.text('male'), findsOneWidget);
      expect(find.text('1990-01-02'), findsOneWidget);

      final request = requestFor('PUT', '${ApiConfig.userBaseUrl}/me');
      expect(request, isNotNull);
      expect(
        jsonDecode(request!.body),
        equals({'gender': 'male', 'dateOfBirth': '1995-04-12'}),
      );
    });

    testWidgets('shows an error snackbar when profile info update fails', (
      tester,
    ) async {
      await saveSession();
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
      ]);
      httpOverrides.addResponse(
        method: 'PUT',
        url: '${ApiConfig.userBaseUrl}/me',
        response: const StubHttpResponse(statusCode: 500, body: '{}'),
      );

      await pumpProfile(tester);
      await openAction(tester, 'Edit Profile Info');

      await tester.tap(find.text('female').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('male').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Failed to update profile. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('female'), findsOneWidget);
    });

    testWidgets(
      'edit preferences dialog syncs to backend and refreshes local displays',
      (tester) async {
        await saveSession();
        stubProfileSequence([
          {'gender': 'female', 'dateOfBirth': '1995-04-12'},
        ]);
        httpOverrides.addResponse(
          method: 'PUT',
          url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
          response: const StubHttpResponse(statusCode: 204, body: '{}'),
        );
        httpOverrides.addResponse(
          method: 'GET',
          url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
          response: StubHttpResponse.json({
            'cuisines': ['Chinese', 'Thai'],
            'budget': 'high',
            'spiceLevel': 1,
          }),
        );

        await pumpProfile(tester);
        await openAction(tester, 'Edit Preferences');

        await tester.tap(find.text('Japanese'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chinese'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Premium'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mild'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(
          find.text('Preferences updated and discover screen refreshed'),
          findsOneWidget,
        );
        expect(find.text('Chinese, Thai'), findsOneWidget);
        expect(find.text(r'$$$'), findsOneWidget);
        expect(find.text('Mild'), findsOneWidget);

        final request = requestFor(
          'PUT',
          '${ApiConfig.preferenceBaseUrl}/users/user-123',
        );
        expect(request, isNotNull);
        expect(
          jsonDecode(request!.body),
          equals({
            'cuisines': ['Chinese', 'Thai'],
            'budget': 'high',
            'spiceLevel': 1,
          }),
        );
      },
    );

    testWidgets(
      'edit preferences dialog falls back to local persistence on sync failure',
      (tester) async {
        seedLocalPreferences(
          cuisines: const ['Thai'],
          budget: 'low',
          spice: 'Medium',
        );
        await saveSession();
        stubProfileSequence([
          {'gender': 'female', 'dateOfBirth': '1995-04-12'},
        ]);
        httpOverrides.addResponse(
          method: 'PUT',
          url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
          response: const StubHttpResponse(statusCode: 500, body: '{}'),
        );

        await pumpProfile(tester);
        await openAction(tester, 'Edit Preferences');

        await tester.tap(find.text('Korean'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mid Range'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hot'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(
          find.text('Preferences saved locally (sync failed)'),
          findsOneWidget,
        );
        expect(find.text('Korean, Thai'), findsOneWidget);
        expect(find.text(r'$$'), findsOneWidget);
        expect(find.text('Hot'), findsOneWidget);

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('prefs.cuisines'),
          equals(['Korean', 'Thai']),
        );
        expect(prefs.getString('prefs.budget'), 'medium');
        expect(prefs.getString('prefs.spice'), 'Hot');
      },
    );

    testWidgets('cuisine editor updates preferences and shows success state', (
      tester,
    ) async {
      seedLocalPreferences(
        cuisines: const ['Thai'],
        budget: 'low',
        spice: 'Medium',
      );
      await saveSession();
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
      ]);
      httpOverrides.addResponse(
        method: 'PUT',
        url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
        response: const StubHttpResponse(statusCode: 204, body: '{}'),
      );
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
        response: StubHttpResponse.json({
          'cuisines': ['Japanese', 'Thai'],
          'budget': 'low',
          'spiceLevel': 2,
        }),
      );

      await pumpProfile(tester);
      await openAction(tester, 'Cuisines');

      expect(find.text('Edit Cuisines'), findsOneWidget);
      await tester.tap(find.text('Japanese'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Cuisine preferences updated.'), findsOneWidget);
      expect(find.text('Japanese, Thai'), findsOneWidget);
    });

    testWidgets('spice editor saves locally when backend sync fails', (
      tester,
    ) async {
      seedLocalPreferences(cuisines: const ['Thai'], budget: 'low', spice: '1');
      await saveSession();
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
      ]);
      httpOverrides.addResponse(
        method: 'PUT',
        url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
        response: const StubHttpResponse(statusCode: 500, body: '{}'),
      );

      await pumpProfile(tester);
      await openAction(tester, 'Spice Level');

      expect(find.text('Edit Spice Level'), findsOneWidget);
      await tester.tap(find.text('Hot').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Spice preference saved locally (sync failed).'),
        findsOneWidget,
      );
      expect(find.text('Hot'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('prefs.spice'), 'Hot');
    });

    testWidgets('budget editor updates preferences and refreshes the budget', (
      tester,
    ) async {
      seedLocalPreferences(
        cuisines: const ['Thai'],
        budget: 'low',
        spice: 'Hot',
      );
      await saveSession();
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
      ]);
      httpOverrides.addResponse(
        method: 'PUT',
        url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
        response: const StubHttpResponse(statusCode: 204, body: '{}'),
      );
      httpOverrides.addResponse(
        method: 'GET',
        url: '${ApiConfig.preferenceBaseUrl}/users/user-123',
        response: StubHttpResponse.json({
          'cuisines': ['Thai'],
          'budget': 'high',
          'spiceLevel': 3,
        }),
      );

      await pumpProfile(tester);
      await openAction(tester, 'Budget');

      expect(find.text('Edit Budget'), findsOneWidget);
      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Budget preference updated.'), findsOneWidget);
      expect(find.text(r'$$$'), findsOneWidget);
    });

    testWidgets('confirming logout clears local state and navigates', (
      tester,
    ) async {
      await saveSession(accessToken: '');
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
      ]);
      FavoritesStore.instance.add(sampleFavorite());

      await pumpProfile(tester);
      await openAction(tester, 'Logout');

      expect(find.text('Are you sure you want to logout?'), findsOneWidget);

      await tester.tap(find.text('Logout').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth.userId'), isNull);
      expect(prefs.getString('auth.accessToken'), isNull);
      expect(prefs.getString('auth.idToken'), isNull);
      expect(prefs.getString('auth.refreshToken'), isNull);
      expect(prefs.getString('auth.email'), isNull);
      expect(prefs.getBool('user.backendCreated.user-123'), isNull);
      expect(FavoritesStore.instance.favorites.value, isEmpty);
      expect(find.text('Sign In Screen'), findsOneWidget);
    });

    testWidgets('cancelling logout keeps local state intact', (tester) async {
      await saveSession(accessToken: '');
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
      ]);
      FavoritesStore.instance.add(sampleFavorite());

      await pumpProfile(tester);
      await openAction(tester, 'Logout');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth.userId'), equals('user-123'));
      expect(prefs.getString('auth.refreshToken'), equals('refresh-token'));
      expect(prefs.getBool('user.backendCreated.user-123'), isTrue);
      expect(FavoritesStore.instance.contains('food-1'), isTrue);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sign In Screen'), findsNothing);
    });

    testWidgets('shows an error when backend account deletion fails', (
      tester,
    ) async {
      await saveSession();
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
      ]);
      httpOverrides.addResponse(
        method: 'DELETE',
        url: '${ApiConfig.userBaseUrl}/user-123',
        response: const StubHttpResponse(statusCode: 500, body: '{}'),
      );

      await pumpProfile(tester);
      await openAction(tester, 'Delete Account');

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Unable to delete account. Please try again.'),
        findsOneWidget,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth.userId'), equals('user-123'));
      expect(find.text('Sign In Screen'), findsNothing);
    });

    testWidgets('deleting the account clears local data and navigates out', (
      tester,
    ) async {
      await saveSession();
      FavoritesStore.instance.add(sampleFavorite());
      stubProfileSequence([
        {'gender': 'female', 'dateOfBirth': '1995-04-12'},
      ]);
      httpOverrides.addResponse(
        method: 'DELETE',
        url: '${ApiConfig.userBaseUrl}/user-123',
        response: const StubHttpResponse(statusCode: 204, body: '{}'),
      );
      await pumpProfile(tester);
      await openAction(tester, 'Delete Account');

      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(find.text('Sign In Screen'), findsOneWidget);
      expect(prefs.getString('auth.userId'), isNull);
      expect(prefs.getString('prefs.budget'), isNull);
      expect(prefs.getString('prefs.spice'), isNull);
      expect(prefs.getStringList('prefs.cuisines'), isNull);
      expect(prefs.getString('prefs.dietType'), isNull);
      expect(prefs.getStringList('prefs.allergens'), isNull);
      expect(FavoritesStore.instance.favorites.value, isEmpty);
    });
  });
}
