import 'package:flutter/material.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/favorites/favorites_screen.dart';
import '../../features/profile/profile_screen.dart';

enum MainTab { discover, favorites, profile }

class MainShell extends StatefulWidget {
  final MainTab initialTab;

  const MainShell({super.key, this.initialTab = MainTab.discover});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1),

      // Keeps state of each tab (scroll position etc.)
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: const [
            DiscoverScreen(showBottomNav: false),
            FavoritesScreen(showBottomNav: false),
            ProfileScreen(showBottomNav: false),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        bottom: true,
        child: _BottomNav(
          activeIndex: _index,
          onTap: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int activeIndex;
  final void Function(int) onTap;

  const _BottomNav({required this.activeIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navBtn(icon: Icons.restaurant_menu, label: "Discover", index: 0),
          _navBtn(icon: Icons.favorite_border, label: "Favorites", index: 1),
          _navBtn(icon: Icons.person_outline, label: "Profile", index: 2),
        ],
      ),
    );
  }

  Widget _navBtn({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final active = index == activeIndex;

    if (!active) {
      return GestureDetector(
        onTap: () => onTap(index),
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

    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
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
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
