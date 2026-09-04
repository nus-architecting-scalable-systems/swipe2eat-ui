# Swipe2Eat UI

A Flutter app for discovering, swiping, saving, and revisiting food recommendations. The app integrates with the shared backend for authentication, preferences, food discovery, favorites, and profile management.

## Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running The App](#running-the-app)
- [Project Structure](#project-structure)
- [API Integration](#api-integration)
- [Food Location Flow](#food-location-flow)
- [Testing](#testing)
- [Dependencies](#dependencies)
- [Troubleshooting](#troubleshooting)

## Features

### Core App

- Swipe-based food discovery with card gestures and like/dislike actions.
- Favorites screen that reloads liked foods from the backend.
- Food detail screen with image, rating, price, tags, description, and map location link.
- Profile screen for user details, preferences, logout, and account deletion.
- Onboarding flow for cuisine, budget, spice, dietary type, and allergens.
- Responsive Flutter UI for iOS, Android, web, and desktop-capable builds.

### Authentication

- Backend REST registration, sign-in, logout, profile, and account deletion flows through the user service.
- Bearer-token authentication for backend APIs.
- SharedPreferences-backed local session storage.
- Expired-session handling through `AuthenticatedHttpClient`.

### Backend And Local State

- Food discovery fetches personalized results by stored user id first, then falls back to preference filters.
- Preferences sync to the backend and are also saved locally.
- Swipe preferences are queued through the backend swipe endpoint.
- Favorites are synced from the backend and cached in `FavoritesStore`.
- Backend image keys are expanded to public S3 image URLs.

## Prerequisites

- Flutter SDK with Dart SDK support for `sdk: ^3.10.7`.
- Git.
- Xcode and CocoaPods for iOS development on macOS.
- Android Studio or Android SDK for Android development.

Useful checks:

```bash
flutter --version
dart --version
flutter doctor
```

## Installation

```bash
git clone https://github.com/NUS-MTechSE-DMSS/swipe2eat-ui.git
cd swipe2eat-ui
flutter pub get
```

For iOS:

```bash
cd ios
pod install
cd ..
```

## Configuration

The backend base URL is read from `ApiConfig.baseUrl`, which uses the `API_BASE_URL` Dart define.

Environment files live in `config/env/`:

```text
config/env/dev.json
config/env/staging.json
config/env/prod.json
```

The checked-in development environment uses:

```text
http://nus-archss-alb-dev-126330082.ap-southeast-1.elb.amazonaws.com
```

Plain `flutter run` also defaults to this development backend. Staging and
production builds should continue to pass their environment file explicitly.

Example run using an environment file:

```bash
flutter run --dart-define-from-file=config/env/dev.json
```

Android builds also define product flavors in `android/app/build.gradle.kts`:

```bash
flutter run --flavor dev --dart-define-from-file=config/env/dev.json
```

## Running The App

List devices:

```bash
flutter devices
```

iOS simulator:

```bash
flutter run -d <simulator_id> --dart-define-from-file=config/env/dev.json
```

Android emulator:

```bash
flutter run -d <emulator_id> --flavor dev --dart-define-from-file=config/env/dev.json
```

Web:

```bash
flutter run -d chrome --dart-define-from-file=config/env/dev.json
```

## Project Structure

```text
lib/
  app.dart
  main.dart
  core/
    config/api_config.dart
    navigation/
    services/
    state/favorites_store.dart
    theme/
    utils/
    widgets/
  features/
    auth/
    discover/
    favorites/
    onboarding/
    profile/
  models/

test/
  core/
  features/
  models/
  test_helpers/

integration_test/
  app_smoke_test.dart
  favorites_location_link_test.dart
```

## API Integration

The app uses authenticated backend calls through `AuthenticatedHttpClient` where a session is required.

### Authentication

Implemented user-service auth endpoints:

```text
POST /user/register
POST /user/login
POST /user/logout
GET /user/{userId}
PUT /user/me
DELETE /user/{userId}
```

Successful sign-in responses must include an access token and user id. The
current user service does not expose token-refresh or password-reset endpoints.

### Food Discovery

Primary personalized request:

```text
GET /food/?userId={userId}
```

Fallback request when personalized results are empty:

```text
GET /food/?budget=medium&cuisines=Thai&cuisines=Japanese&spiceLevel=3
```

The parser accepts list responses directly, or wrapped in `data` or `foods`.

### Favorites

```text
GET /preference/food/users/{userId}
```

Favorites can be returned as food objects directly or nested under a `food` key. The favorites parser preserves `address` when the backend provides it.

### Swipe Preferences

```text
POST /preference/food/swipe
```

This records like/dislike actions for the authenticated user.

### User Preferences

```text
GET /preference/users/{userId}
PUT /preference/users/{userId}
GET /preference/dietary/options
GET /preference/dietary/users/{userId}
```

Preferences are saved locally as a fallback when sync fails.

### Profile And User

```text
GET /user/{userId}
PUT /user/me
POST /user/logout
DELETE /user/{userId}
```

## Food Location Flow

Food details show two related location values:

1. Static place label: the grey text under the dish title always shows `item.restaurant`, mapped from backend `restaurantName`.
2. Map link: the blue underlined row uses `item.address` when present. If `address` is missing, it falls back to `item.restaurant`.

Sequence:

```text
Backend food JSON
  -> FoodService or FavoritesScreen parser
  -> FoodItem(restaurant, address)
  -> FoodDetailScreen
  -> choose address if present, otherwise restaurant
  -> render blue map link
  -> tap opens Google Maps search via url_launcher
```

Google Maps URL format:

```text
https://www.google.com/maps/search/?api=1&query=<encoded location>
```

This means a food item like `Thai Fried Rice` at `Dunman Food Centre` still gets a map link even if the backend did not send a full address.

## Testing

Current local verification:

```bash
flutter analyze
flutter test
flutter test integration_test/favorites_location_link_test.dart
```

As of this update:

- `flutter test` passes 298 unit/widget tests.
- `integration_test/favorites_location_link_test.dart` has 2 passing integration tests for the food location link flow.
- `integration_test/app_smoke_test.dart` covers basic app launch/auth navigation.

See [test/TESTSUITE_README.md](test/TESTSUITE_README.md) for the test layout and focused test commands.

## Dependencies

Runtime dependencies:

- `flutter`
- `http: ^1.2.2`
- `shared_preferences: ^2.2.3`
- `url_launcher: ^6.3.0`
- `cupertino_icons: ^1.0.8`

Development dependencies:

- `flutter_test`
- `integration_test`
- `flutter_lints: ^6.0.0`
- `mockito: ^5.4.4`
- `build_runner: ^2.4.9`

For exact versions, see [pubspec.yaml](pubspec.yaml).

## Troubleshooting

### Flutter Command Not Found

Ensure Flutter is installed and on your PATH:

```bash
flutter --version
```

### iOS Pods Or Build Issues

```bash
cd ios
pod install
cd ..
flutter clean
flutter pub get
```

### Device Not Detected

```bash
flutter doctor
flutter devices
```

For Android, also check USB debugging and Android licenses:

```bash
flutter doctor --android-licenses
```

### Backend Or Login Issues

- Confirm `API_BASE_URL` points to the intended backend.
- Confirm `/user/login` succeeds before testing authenticated screens.
- Clear simulator app data when testing a fresh auth state.
- Re-run with the expected environment file:

```bash
flutter run --dart-define-from-file=config/env/dev.json
```

### Food Location Link Missing

Expected behavior:

- If `address` is present, the blue map row shows the address.
- If `address` is missing but `restaurantName` is present, the blue map row shows the restaurant/place name.
- If both are missing or restaurant is `Unknown`, no map link is shown.

Run the regression test:

```bash
flutter test integration_test/favorites_location_link_test.dart
```

## Test
