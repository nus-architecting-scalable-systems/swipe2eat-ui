import 'dart:convert';
import 'dart:developer' as developer;
import '../../../core/services/authenticated_http_client.dart';
import '../../../core/utils/food_image_url.dart';
import '../../../models/food_item.dart';
import '../../../core/config/api_config.dart';
import '../../auth/services/token_storage.dart';

/// Service for food-related API operations.
/// Handles fetching foods from the backend.
class FoodService {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static int _invalidFoodIdDropCount = 0;
  static int _lastInvalidFoodIdDropCount = 0;

  /// Total number of food records dropped due to missing/invalid UUID IDs
  /// since app start.
  static int get invalidFoodIdDropCount => _invalidFoodIdDropCount;
  static int get lastInvalidFoodIdDropCount => _lastInvalidFoodIdDropCount;

  /// Builds HTTP headers with the stored backend authentication token.
  static Future<Map<String, String>> _buildAuthHeaders() async {
    final headers = <String, String>{};
    final authHeader = await TokenStorage.getAuthorizationHeader();
    if (authHeader != null) {
      headers['Authorization'] = authHeader;
    }
    return headers;
  }

  /// Converts spice level string to numeric value for API.
  /// 1 = mild, 2 = medium, 3 = hot
  static int _spiceLevelToNumber(String spiceLevel) {
    switch (spiceLevel.toLowerCase().trim()) {
      case 'mild':
        return 1;
      case 'medium':
        return 2;
      case 'hot':
        return 3;
      default:
        return 2; // default to medium
    }
  }

  /// Fetches foods from the backend based on user preferences.
  ///
  /// Parameters:
  /// - [cuisines]: List of preferred cuisines
  /// - [budget]: Budget level ('low', 'medium', 'high')
  /// - [spiceLevel]: Spice preference ('mild', 'medium', 'hot')
  /// - [dietType]: Dietary type (optional, use 'None' to exclude)
  /// - [allergens]: List of allergens to avoid
  ///
  /// Returns a list of [FoodItem] objects or throws an exception on failure.
  static Future<List<FoodItem>> fetchFoods({
    required List<String> cuisines,
    required String budget,
    required String spiceLevel,
    String? dietType,
    List<String>? allergens,
  }) async {
    final userId = await TokenStorage.getUserId();
    final headers = await _buildAuthHeaders();

    if (userId != null && userId.trim().isNotEmpty) {
      final personalizedFoods = await _fetchFoodsByQuery(
        queryParameters: {
          'userId': [userId.trim()],
        },
        headers: headers,
      );
      if (personalizedFoods.isNotEmpty) {
        return personalizedFoods;
      }
    }

    final fallbackParams = <String, List<String>>{
      'budget': [budget],
    };

    if (cuisines.isNotEmpty) {
      fallbackParams['cuisines'] = cuisines;
    }

    if (spiceLevel.trim().isNotEmpty) {
      fallbackParams['spiceLevel'] = [
        _spiceLevelToNumber(spiceLevel).toString(),
      ];
    }

    return _fetchFoodsByQuery(
      queryParameters: fallbackParams,
      headers: headers,
    );
  }

  static Future<List<FoodItem>> _fetchFoodsByQuery({
    required Map<String, List<String>> queryParameters,
    required Map<String, String> headers,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/food/',
    ).replace(query: _buildQueryString(queryParameters));

    final tokenType = headers.containsKey('Authorization')
        ? AuthTokenType.idToken
        : AuthTokenType.none;
    final res = await AuthenticatedHttpClient.get(
      uri,
      headers: headers,
      tokenType: tokenType,
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load foods (${res.statusCode})');
    }

    final data = jsonDecode(res.body);
    final list = _extractList(data);
    final foods = <FoodItem>[];
    final droppedIdSamples = <String>[];
    var droppedInThisFetch = 0;
    _lastInvalidFoodIdDropCount = 0;

    for (final raw in list) {
      final rawId = _extractRawId(raw);
      if (rawId == null || !_isValidUuid(rawId)) {
        droppedInThisFetch++;
        if (droppedIdSamples.length < 5) {
          droppedIdSamples.add(rawId ?? '<missing>');
        }
        continue;
      }

      final item = _foodFromJson(raw);
      if (item != null) {
        foods.add(item);
      }
    }

    if (droppedInThisFetch > 0) {
      _lastInvalidFoodIdDropCount = droppedInThisFetch;
      _invalidFoodIdDropCount += droppedInThisFetch;
      developer.log(
        'Dropped $droppedInThisFetch food records with invalid UUID ids. '
        'Sample ids: ${droppedIdSamples.join(", ")}. '
        'Total dropped since app start: $_invalidFoodIdDropCount.',
        name: 'FoodService',
        level: 900,
      );
    }

    return foods;
  }

  static String _buildQueryString(Map<String, List<String>> queryParameters) {
    final params = <String>[];
    for (final entry in queryParameters.entries) {
      for (final value in entry.value) {
        if (value.trim().isEmpty) continue;
        params.add('${entry.key}=${Uri.encodeQueryComponent(value)}');
      }
    }
    return params.join('&');
  }

  /// Extracts the list of food items from various response formats.
  static List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['data'] is List) return data['data'] as List;
    if (data is Map && data['foods'] is List) return data['foods'] as List;
    return const <dynamic>[];
  }

  /// Parses a JSON object into a [FoodItem].
  static FoodItem? _foodFromJson(dynamic raw) {
    if (raw is! Map) return null;

    String? readString(String key) {
      final v = raw[key];
      return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    }

    double readDouble(String key, {double fallback = 0}) {
      final v = raw[key];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    final id = readString('id');
    if (id == null || !_isValidUuid(id)) {
      return null;
    }
    final name = readString('name') ?? "Unknown Dish";
    final restaurant = readString('restaurantName') ?? "Unknown";
    final rating = readDouble('rating', fallback: 4.5);
    final price = readDouble('price', fallback: 14.99);
    final description =
        readString('description') ??
        "A delicious pick based on your preferences.";

    final imageKey = readString('imageKey');
    final imageUrl =
        foodImageUrlFromKey(imageKey) ??
        "https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=1200";

    const int spiceLevel = 2;

    int budgetLevel;
    if (price <= 10) {
      budgetLevel = 1;
    } else if (price <= 20) {
      budgetLevel = 2;
    } else {
      budgetLevel = 3;
    }

    List<String> tags = const [];
    final cuisineRaw = raw['cuisine'];
    if (cuisineRaw is List) {
      tags = cuisineRaw.map((e) => e.toString()).toList();
    }

    final address = readString('address');

    return FoodItem(
      id: id,
      name: name,
      restaurant: restaurant,
      imageUrl: imageUrl,
      rating: rating,
      price: price,
      description: description,
      spiceLevel: spiceLevel,
      budgetLevel: budgetLevel,
      tags: tags,
      address: address,
    );
  }

  static bool _isValidUuid(String value) {
    return _uuidPattern.hasMatch(value);
  }

  static String? _extractRawId(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is String && id.trim().isNotEmpty) {
      return id.trim();
    }
    return null;
  }
}
