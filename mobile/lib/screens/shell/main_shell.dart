import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../cart/cart_screen.dart';
import '../../services/profile_service.dart';
import '../../widgets/cart_tab_icon.dart';
import '../../widgets/icon_circle.dart';
import '../catalog/categories_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';

/// The app after login / "Just browsing": 5 tabs with a bottom navigation
/// bar (Figma: Bottom Nav). Tabs keep their state when switching.
class MainShell extends StatefulWidget {
  static const cartTab = 3;
  static const profileTab = 4;

  /// Asks the shell to show a tab. Pages pushed on top use this after
  /// popping back, e.g. the cart button on Product Details.
  static final requestedTab = ValueNotifier<int?>(null);

  final int initialIndex;

  /// Injected in tests/screenshots; the real API otherwise.
  final ProfileService? profileService;
  final CatalogService? catalogService;
  final CartService? cartService;

  const MainShell({super.key, this.initialIndex = 0, this.profileService, this.catalogService, this.cartService});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    MainShell.requestedTab.addListener(_onTabRequest);
  }

  @override
  void dispose() {
    MainShell.requestedTab.removeListener(_onTabRequest);
    super.dispose();
  }

  void _onTabRequest() {
    final tab = MainShell.requestedTab.value;
    if (tab == null) return;
    MainShell.requestedTab.value = null;
    setState(() => _index = tab);
  }

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.widgets_outlined, Icons.widgets_rounded, 'Categories'),
    (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Wishlist'),
    (Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'Cart'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(catalogService: widget.catalogService, onOpenCart: () => setState(() => _index = MainShell.cartTab)),
          CategoriesScreen(catalogService: widget.catalogService, onOpenCart: () => setState(() => _index = MainShell.cartTab)),
          const _ComingSoonTab(icon: Icons.favorite_rounded, title: 'Wishlist'),
          CartScreen(cartService: widget.cartService, catalogService: widget.catalogService),
          ProfileScreen(service: widget.profileService),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            if (!dark) BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final (i, (icon, selected, label)) in _tabs.indexed)
              i == MainShell.cartTab
                  ? NavigationDestination(icon: const CartTabIcon(), selectedIcon: const CartTabIcon(selected: true), label: label)
                  : NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for tabs that are built in later branches.
class _ComingSoonTab extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ComingSoonTab({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconCircle(icon: icon, color: title == 'Wishlist' ? AppTheme.coral : null),
                const SizedBox(height: 20),
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Coming soon', style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
