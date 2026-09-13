import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/food_item.dart';
import '../../core/state/favorites_store.dart';
import '../../core/services/preferences_service.dart';
import '../../core/widgets/loading_placeholder.dart';
import '../favorites/food_detail_screen.dart';
import '../auth/services/token_storage.dart';
import 'services/food_service.dart';

class DiscoverScreen extends StatefulWidget {
  final bool showBottomNav;
  const DiscoverScreen({super.key, this.showBottomNav = true});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final List<FoodItem> _items = [];
  bool _loading = true;
  String? _error;
  int _lastDroppedInvalidIds = 0;

  int _topIndex = 0;

  // Defaults used when no local preferences are saved yet
  List<String> _selectedCuisines = ['Chinese', 'Thai', 'Western'];
  String _selectedBudget = 'low'; // 'low', 'medium', 'high'
  String _selectedSpice = 'Medium';
  String _selectedDietType = 'None';
  List<String> _selectedAllergens = const [];
  String _locationLabel = 'Your city';

  static const String _prefsCuisinesKey = 'prefs.cuisines';
  static const String _prefsBudgetKey = 'prefs.budget';
  static const String _prefsSpiceKey = 'prefs.spice';
  static const String _prefsDietTypeKey = 'prefs.dietType';
  static const String _prefsAllergensKey = 'prefs.allergens';

  // drag state
  Offset _dragOffset = Offset.zero;
  double _dragRotation = 0; // radians

  FoodItem? get _current =>
      _topIndex < _items.length ? _items[_topIndex] : null;

  @override
  void initState() {
    super.initState();
    _initLoad();

    // Listen for preferences updates and refresh food list
    PreferencesService.preferencesUpdated.addListener(_onPreferencesUpdated);
  }

  @override
  void dispose() {
    // Clean up the listener when the widget is disposed
    PreferencesService.preferencesUpdated.removeListener(_onPreferencesUpdated);
    super.dispose();
  }

  void _onPreferencesUpdated() {
    // Reload preferences and refresh food list
    _initLoad();
  }

  Future<void> _initLoad() async {
    await _loadBootstrapState();
    if (!mounted) return;
    await _fetchFoods();
  }

  Future<void> _loadBootstrapState() async {
    try {
      final results = await Future.wait<Object?>([
        SharedPreferences.getInstance(),
        TokenStorage.getIdToken(),
      ]);
      final prefs = results[0] as SharedPreferences;
      final idToken = results[1] as String?;
      if (!mounted) return;

      String? city;
      if (idToken != null && idToken.isNotEmpty) {
        final parts = idToken.split('.');
        if (parts.length == 3) {
          final normalized = base64Url.normalize(parts[1]);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final payload = jsonDecode(decoded);
          if (payload is Map) {
            city = (payload['custom:City'] ?? payload['city'])
                ?.toString()
                .trim();
          }
        }
      }

      final cuisines = prefs.getStringList(_prefsCuisinesKey);
      final budget = prefs.getString(_prefsBudgetKey);
      final spice = prefs.getString(_prefsSpiceKey);
      final dietType = prefs.getString(_prefsDietTypeKey);
      final allergens = prefs.getStringList(_prefsAllergensKey);

      setState(() {
        if (city != null && city.isNotEmpty) {
          _locationLabel = city;
        }
        if (cuisines != null && cuisines.isNotEmpty) {
          _selectedCuisines = cuisines;
        }
        if (budget != null && budget.trim().isNotEmpty) {
          _selectedBudget = budget.trim();
        }
        if (spice != null && spice.trim().isNotEmpty) {
          _selectedSpice = spice.trim();
        }
        if (dietType != null && dietType.trim().isNotEmpty) {
          _selectedDietType = dietType.trim();
        }
        if (allergens != null && allergens.isNotEmpty) {
          _selectedAllergens = allergens;
        }
      });
    } catch (_) {
      // Keep fallback values when cached state is unavailable.
    }
  }

