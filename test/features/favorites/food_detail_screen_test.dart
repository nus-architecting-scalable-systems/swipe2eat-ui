import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipe2eat_ui/features/favorites/food_detail_screen.dart';
import 'package:swipe2eat_ui/core/state/favorites_store.dart';
import 'package:swipe2eat_ui/models/food_item.dart';
import 'dart:io';
import '../../test_helpers/network_image_stub.dart';

void main() {
  group('FoodDetailScreen widget tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'auth.userId': 'user-123',
        'auth.idToken': 'id-token',
        'auth.accessToken': 'access-token',
      });
      FavoritesStore.instance.clear();
    });

    setUpAll(() {
      HttpOverrides.global = TestHttpOverrides();
    });

    tearDownAll(() {
      HttpOverrides.global = null;
    });

    Future<void> pumpDetail(WidgetTester tester, FoodItem item) async {
      final app = MaterialApp(
        home: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute(builder: (_) => FoodDetailScreen(item: item)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('displays item details', (tester) async {
      final item = FoodItem(
        id: '1',
        name: 'Sushi Deluxe',
        restaurant: 'Sushi Bar',
        imageUrl: 'https://example.com/sushi.jpg',
        rating: 4.9,
        price: 18.99,
        description: 'Fresh sushi platter',
        spiceLevel: 0,
        budgetLevel: 2,
        tags: const ['Japanese', 'Seafood'],
      );

      await pumpDetail(tester, item);

      expect(find.text('Sushi Deluxe'), findsOneWidget);
      expect(find.text('Sushi Bar'), findsWidgets);
      expect(find.text(item.description), findsOneWidget);
      expect(find.text('\$${item.price.toStringAsFixed(2)}'), findsOneWidget);
      // tags present
      expect(find.text('Japanese'), findsOneWidget);
      expect(find.text('Seafood'), findsOneWidget);
    });

    testWidgets('uses restaurant name as map link when address is missing', (
      tester,
    ) async {
      final item = FoodItem(
        id: '1',
        name: 'Thai Fried Rice',
        restaurant: 'Dunman Food Centre',
        imageUrl: 'https://example.com/thai-fried-rice.jpg',
        rating: 4.1,
        price: 5.93,
        description: 'Thai Fried Rice description',
        spiceLevel: 0,
        budgetLevel: 1,
        tags: const ['Thai'],
      );

      await pumpDetail(tester, item);

      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(
        find.byKey(const ValueKey('food-detail-map-location-link')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('food-detail-map-location-link')),
          matching: find.text('Dunman Food Centre'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('back button pops without changing favorites', (tester) async {
      final item = FoodItem(
        id: '1',
        name: 'Sushi Deluxe',
        restaurant: 'Sushi Bar',
        imageUrl: 'https://example.com/sushi.jpg',
        rating: 4.9,
        price: 18.99,
        description: 'Fresh sushi platter',
        spiceLevel: 0,
        budgetLevel: 2,
        tags: const ['Japanese', 'Seafood'],
      );

      await pumpDetail(tester, item);

      // Initially not favorite
      expect(FavoritesStore.instance.contains(item.id), false);

      // Tap back button (arrow)
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      // Should be popped and still not favorite
      expect(FavoritesStore.instance.contains(item.id), false);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('tapping favorite button adds item then pops', (tester) async {
      final item = FoodItem(
        id: '1',
        name: 'Sushi Deluxe',
        restaurant: 'Sushi Bar',
        imageUrl: 'https://example.com/sushi.jpg',
        rating: 4.9,
        price: 18.99,
        description: 'Fresh sushi platter',
        spiceLevel: 0,
        budgetLevel: 2,
        tags: const ['Japanese', 'Seafood'],
      );

      await pumpDetail(tester, item);

      // Initially not favorite
      expect(FavoritesStore.instance.contains(item.id), false);

      // Favorite icon should be border initially
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // Tap favorite icon
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      // Screen pops back to previous route
      expect(find.text('open'), findsOneWidget);

      // Item should have been added to favorites
      expect(FavoritesStore.instance.contains(item.id), true);
    });

    testWidgets('tapping favorite when already favored removes it (and pops)', (
      tester,
    ) async {
      final item = FoodItem(
        id: '1',
        name: 'Sushi Deluxe',
        restaurant: 'Sushi Bar',
        imageUrl: 'https://example.com/sushi.jpg',
        rating: 4.9,
        price: 18.99,
        description: 'Fresh sushi platter',
        spiceLevel: 0,
        budgetLevel: 2,
        tags: const ['Japanese', 'Seafood'],
      );

      // pre-add item
      FavoritesStore.instance.add(item);
      expect(FavoritesStore.instance.contains(item.id), true);

      await pumpDetail(tester, item);

      // Favorite icon should show filled heart
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Tap favorite icon to remove
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pumpAndSettle();

      // Screen popped
      expect(find.text('open'), findsOneWidget);

      // Item removed
      expect(FavoritesStore.instance.contains(item.id), false);
    });
  });
}

// Using shared TestHttpOverrides from test_helpers/network_image_stub.dart
