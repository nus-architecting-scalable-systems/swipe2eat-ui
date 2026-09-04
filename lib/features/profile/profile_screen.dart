import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/user_service.dart';
import '../../core/state/favorites_store.dart';
import '../../core/services/preferences_service.dart';
import '../auth/services/token_storage.dart';

const List<String> _cuisineOptions = [
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

const List<String> _budgetOptions = ['low', 'medium', 'high'];
const Map<String, String> _budgetLabels = {
  'low': 'Budget Friendly',
  'medium': 'Mid Range',
  'high': 'Premium',
};
const List<String> _spiceOptions = ['Mild', 'Medium', 'Hot'];

String _normalizeSpiceValue(String value) {
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

class ProfileScreen extends StatefulWidget {
  final bool showBottomNav;
  const ProfileScreen({super.key, this.showBottomNav = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = "Food Explorer";
  String _cuisinesDisplay = "Loading...";
  String _spiceDisplay = "Loading...";
  String _budgetDisplay = "Loading...";
  String _genderDisplay = "Not set";
  String _dobDisplay = "Not set";

  static const String _prefsCuisinesKey = 'prefs.cuisines';
  static const String _prefsBudgetKey = 'prefs.budget';
  static const String _prefsBudgetLabelKey = 'prefs.budgetLabel';
  static const String _prefsSpiceKey = 'prefs.spice';
  static const String _prefsDietTypeKey = 'prefs.dietType';
  static const String _prefsAllergensKey = 'prefs.allergens';

  @override
  void initState() {
    super.initState();
    _loadUserNameFromToken();
    _loadPreferences();
    _loadUserProfile();
    // Listen for preference updates
    PreferencesService.preferencesUpdated.addListener(_onPreferencesUpdated);
  }

  @override
  void dispose() {
    PreferencesService.preferencesUpdated.removeListener(_onPreferencesUpdated);
    super.dispose();
  }

  void _onPreferencesUpdated() {
    _loadPreferences();
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserService.getUserProfile();
    if (!mounted || profile == null) return;
    final gender = profile['gender'] as String?;
    final dobRaw = profile['dateOfBirth'] as String?;
    String dobDisplay = "Not set";
    if (dobRaw != null && dobRaw.isNotEmpty) {
      final dob = DateTime.tryParse(dobRaw);
      if (dob != null) {
        dobDisplay =
            "${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}";
      }
    }
    setState(() {
      _genderDisplay = gender != null && gender.isNotEmpty ? gender : "Not set";
      _dobDisplay = dobDisplay;
    });
  }

  Future<void> _loadUserNameFromToken() async {
    try {
      final idToken = await TokenStorage.getIdToken();
      if (idToken == null || idToken.isEmpty) return;

      final parts = idToken.split('.');
      if (parts.length != 3) return;

      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is! Map) return;

      final name = (payload['name'] ?? payload['given_name'])
          ?.toString()
          .trim();
      if (!mounted || name == null || name.isEmpty) return;

      setState(() {
        _displayName = name;
      });
    } catch (_) {
      // Keep fallback display name when token name is unavailable.
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UserService.logoutCurrentUser();

      // Clear all tokens
      await TokenStorage.clearTokens();

      // Clear favorites
      FavoritesStore.instance.clear();

      // Navigate to sign-in screen and remove all previous routes
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/sign-in', (route) => false);
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final cuisines = prefs.getStringList(_prefsCuisinesKey) ?? [];
    final budgetRaw = prefs.getString(_prefsBudgetKey);
    final legacyBudgetLabel = prefs.getString(_prefsBudgetLabelKey);
    final budget =
        budgetRaw ??
        _legacyBudgetLabelToBudgetValue(legacyBudgetLabel) ??
        "Not set";
    final spice = prefs.getString(_prefsSpiceKey) ?? "Not set";

    if (mounted) {
      setState(() {
        _cuisinesDisplay = cuisines.isNotEmpty
            ? cuisines.join(", ")
            : "Not set";
        _budgetDisplay = _getBudgetDisplay(budget);
        _spiceDisplay = spice;
      });
    }
  }

  String _getBudgetDisplay(String budget) {
    switch (budget.toLowerCase()) {
      case 'low':
      case 'budget friendly':
        return "\$";
      case 'medium':
      case 'mid range':
        return "\$\$";
      case 'high':
      case 'premium':
        return "\$\$\$";
      default:
        return budget;
    }
  }

  String? _legacyBudgetLabelToBudgetValue(String? label) {
    if (label == null || label.trim().isEmpty) return null;
    switch (label.trim().toLowerCase()) {
      case 'budget friendly':
        return 'low';
      case 'mid range':
        return 'medium';
      case 'premium':
        return 'high';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8F1),
      child: Column(
        children: [
          const SizedBox(height: 14),

          // Header
          Padding(
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
                  child: const Icon(Icons.person_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Profile",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileCard(displayName: _displayName),
                  const SizedBox(height: 18),

                  const Text(
                    "Personal Info",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),

                  _PrefTile(
                    icon: Icons.wc_rounded,
                    title: "Gender",
                    value: _genderDisplay,
                    onTap: () => _showEditProfileDialog(context),
                  ),
                  _PrefTile(
                    icon: Icons.cake_rounded,
                    title: "Date of Birth",
                    value: _dobDisplay,
                    onTap: () => _showEditProfileDialog(context),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "Your Preferences",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),

                  _PrefTile(
                    icon: Icons.restaurant_menu,
                    title: "Cuisines",
                    value: _cuisinesDisplay,
                    onTap: () {
                      _showCuisineEditor(context);
                    },
                  ),
                  _PrefTile(
                    icon: Icons.local_fire_department_rounded,
                    title: "Spice Level",
                    value: _spiceDisplay,
                    onTap: () {
                      _showSpiceEditor(context);
                    },
                  ),
                  _PrefTile(
                    icon: Icons.attach_money_rounded,
                    title: "Budget",
                    value: _budgetDisplay,
                    onTap: () {
                      _showBudgetEditor(context);
                    },
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "Account",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),

                  _ActionTile(
                    icon: Icons.person_outline_rounded,
                    title: "Edit Profile Info",
                    onTap: () => _showEditProfileDialog(context),
                  ),
                  _ActionTile(
                    icon: Icons.edit_rounded,
                    title: "Edit Preferences",
                    onTap: () {
                      _showEditPreferencesDialog(context);
                    },
                  ),
                  _ActionTile(
                    icon: Icons.logout_rounded,
                    title: "Logout",
                    danger: true,
                    onTap: _handleLogout,
                  ),
                  _ActionTile(
                    icon: Icons.delete_forever_rounded,
                    title: "Delete Account",
                    danger: true,
                    onTap: _handleDeleteAccount,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your account and preferences. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleted = await UserService.deleteCurrentUserInBackend();
    if (!mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to delete account. Please try again.'),
        ),
      );
      return;
    }

    await _clearLocalUserData();
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Account deleted')));
    Navigator.of(context).pushNamedAndRemoveUntil('/sign-in', (route) => false);
  }

  Future<void> _clearLocalUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsCuisinesKey);
    await prefs.remove(_prefsBudgetKey);
    await prefs.remove(_prefsBudgetLabelKey);
    await prefs.remove(_prefsSpiceKey);
    await prefs.remove(_prefsDietTypeKey);
    await prefs.remove(_prefsAllergensKey);
    FavoritesStore.instance.clear();
    await TokenStorage.clearTokens();
  }

  void _showEditProfileDialog(BuildContext context) async {
    final currentGender = _genderDisplay == "Not set" ? null : _genderDisplay;
    final currentDob = _dobDisplay == "Not set"
        ? null
        : DateTime.tryParse(_dobDisplay);

    showDialog(
      context: context,
      builder: (_) => _ProfileInfoDialog(
        initialGender: currentGender,
        initialDateOfBirth: currentDob,
        onSave: (gender, dob) async {
          final success = await UserService.updateUserProfile(
            gender: gender,
            dateOfBirth: dob,
          );
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Profile updated successfully'
                      : 'Failed to update profile. Please try again.',
                ),
              ),
            );
          }
          if (success) await _loadUserProfile();
        },
      ),
    );
  }

  void _showEditPreferencesDialog(BuildContext context) async {
    final prefs = await PreferencesService.getLocalPreferences();
    final currentCuisines = List<String>.from(prefs['cuisines'] ?? []);
    final currentBudget = prefs['budget'] ?? 'low';
    final currentSpice = prefs['spiceLevel']?.toString() ?? 'Medium';

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => _PreferencesDialog(
        initialCuisines: currentCuisines,
        initialBudget: currentBudget,
        initialSpice: currentSpice,
        onSave: (cuisines, budget, spice) async {
          final synced = await _persistPreferenceChanges(
            cuisines: cuisines,
            budget: budget,
            spice: spice,
          );

          if (context.mounted) {
            Navigator.pop(context); // Close dialog

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  synced
                      ? "Preferences updated and discover screen refreshed"
                      : "Preferences saved locally (sync failed)",
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<bool> _persistPreferenceChanges({
    required List<String> cuisines,
    required String budget,
    required String spice,
  }) async {
    final synced = await PreferencesService.updatePreferences(
      cuisines: cuisines,
      budget: budget,
      spiceLevel: spice,
    );

    if (synced) {
      await PreferencesService.fetchPreferencesFromBackend();
    } else {
      await PreferencesService.saveLocalPreferences(
        cuisines: cuisines,
        budget: budget,
        spiceLevel: spice,
      );
    }

    return synced;
  }

  Future<void> _showCuisineEditor(BuildContext context) async {
    final prefs = await PreferencesService.getLocalPreferences();
    final currentCuisines = List<String>.from(prefs['cuisines'] ?? []);
    final currentBudget = prefs['budget']?.toString() ?? 'low';
    final currentSpice = _normalizeSpiceValue(
      prefs['spiceLevel']?.toString() ?? 'Medium',
    );
    if (!context.mounted) return;

    final selection = await showDialog<List<String>>(
      context: context,
      builder: (_) => _CuisineEditorSheet(initialCuisines: currentCuisines),
    );

    if (selection == null) return;

    final cuisines = List<String>.from(selection)..sort();
    final synced = await _persistPreferenceChanges(
      cuisines: cuisines,
      budget: currentBudget,
      spice: currentSpice,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Cuisine preferences updated.'
              : 'Cuisine preferences saved locally (sync failed).',
        ),
      ),
    );
  }

  Future<void> _showSpiceEditor(BuildContext context) async {
    final prefs = await PreferencesService.getLocalPreferences();
    final currentCuisines = List<String>.from(prefs['cuisines'] ?? []);
    final currentBudget = prefs['budget']?.toString() ?? 'low';
    final currentSpice = _normalizeSpiceValue(
      prefs['spiceLevel']?.toString() ?? 'Medium',
    );
    if (!context.mounted) return;

    final selection = await showDialog<String>(
      context: context,
      builder: (_) => _SpiceEditorSheet(initialSpice: currentSpice),
    );

    if (selection == null) return;

    final synced = await _persistPreferenceChanges(
      cuisines: currentCuisines,
      budget: currentBudget,
      spice: selection,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Spice preference updated.'
              : 'Spice preference saved locally (sync failed).',
        ),
      ),
    );
  }

  Future<void> _showBudgetEditor(BuildContext context) async {
    final prefs = await PreferencesService.getLocalPreferences();
    final currentCuisines = List<String>.from(prefs['cuisines'] ?? []);
    final currentBudget = prefs['budget']?.toString() ?? 'low';
    final currentSpice = _normalizeSpiceValue(
      prefs['spiceLevel']?.toString() ?? 'Medium',
    );
    if (!context.mounted) return;

    final selection = await showDialog<String>(
      context: context,
      builder: (_) => _BudgetEditorSheet(initialBudget: currentBudget),
    );

    if (selection == null) return;

    final synced = await _persistPreferenceChanges(
      cuisines: currentCuisines,
      budget: selection,
      spice: currentSpice,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Budget preference updated.'
              : 'Budget preference saved locally (sync failed).',
        ),
      ),
    );
  }
}