  Future<void> _fetchFoods() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final foods = await FoodService.fetchFoods(
        cuisines: _selectedCuisines,
        budget: _selectedBudget,
        spiceLevel: _selectedSpice,
        dietType: _selectedDietType,
        allergens: _selectedAllergens,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(foods);
        _topIndex = 0;
        _lastDroppedInvalidIds = FoodService.lastInvalidFoodIdDropCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openQuickPreferencesEditor() async {
    final selection = await showModalBottomSheet<_DiscoverPreferenceSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickPreferencesSheet(
        initialCuisines: _selectedCuisines,
        initialBudget: _selectedBudget,
        initialSpice: _selectedSpice,
      ),
    );

    if (selection == null || !mounted) return;

    final cuisines = List<String>.from(selection.cuisines)..sort();
    setState(() {
      _selectedCuisines = cuisines;
      _selectedBudget = selection.budget;
      _selectedSpice = selection.spice;
    });

    final synced = await PreferencesService.updatePreferences(
      cuisines: cuisines,
      budget: selection.budget,
      spiceLevel: selection.spice,
    );

    await PreferencesService.saveLocalPreferences(
      cuisines: cuisines,
      budget: selection.budget,
      spiceLevel: selection.spice,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Preferences updated.'
              : 'Preferences saved locally (sync failed).',
        ),
      ),
    );
  }

  void _resetDrag() {
    setState(() {
      _dragOffset = Offset.zero;
      _dragRotation = 0;
    });
  }

  void _swipeLeft() {
    _completeSwipe(isRight: false);
  }

  void _swipeRight() {
    _completeSwipe(isRight: true);
  }

  void _completeSwipe({required bool isRight}) {
    final item = _current;
    if (item == null) return;

    if (isRight) {
      FavoritesStore.instance.add(item);
    }

    setState(() {
      _topIndex++;
      _dragOffset = Offset.zero;
      _dragRotation = 0;
    });

    PreferencesService.queueSwipePreference(
      foodId: item.id,
      liked: isRight,
    ).then((synced) {
      if (!mounted || synced) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sync swipe. Please try again later.'),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;

    return Container(
      color: const Color(0xFFFFF8F1),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _TopBar(
            locationLabel: _locationLabel,
            onEditPreferencesTap: _openQuickPreferencesEditor,
            onRefreshTap: _fetchFoods,
          ),
          const SizedBox(height: 14),

          Expanded(
            child: Center(
              child: _loading
                  ? const _DiscoverLoadingState()
                  : _error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Couldn't load foods",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _fetchFoods,
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
                    )
                  : item == null
                  ? _items.isEmpty
                        ? _EmptyState(
                            title: "No dishes available",
                            subtitle: _lastDroppedInvalidIds > 0
                                ? "Skipped $_lastDroppedInvalidIds dishes because of invalid data. Please try again shortly."
                                : "No dishes match your current preferences right now.",
                            onAction: _fetchFoods,
                          )
                        : _EmptyState(
                            title: "No more dishes 🎉",
                            subtitle:
                                "You've swiped through all available dishes. Refresh to load another batch.",
                            actionLabel: "Refresh dishes",
                            actionIcon: Icons.refresh_rounded,
                            onAction: _fetchFoods,
                          )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = min(
                          constraints.maxWidth * 0.86,
                          360.0,
                        );
                        final cardHeight = min(
                          constraints.maxHeight * 0.82,
                          560.0,
                        );

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_topIndex + 1 < _items.length)
                              Transform.scale(
                                scale: 0.96,
                                child: Opacity(
                                  opacity: 0.45,
                                  child: _FoodCard(
                                    item: _items[_topIndex + 1],
                                    width: cardWidth,
                                    height: cardHeight,
                                    showOverlay: false,
                                  ),
                                ),
                              ),

                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FoodDetailScreen(item: item),
                                  ),
                                );
                              },
                              onPanUpdate: (d) {
                                setState(() {
                                  _dragOffset += d.delta;
                                  _dragRotation = (_dragOffset.dx / 800) * 0.6;
                                });
                              },
                              onPanEnd: (_) {
                                final dx = _dragOffset.dx;
                                if (dx > 120) {
                                  _swipeRight();
                                } else if (dx < -120) {
                                  _swipeLeft();
                                } else {
                                  _resetDrag();
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOut,
                                transform: Matrix4.identity()
                                  ..translateByDouble(
                                    _dragOffset.dx,
                                    _dragOffset.dy,
                                    0,
                                    1,
                                  )
                                  ..rotateZ(_dragRotation),
                                child: _FoodCard(
                                  item: item,
                                  width: cardWidth,
                                  height: cardHeight,
                                  showOverlay: true,
                                  overlayDx: _dragOffset.dx,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),

          const SizedBox(height: 6),
          _ActionRow(
            onNope: _swipeLeft,
            onLike: _swipeRight,
            enabled: !_loading && item != null,
          ),
          const SizedBox(height: 10),

          if (widget.showBottomNav)
            _BottomNavMock(
              active: _NavItem.discover,
              onTap: (item) {
                // optional: keep old behavior if used standalone
              },
            ),
        ],
      ),
    );
  }
}

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = min(constraints.maxWidth * 0.86, 360.0);
        final cardHeight = min(constraints.maxHeight * 0.82, 560.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 0.96,
              child: Opacity(
                opacity: 0.42,
                child: _FoodCardSkeleton(width: cardWidth, height: cardHeight),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -6),
              child: _FoodCardSkeleton(width: cardWidth, height: cardHeight),
            ),
          ],
        );
      },
    );
  }
}

