# Swipe2Eat UI Test Suite

This document describes the current test layout and the commands used to verify the app.

## Current Status

Latest local verification from this workspace:

```text
flutter analyze: no issues
flutter test: 298 tests passed
flutter test integration_test/favorites_location_link_test.dart: 2 tests passed
```

Test files:

- 38 unit/widget test files under `test/`
- 2 integration test files under `integration_test/`
- shared HTTP/image stubs under `test/test_helpers/`

## Test Layout

```text
test/
  app_test.dart
  main_test.dart
  models/
    cuisine_option_test.dart
    food_item_extensions_test.dart
    food_item_test.dart
  core/
    config/api_config_test.dart
    navigation/main_shell_test.dart
    services/
      authenticated_http_client_test.dart
      preferences_service_test.dart
      user_service_test.dart
    state/favorites_store_test.dart
    theme/app_theme_test.dart
    utils/
      auth_validation_test.dart
      food_image_url_test.dart
    widgets/
      gradient_button_test.dart
      loading_placeholder_test.dart
  features/
    auth/
      auth_session_test.dart
      forgot_password_screen_test.dart
      sign_in_screen_test.dart
      sign_up_screen_test.dart
      token_storage_test.dart
      user_auth_service_test.dart
      user_model_test.dart
    chat/
      chat_message_test.dart
      chat_screen_test.dart
      chat_service_test.dart
    discover/
      discover_screen_test.dart
      food_service_test.dart
    favorites/
      favorites_screen_test.dart
      food_detail_screen_test.dart
    onboarding/
      budget_screen_test.dart
      cuisine_screen_test.dart
      dietary_options_test.dart
      done_screen_test.dart
      spice_screen_test.dart
      welcome_screen_test.dart
    profile/
      profile_screen_test.dart
  test_helpers/
    http_test_overrides.dart
    network_image_stub.dart

integration_test/
  app_smoke_test.dart
  favorites_location_link_test.dart
```

## What The Tests Cover

### Core

- API configuration defaults and derived URLs.
- Authenticated HTTP behavior, including token refresh after 401 responses.
- Preferences service parsing, persistence, fallback behavior, and swipe requests.
- User service profile/logout/delete interactions.
- FavoritesStore add/remove/set/clear behavior.
- Theme, validation utilities, image URL expansion, and shared widgets.

### Auth

- Backend auth sign-up, sign-in, forgot-password, reset-password, and refresh request handling.
- Auth session freshness and refresh behavior.
- TokenStorage persistence and JWT-derived metadata.
- Sign-in, sign-up, and forgot-password screen behavior.

### Discover

- FoodService request selection: personalized user-id fetch first, preference fallback second.
- Food JSON parsing, invalid-id filtering, fallback values, image URL mapping, cuisine tags, and address parsing.
- DiscoverScreen loading, card rendering, food-detail navigation, preference editing, refresh, and swipe sync behavior.

### Favorites And Food Details

- FavoritesScreen reloads liked foods from `/preference/food/users/{userId}`.
- Favorites parser supports direct and nested `food` payloads.
- Favorites parser preserves `address` when provided by the backend.
- FoodDetailScreen displays core food data and favorite-state actions.
- FoodDetailScreen renders the map location link from `address` when available.
- FoodDetailScreen falls back to `restaurantName` for the map location link when `address` is missing.

### Profile, Chat, And Onboarding

- Profile display, editing, local fallback, logout, and account deletion flows.
- Chat message parsing, chat service calls, and recommendation rendering.
- Onboarding cuisine, budget, spice, dietary, and completion screens.

## Integration Tests

### `integration_test/app_smoke_test.dart`

Launches the app from a clean state and verifies basic sign-in/forgot-password navigation.

Run:

```bash
flutter test integration_test/app_smoke_test.dart
```

### `integration_test/favorites_location_link_test.dart`

Verifies the food-location regression path:

1. Saves a mock logged-in session.
2. Stubs the favorites backend response.
3. Opens `FavoritesScreen`.
4. Opens `FoodDetailScreen`.
5. Verifies the blue map location row is visible.

It covers both:

- explicit backend `address`
- missing `address` with `restaurantName` fallback, for example `Dunman Food Centre`

Run:

```bash
flutter test integration_test/favorites_location_link_test.dart
```

## Common Commands

Analyze:

```bash
flutter analyze
```

Run all unit/widget tests:

```bash
flutter test
```

Run focused favorites/location tests:

```bash
flutter test test/features/favorites/food_detail_screen_test.dart test/features/favorites/favorites_screen_test.dart
flutter test integration_test/favorites_location_link_test.dart
```

Run one test file:

```bash
flutter test test/features/discover/food_service_test.dart
```

Run by test name:

```bash
flutter test --plain-name "uses restaurant name as map link when address is missing"
```

Run with coverage:

```bash
flutter test --coverage
```

## Test Helpers

`test/test_helpers/http_test_overrides.dart` provides deterministic HTTP stubbing for service and widget tests. It captures requests and returns configured JSON/image responses.

`test/test_helpers/network_image_stub.dart` provides a lightweight transparent PNG response for widget tests that need network images.

## Notes For Future Updates

- Update this document when adding new test files or when the passing `flutter test` count changes.
- Keep integration tests focused on user-visible flows that can regress across services/screens.
- Prefer `HttpTestOverrides` over live backend calls for deterministic local and CI test runs.
