import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/services/authenticated_http_client.dart';
import '../../core/state/favorites_store.dart';
import '../../core/utils/food_image_url.dart';
import '../../core/widgets/loading_placeholder.dart';
import '../../models/food_item.dart';
import 'food_detail_screen.dart';
import '../auth/services/token_storage.dart';

class FavoritesScreen extends StatefulWidget {
  // const FavoritesScreen({super.key});
  final bool showBottomNav;
  const FavoritesScreen({super.key, this.showBottomNav = true});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _query = "";
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFavorites();
  }

  /// Builds HTTP headers with the stored backend authentication token.
  Future<Map<String, String>> _buildAuthHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final authHeader = await TokenStorage.getAuthorizationHeader();
    if (authHeader != null) {
      headers['Authorization'] = authHeader;
    }
    return headers;
  }

  Future<void> _fetchFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.trim().isEmpty) {
        throw Exception('Missing user id');
      }
      final uri = Uri.parse(
        '${ApiConfig.preferenceBaseUrl}/foods/users/$userId',
      );
      final res = await AuthenticatedHttpClient.get(
        uri,
        headers: await _buildAuthHeaders(),
        tokenType: AuthTokenType.idToken,
      );
      if (res.statusCode != 200) {
        throw Exception('Failed to load favorites (${res.statusCode})');
      }
      final data = jsonDecode(res.body);
      final list = _extractList(data);
      final items = list
          .map((e) => _foodFromPreferenceJson(e))
          .whereType<FoodItem>()
          .toList();
      FavoritesStore.instance.setAll(items);
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8F1),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8A3D), Color(0xFFFF4D4D)],
                    ),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<List<FoodItem>>(
                    valueListenable: FavoritesStore.instance.favorites,
                    builder: (context, favs, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Favorites",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${favs.length} dishes saved",
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (!widget.showBottomNav)
                  const SizedBox.shrink()
                else
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Icon(Icons.close_rounded),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Search
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 14,
                    offset: Offset(0, 8),
                    color: Color(0x14000000),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: "Search your favorites...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Grid
            Expanded(
              child: ValueListenableBuilder<List<FoodItem>>(
                valueListenable: FavoritesStore.instance.favorites,
                builder: (context, favs, child) {
                  if (_loading) {
                    return const _FavoritesGridSkeleton();
                  }
                  if (_error != null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Couldn't load favorites",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _fetchFavorites,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: const Text(
                                "Retry",
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final filtered = favs.where((f) {
                    if (_query.isEmpty) return true;
                    return f.name.toLowerCase().contains(_query) ||
                        f.restaurant.toLowerCase().contains(_query) ||
                        f.tags.any((t) => t.toLowerCase().contains(_query));
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        "No favorites yet.\nGo like some food 😄",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    itemCount: filtered.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.78,
                        ),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      return _FavoriteTile(
                        item: item,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FoodDetailScreen(item: item),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['data'] is List) return data['data'] as List;
  if (data is Map && data['foods'] is List) return data['foods'] as List;
  return const <dynamic>[];
}

FoodItem? _foodFromPreferenceJson(dynamic raw) {
  if (raw is Map && raw['food'] is Map) {
    return _foodFromJson(raw['food']);
  }
  return _foodFromJson(raw);
}

FoodItem? _foodFromJson(dynamic raw) {
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

  final id = readString('id') ?? DateTime.now().toString();
  final name = readString('name') ?? 'Unknown Dish';
  final restaurant = readString('restaurantName') ?? 'Unknown';
  final rating = readDouble('rating', fallback: 4.5);
  final price = readDouble('price', fallback: 14.99);
  final description =
      readString('description') ??
      'A delicious pick based on your preferences.';

  final imageKey = readString('imageKey');
  final imageUrl =
      foodImageUrlFromKey(imageKey) ??
      'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=1200';

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
  } else if (cuisineRaw is String && cuisineRaw.trim().isNotEmpty) {
    tags = [cuisineRaw.trim()];
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

class _FavoritesGridSkeleton extends StatelessWidget {
  const _FavoritesGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => const _FavoriteTileSkeleton(),
    );
  }
}

class _FavoriteTileSkeleton extends StatelessWidget {
  const _FavoriteTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: SkeletonBox(borderRadius: BorderRadius.zero),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const SkeletonBox(
                        width: 34,
                        height: 12,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const SkeletonBox(
                        width: 42,
                        height: 12,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(
                    width: 108,
                    height: 16,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(
                    width: 86,
                    height: 12,
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;

  const _FavoriteTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              blurRadius: 18,
              offset: Offset(0, 10),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AppNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _PillBadge(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _PillBadge(
                        child: Text(
                          "\$${item.price.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Text
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.restaurant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final Widget child;
  const _PillBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}