class _FoodCardSkeleton extends StatelessWidget {
  final double width;
  final double height;

  const _FoodCardSkeleton({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              blurRadius: 28,
              offset: Offset(0, 16),
              color: Color(0x22000000),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: SkeletonBox(borderRadius: BorderRadius.zero),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const SkeletonBox(
                          width: 44,
                          height: 12,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(
                            width: 180,
                            height: 22,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          SizedBox(height: 8),
                          SkeletonBox(
                            width: 120,
                            height: 14,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          SkeletonBox(
                            width: 72,
                            height: 14,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          SizedBox(width: 12),
                          SkeletonBox(
                            width: 68,
                            height: 14,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          Spacer(),
                          SkeletonBox(
                            width: 58,
                            height: 22,
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          SkeletonBox(
                            width: 74,
                            height: 32,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          SkeletonBox(
                            width: 96,
                            height: 32,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          SkeletonBox(
                            width: 82,
                            height: 32,
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------- TOP BAR ------------------- */

class _TopBar extends StatelessWidget {
  final String locationLabel;
  final VoidCallback onEditPreferencesTap;
  final VoidCallback onRefreshTap;

  const _TopBar({
    required this.locationLabel,
    required this.onEditPreferencesTap,
    required this.onRefreshTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
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
            child: const Icon(Icons.restaurant, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Swipe2Eat",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      locationLabel,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<_TopBarAction>(
            offset: const Offset(0, 52),
            elevation: 12,
            color: const Color(0xFFFFFBF7),
            surfaceTintColor: Colors.transparent,
            shadowColor: const Color(0x22000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFFE6D6)),
            ),
            menuPadding: const EdgeInsets.symmetric(vertical: 8),
            onSelected: (value) {
              if (value == _TopBarAction.editPreferences) {
                onEditPreferencesTap();
              } else if (value == _TopBarAction.refresh) {
                onRefreshTap();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<_TopBarAction>(
                value: _TopBarAction.editPreferences,
                child: _TopBarMenuItem(
                  icon: Icons.tune_rounded,
                  label: 'Edit preferences',
                ),
              ),
              PopupMenuItem<_TopBarAction>(
                value: _TopBarAction.refresh,
                child: _TopBarMenuItem(
                  icon: Icons.refresh_rounded,
                  label: 'Refresh dishes',
                ),
              ),
            ],
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TopBarAction { editPreferences, refresh }

class _TopBarMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TopBarMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF2E7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFFF6B4A)),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

class _DiscoverPreferenceSelection {
  final List<String> cuisines;
  final String budget;
  final String spice;

  const _DiscoverPreferenceSelection({
    required this.cuisines,
    required this.budget,
    required this.spice,
  });
}

class _QuickPreferencesSheet extends StatefulWidget {
  final List<String> initialCuisines;
  final String initialBudget;
  final String initialSpice;

  const _QuickPreferencesSheet({
    required this.initialCuisines,
    required this.initialBudget,
    required this.initialSpice,
  });

  @override
  State<_QuickPreferencesSheet> createState() => _QuickPreferencesSheetState();
}

class _QuickPreferencesSheetState extends State<_QuickPreferencesSheet> {
  late Set<String> _selectedCuisines;
  late String _selectedBudget;
  late String _selectedSpice;

  static const List<String> _cuisineOptions = [
    'Thai',
    'Chinese',
    'Western',
    'Japanese',
    'Indian',
    'Italian',
    'Korean',
    'Vietnamese',
    'Mediterranean',
    'Malay',
    'Asian',
  ];

  static const List<String> _budgetOptions = ['low', 'medium', 'high'];
  static const Map<String, String> _budgetLabels = {
    'low': 'Budget Friendly',
    'medium': 'Mid Range',
    'high': 'Premium',
  };
  static const List<String> _spiceOptions = ['Mild', 'Medium', 'Hot'];

  @override
  void initState() {
    super.initState();
    _selectedCuisines = Set<String>.from(widget.initialCuisines);
    _selectedBudget = widget.initialBudget;
    _selectedSpice = _normalizeSpice(widget.initialSpice);
  }

  String _normalizeSpice(String value) {
    switch (value.trim().toLowerCase()) {
      case 'mild':
      case '1':
      case 'low':
        return 'Mild';
      case 'hot':
      case '3':
      case 'high':
      case 'spicy':
        return 'Hot';
      case 'medium':
      case '2':
      case 'med':
      default:
        return 'Medium';
    }
  }

  void _toggleCuisine(String cuisine) {
    setState(() {
      if (_selectedCuisines.contains(cuisine)) {
        _selectedCuisines.remove(cuisine);
      } else {
        _selectedCuisines.add(cuisine);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _selectedCuisines.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 80, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Quick Preferences',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cuisines',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _cuisineOptions.map((cuisine) {
                    final selected = _selectedCuisines.contains(cuisine);
                    return FilterChip(
                      label: Text(cuisine),
                      selected: selected,
                      onSelected: (_) => _toggleCuisine(cuisine),
                      selectedColor: const Color(0xFFFFF2E7),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Budget',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _budgetOptions.map((budget) {
                    final selected = _selectedBudget == budget;
                    return FilterChip(
                      label: Text(_budgetLabels[budget]!),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _selectedBudget = budget),
                      selectedColor: const Color(0xFFFFF2E7),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Spice Level',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _spiceOptions.map((spice) {
                    final selected = _selectedSpice == spice;
                    return FilterChip(
                      label: Text(spice),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedSpice = spice),
                      selectedColor: const Color(0xFFFFF2E7),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !canSave
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  _DiscoverPreferenceSelection(
                                    cuisines: _selectedCuisines.toList(),
                                    budget: _selectedBudget,
                                    spice: _selectedSpice,
                                  ),
                                );
                              },
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------- CARD ------------------- */

class _FoodCard extends StatelessWidget {
  final FoodItem item;
  final double width;
  final double height;

  final bool showOverlay;
  final double overlayDx;

  const _FoodCard({
    required this.item,
    required this.width,
    required this.height,
    required this.showOverlay,
    this.overlayDx = 0,
  });

  @override
  Widget build(BuildContext context) {
    final overlay = showOverlay
        ? _SwipeOverlay(dx: overlayDx)
        : const SizedBox.shrink();

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            blurRadius: 28,
            offset: Offset(0, 16),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Column(
              children: [
                // image
                Expanded(
                  flex: 6,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AppNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // rating badge
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // title overlay
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                shadows: [
                                  Shadow(blurRadius: 14, color: Colors.black54),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.restaurant,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                shadows: [
                                  Shadow(blurRadius: 14, color: Colors.black54),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // details
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _SpiceIcons(level: item.spiceLevel),
                            const SizedBox(width: 12),
                            _BudgetIcons(level: item.budgetLevel),
                            const Spacer(),
                            Text(
                              "\$${item.price.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: item.tags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF2E7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      color: Color(0xFFFF6B4A),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // swipe overlay
            Positioned.fill(child: overlay),
          ],
        ),
      ),
    );
  }
}

class _SwipeOverlay extends StatelessWidget {
  final double dx; // drag x

  const _SwipeOverlay({required this.dx});

  @override
  Widget build(BuildContext context) {
    // right swipe => like
    // left swipe => nope
    final isRight = dx > 0;
    final strength = (dx.abs() / 160).clamp(0.0, 1.0);
    if (strength == 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Opacity(
        opacity: strength * 0.9,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isRight
                  ? [const Color(0x3322C55E), const Color(0x00000000)]
                  : [const Color(0x33FF4D4D), const Color(0x00000000)],
              begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
              end: Alignment.center,
            ),
          ),
          child: Align(
            alignment: isRight ? Alignment.topLeft : Alignment.topRight,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isRight ? Icons.favorite : Icons.close,
                    color: isRight
                        ? const Color(0xFF22C55E)
                        : const Color(0xFFFF4D4D),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRight ? "LIKE" : "NOPE",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isRight
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------- ICON ROWS ------------------- */

class _SpiceIcons extends StatelessWidget {
  final int level; // 1..3
  const _SpiceIcons({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final on = i < level;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: on ? const Color(0xFFFF6B4A) : const Color(0xFFE5E7EB),
          ),
        );
      }),
    );
  }
}

class _BudgetIcons extends StatelessWidget {
  final int level; // 1..3
  const _BudgetIcons({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final on = i < level;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            r"$",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: on ? const Color(0xFF16A34A) : const Color(0xFFE5E7EB),
            ),
          ),
        );
      }),
    );
  }
}

/* ------------------- ACTIONS ------------------- */

class _ActionRow extends StatelessWidget {
  final VoidCallback onNope;
  final VoidCallback onLike;
  final bool enabled;

  const _ActionRow({
    required this.onNope,
    required this.onLike,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleAction(
            icon: Icons.close_rounded,
            iconColor: const Color(0xFFEF4444),
            onTap: enabled ? onNope : null,
          ),
          const SizedBox(width: 28),
          _CircleAction(
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFFF6B4A),
            size: 74,
            onTap: enabled ? onLike : null,
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double size;
  final VoidCallback? onTap;

  const _CircleAction({
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            boxShadow: const [
              BoxShadow(
                blurRadius: 18,
                offset: Offset(0, 10),
                color: Color(0x14000000),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: size * 0.42),
        ),
      ),
    );
  }
}

/* ------------------- BOTTOM NAV (TEMP) ------------------- */

enum _NavItem { discover, favorites, profile }

class _BottomNavMock extends StatelessWidget {
  final _NavItem active;
  final void Function(_NavItem item) onTap;

  const _BottomNavMock({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavButton(
            icon: Icons.restaurant_menu,
            label: "Discover",
            active: active == _NavItem.discover,
            onTap: () => onTap(_NavItem.discover),
          ),
          _NavButton(
            icon: Icons.favorite_border,
            label: "Favorites",
            active: active == _NavItem.favorites,
            onTap: () => onTap(_NavItem.favorites),
          ),
          _NavButton(
            icon: Icons.person_outline,
            label: "Profile",
            active: active == _NavItem.profile,
            onTap: () => onTap(_NavItem.profile),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback onAction;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.onAction,
    this.actionLabel = "Retry",
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actionIcon != null) ...[
                  Icon(actionIcon, size: 18, color: const Color(0xFFFF6B4A)),
                  const SizedBox(width: 8),
                ],
                Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2E7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFFF6B4A)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFF6B4A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