//for profile card -- supporting UI parts

class _ProfileCard extends StatelessWidget {
  final String displayName;

  const _ProfileCard({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 10),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A3D), Color(0xFFFF4D4D)],
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder(
                  valueListenable: FavoritesStore.instance.favorites,
                  builder: (context, list, child) {
                    return Text(
                      "${list.length} favorites saved",
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _PrefTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF6B4A)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w900, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferencesDialog extends StatefulWidget {
  final List<String> initialCuisines;
  final String initialBudget;
  final String initialSpice;
  final Function(List<String> cuisines, String budget, String spice) onSave;

  const _PreferencesDialog({
    required this.initialCuisines,
    required this.initialBudget,
    required this.initialSpice,
    required this.onSave,
  });

  @override
  State<_PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<_PreferencesDialog> {
  late Set<String> _selectedCuisines;
  late String _selectedBudget;
  late String _selectedSpice;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCuisines = Set.from(widget.initialCuisines);
    _selectedBudget = widget.initialBudget;
    _selectedSpice = _normalizeSpiceValue(widget.initialSpice);
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
    return AlertDialog(
      title: const Text('Edit Preferences'),
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cuisines',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _cuisineOptions.map((cuisine) {
                  final selected = _selectedCuisines.contains(cuisine);
                  return FilterChip(
                    label: Text(cuisine),
                    selected: selected,
                    onSelected: (_) => _toggleCuisine(cuisine),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFFFF2E7),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFFFF6B4A)
                          : const Color(0xFF111827),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Budget',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _budgetOptions.map((budget) {
                  final selected = _selectedBudget == budget;
                  return FilterChip(
                    label: Text(_budgetLabels[budget]!),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedBudget = budget),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFFFF2E7),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFFFF6B4A)
                          : const Color(0xFF111827),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Spice Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _spiceOptions.map((spice) {
                  final selected = _selectedSpice == spice;
                  return FilterChip(
                    label: Text(spice),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedSpice = spice),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFFFFF2E7),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? const Color(0xFFFF6B4A)
                          : const Color(0xFF111827),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.onSave(
                    _selectedCuisines.toList()..sort(),
                    _selectedBudget,
                    _selectedSpice,
                  );
                },
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F1),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                blurRadius: 24,
                offset: Offset(0, 16),
                color: Color(0x22000000),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CuisineEditorSheet extends StatefulWidget {
  final List<String> initialCuisines;

  const _CuisineEditorSheet({required this.initialCuisines});

  @override
  State<_CuisineEditorSheet> createState() => _CuisineEditorSheetState();
}

class _CuisineEditorSheetState extends State<_CuisineEditorSheet> {
  late Set<String> _selectedCuisines;

  @override
  void initState() {
    super.initState();
    _selectedCuisines = Set<String>.from(widget.initialCuisines);
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

    return _SheetFrame(
      title: 'Edit Cuisines',
      subtitle: 'Choose the cuisines that should shape your recommendations.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cuisineOptions.map((cuisine) {
              final selected = _selectedCuisines.contains(cuisine);
              return FilterChip(
                label: Text(cuisine),
                selected: selected,
                onSelected: (_) => _toggleCuisine(cuisine),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFFFFF2E7),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? const Color(0xFFFF6B4A)
                      : const Color(0xFF111827),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
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
                      : () =>
                            Navigator.pop(context, _selectedCuisines.toList()),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetEditorSheet extends StatefulWidget {
  final String initialBudget;

  const _BudgetEditorSheet({required this.initialBudget});

  @override
  State<_BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends State<_BudgetEditorSheet> {
  late String _selectedBudget;

  @override
  void initState() {
    super.initState();
    _selectedBudget = widget.initialBudget;
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Edit Budget',
      subtitle: 'Set the spending range you want us to bias toward.',
      child: Column(
        children: [
          ..._budgetOptions.map((budget) {
            final selected = _selectedBudget == budget;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _selectedBudget = budget),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFF2E7) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFB28E)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFF6B4A)
                              : const Color(0xFFFFF2E7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.attach_money_rounded,
                          color: selected
                              ? Colors.white
                              : const Color(0xFFFF6B4A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _budgetLabels[budget]!,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFFFF6B4A),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
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
                  onPressed: () => Navigator.pop(context, _selectedBudget),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const List<String> _genderOptions = [
  'male',
  'female',
  'non-binary',
  'prefer not to say',
];

class _ProfileInfoDialog extends StatefulWidget {
  final String? initialGender;
  final DateTime? initialDateOfBirth;
  final Future<void> Function(String? gender, DateTime? dateOfBirth) onSave;

  const _ProfileInfoDialog({
    required this.initialGender,
    required this.initialDateOfBirth,
    required this.onSave,
  });

  @override
  State<_ProfileInfoDialog> createState() => _ProfileInfoDialogState();
}

class _ProfileInfoDialogState extends State<_ProfileInfoDialog> {
  String? _selectedGender;
  DateTime? _selectedDob;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.initialGender;
    _selectedDob = widget.initialDateOfBirth;
  }

  String _formatDate(DateTime dt) =>
      "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDob = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile Info'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gender',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            hint: const Text('Select gender'),
            items: _genderOptions
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _selectedGender = v),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Date of Birth',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF9CA3AF)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDob != null
                          ? _formatDate(_selectedDob!)
                          : 'Select date',
                      style: TextStyle(
                        color: _selectedDob != null
                            ? const Color(0xFF111827)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() => _saving = true);
                  await widget.onSave(_selectedGender, _selectedDob);
                },
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _SpiceEditorSheet extends StatefulWidget {
  final String initialSpice;

  const _SpiceEditorSheet({required this.initialSpice});

  @override
  State<_SpiceEditorSheet> createState() => _SpiceEditorSheetState();
}

class _SpiceEditorSheetState extends State<_SpiceEditorSheet> {
  late String _selectedSpice;

  @override
  void initState() {
    super.initState();
    _selectedSpice = _normalizeSpiceValue(widget.initialSpice);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Edit Spice Level',
      subtitle: 'Choose how bold you want your flavor recommendations to be.',
      child: Column(
        children: [
          ..._spiceOptions.map((spice) {
            final selected = _selectedSpice == spice;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _selectedSpice = spice),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFF2E7) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFB28E)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFFF6B4A)
                              : const Color(0xFFFFF2E7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          spice == 'Hot'
                              ? Icons.local_fire_department_rounded
                              : spice == 'Medium'
                              ? Icons.whatshot_rounded
                              : Icons.eco_rounded,
                          color: selected
                              ? Colors.white
                              : const Color(0xFFFF6B4A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          spice,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFFFF6B4A),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
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
                  onPressed: () => Navigator.pop(context, _selectedSpice),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
