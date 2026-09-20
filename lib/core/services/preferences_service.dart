import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/onboarding/models/dietary_options.dart';
import '../../features/auth/services/token_storage.dart';
import '../config/api_config.dart';
import 'authenticated_http_client.dart';

class PreferencesService {
  static const String _prefsCuisinesKey = 'prefs.cuisines';
  static const String _prefsBudgetKey = 'prefs.budget';
  static const String _prefsSpiceKey = 'prefs.spice';
  static const String _prefsDietTypeKey = 'prefs.dietType';
  static const String _prefsAllergensKey = 'prefs.allergens';

  /// ValueNotifier that emits when preferences are updated
  /// Subscribers (like DiscoverScreen) can listen to this to refresh their data
  static final preferencesUpdated = ValueNotifier<int>(0);
  static Future<void> _pendingSwipeQueue = Future.value();

  /// Builds HTTP headers with the stored backend authentication token.
  static Future<Map<String, String>> _buildAuthHeaders() async {
    final headers = {'Content-Type': 'application/json'};

    final authHeader = await TokenStorage.getAuthorizationHeader();
    if (authHeader != null) {
      headers['Authorization'] = authHeader;
    }

    return headers;
  }

  static String _normalizeSpiceLabel(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case '1':
      case 'mild':
      case 'low':
        return 'Mild';
      case '2':
      case 'medium':
      case 'med':
        return 'Medium';
      case '3':
      case 'hot':
      case 'high':
      case 'spicy':
        return 'Hot';
      default:
        return 'Medium';
    }
  }

  static bool _hasNonEmptyText(dynamic value) {
    return value is String && value.trim().isNotEmpty;
  }

  static bool _hasNonEmptyCuisines(dynamic cuisinesData) {
    if (cuisinesData is List) {
      return cuisinesData.any((item) => _hasNonEmptyText(item));
    }
    if (cuisinesData is String) {
      return cuisinesData.trim().isNotEmpty;
    }
    return false;
  }

  static int _spiceLevelToBackendNumber(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case '1':
      case 'mild':
      case 'low':
        return 1;
      case '3':
      case 'hot':
      case 'high':
      case 'spicy':
        return 3;
      case '2':
      case 'medium':
      case 'med':
      default:
        return 2;
    }
  }

  static String? _extractSpiceLabel(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final level = raw.toInt();
      if (level < 1 || level > 3) {
        return null;
      }
      return _normalizeSpiceLabel(level.toString());
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final normalized = raw.trim().toLowerCase();
      const valid = {
        '1',
        '2',
        '3',
        'mild',
        'medium',
        'med',
        'hot',
        'high',
        'low',
        'spicy',
      };
      if (!valid.contains(normalized)) {
        return null;
      }
      return _normalizeSpiceLabel(raw);
    }
    return null;
  }

  static bool _hasCompletePreferencePayload(Map<String, dynamic> json) {
    final cuisines = json['cuisines'];
    final budget = json['budget'];
    final spice = json['spiceLevel'] ?? json['spice'];

    return _hasNonEmptyCuisines(cuisines) &&
        _hasNonEmptyText(budget) &&
        _extractSpiceLabel(spice) != null;
  }

  /// Fetches dietary options from the preference service.
  static Future<DietaryOptions> fetchDietaryOptions() async {
    final uri = Uri.parse(ApiConfig.dietaryOptionsUrl);
    final res = await AuthenticatedHttpClient.get(
      uri,
      headers: await _buildAuthHeaders(),
      tokenType: AuthTokenType.idToken,
    ).timeout(const Duration(seconds: 2));

    if (res.statusCode != 200) {
      throw Exception('Failed to load options (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return DietaryOptions.fromJson(data);
  }

  /// Checks if the user has saved preferences on the backend
  /// This is used to determine if user needs to go through onboarding
  /// Returns true if user has preferences, false otherwise
  /// Handles all error cases (404, 400, network errors) by returning false
  static Future<bool> hasUserPreferences() async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.trim().isEmpty) {
        return false;
      }

      final uri = Uri.parse('${ApiConfig.preferenceBaseUrl}/users/$userId');
      final res = await AuthenticatedHttpClient.get(
        uri,
        headers: await _buildAuthHeaders(),
        tokenType: AuthTokenType.idToken,
      ).timeout(const Duration(seconds: 5));

      // 200 with valid preferences
      if (res.statusCode == 200) {
        try {
          final json = jsonDecode(res.body) as Map<String, dynamic>;

          // Returning users must have non-empty cuisines, budget, and spice level.
          if (_hasCompletePreferencePayload(json)) {
            return true;
          }
        } catch (_) {
          // Invalid JSON response
          return false;
        }
      }

      // 404, 400+, or other errors -> user needs onboarding
      return false;
    } catch (_) {
      // Network errors or timeouts -> default to onboarding (safe default)
      return false;
    }
  }

  /// Updates preferences on the backend (cuisines, budget, optional spice level)
  /// Returns true if successful, false otherwise
  static Future<bool> updatePreferences({
    required List<String> cuisines,
    required String budget,
    String? spiceLevel,
  }) async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.trim().isEmpty) {
        return false;
      }

      final uri = Uri.parse('${ApiConfig.preferenceBaseUrl}/users/$userId');
      final headers = await _buildAuthHeaders();
      final payloadMap = <String, dynamic>{
        'cuisines': cuisines,
        'budget': budget,
      };
      if (spiceLevel != null && spiceLevel.trim().isNotEmpty) {
        payloadMap['spiceLevel'] = _spiceLevelToBackendNumber(spiceLevel);
      }
      final payload = jsonEncode(payloadMap);

      final res = await AuthenticatedHttpClient.put(
        uri,
        headers: headers,
        body: payload,
        tokenType: AuthTokenType.idToken,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Updates dietary preferences on the backend.
  /// Returns true if successful, false otherwise.
  static Future<bool> updateDietaryPreferences({
    required String dietType,
    required List<String> allergens,
  }) async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.trim().isEmpty) {
        return false;
      }

      final uri = Uri.parse(
        '${ApiConfig.preferenceBaseUrl}/dietary/users/$userId',
      );
      final headers = await _buildAuthHeaders();
      final payload = jsonEncode({
        'dietType': dietType,
        // Backend DTO uses `allergies`; keep frontend storage naming separate.
        'allergies': allergens,
      });

      final res = await AuthenticatedHttpClient.put(
        uri,
        headers: headers,
        body: payload,
        tokenType: AuthTokenType.idToken,
      );
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Gets current preferences from local storage
  static Future<Map<String, dynamic>> getLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final cuisines =
        prefs.getStringList(_prefsCuisinesKey) ??
        ['Chinese', 'Thai', 'Western'];
    final budget = prefs.getString(_prefsBudgetKey) ?? 'low';
    final spiceLevel = prefs.getString(_prefsSpiceKey) ?? 'Medium';
    final dietType = prefs.getString(_prefsDietTypeKey) ?? 'None';
    final allergens = prefs.getStringList(_prefsAllergensKey) ?? <String>[];

    return {
      'cuisines': cuisines,
      'budget': budget,
      'spiceLevel': spiceLevel,
      'dietType': dietType,
      'allergens': allergens,
    };
  }

  /// Saves preferences to local storage and notifies listeners
  static Future<void> saveLocalPreferences({
    required List<String> cuisines,
    required String budget,
    String? spiceLevel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsCuisinesKey, cuisines);
    await prefs.setString(_prefsBudgetKey, budget);
    if (spiceLevel != null && spiceLevel.trim().isNotEmpty) {
      await prefs.setString(_prefsSpiceKey, _normalizeSpiceLabel(spiceLevel));
    }

    // Notify listeners that preferences have been updated
    preferencesUpdated.value++;
  }

  /// Saves dietary preferences to local storage and notifies listeners.
  static Future<void> saveLocalDietaryPreferences({
    required String dietType,
    required List<String> allergens,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sortedAllergens = List<String>.from(allergens)..sort();
    await prefs.setString(_prefsDietTypeKey, dietType);
    await prefs.setStringList(_prefsAllergensKey, sortedAllergens);

    preferencesUpdated.value++;
  }

  /// Fetches preferences from backend and saves them locally
  /// Returns the fetched preferences map if successful
  static Future<Map<String, dynamic>?> fetchPreferencesFromBackend() async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.trim().isEmpty) {
        return null;
      }

      final uri = Uri.parse('${ApiConfig.preferenceBaseUrl}/users/$userId');
      final res = await AuthenticatedHttpClient.get(
        uri,
        headers: await _buildAuthHeaders(),
        tokenType: AuthTokenType.idToken,
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;

        // Extract cuisines (handle both string and array formats)
        List<String> cuisines = [];
        final cuisinesData = json['cuisines'];
        if (cuisinesData is List) {
          cuisines = List<String>.from(cuisinesData);
        } else if (cuisinesData is String) {
          cuisines = [cuisinesData];
        }

        // Extract budget
        final budget = json['budget']?.toString() ?? 'low';
        final spiceLevel = _extractSpiceLabel(
          json['spiceLevel'] ?? json['spice'],
        );

        // Save to local storage
        await saveLocalPreferences(
          cuisines: cuisines,
          budget: budget,
          spiceLevel: spiceLevel,
        );

        return {
          'cuisines': cuisines,
          'budget': budget,
          'spiceLevel': spiceLevel,
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sends user's swipe preference (like/dislike) for a food item to the backend.
  ///
  /// Parameters:
  /// - [foodId]: ID of the food item
  /// - [liked]: true if liked, false if disliked
  ///
  /// Returns true if successful, false otherwise.
  static Future<bool> sendSwipePreference({
    required String foodId,
    required bool liked,
  }) async {
    final userId = await TokenStorage.getUserId();
    if (userId == null || userId.trim().isEmpty) {
      return false;
    }

    final uri = Uri.parse('${ApiConfig.preferenceBaseUrl}/foods/swipe');
    final headers = await _buildAuthHeaders();
    final payload = jsonEncode({
      'userId': userId,
      'foodId': foodId,
      'status': liked,
    });

    try {
      final res = await AuthenticatedHttpClient.post(
        uri,
        headers: headers,
        body: payload,
        tokenType: AuthTokenType.idToken,
      );
      // Backend contract is 204 No Content; keep 200/201 for compatibility.
      return res.statusCode == 204 ||
          res.statusCode == 200 ||
          res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Queues swipe sync requests so the UI can advance immediately while
  /// preserving backend submission order.
  static Future<bool> queueSwipePreference({
    required String foodId,
    required bool liked,
  }) {
    final completer = Completer<bool>();

    _pendingSwipeQueue = _pendingSwipeQueue.catchError((_) {}).then((_) async {
      try {
        final synced = await sendSwipePreference(foodId: foodId, liked: liked);
        completer.complete(synced);
      } catch (_) {
        completer.complete(false);
      }
    });

    return completer.future;
  }
}
