import 'package:flutter/material.dart';

import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../cart/cart_screen.dart';
import '../../services/profile_service.dart';
import '../../widgets/cart_tab_icon.dart';
import '../catalog/categories_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../../l10n/l10n.dart';

/// The app after login / "Just browsing": 5 tabs with a bottom navigation
/// bar (Figma: Bottom Nav). Tabs keep their state when switching.
class MainShell extends StatefulWidget {
  static const wishlistTab = 2;
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

  static List<(IconData, IconData, String)> _tabs(AppLocalizations l) => [
        (Icons.home_outlined, Icons.home_rounded, l.navHome),
        (Icons.widgets_outlined, Icons.widgets_rounded, l.navCategories),
        (Icons.favorite_border_rounded, Icons.favorite_rounded, l.navWishlist),
        (Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, l.navCart),
        (Icons.person_outline_rounded, Icons.person_rounded, l.navProfile),
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
          WishlistScreen(catalogService: widget.catalogService),
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
            for (final (i, (icon, selected, label)) in _tabs(context.l10n).indexed)
              i == MainShell.cartTab
                  ? NavigationDestination(icon: const CartTabIcon(), selectedIcon: const CartTabIcon(selected: true), label: label)
                  : NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
          ],
        ),
      ),
    );
  }
}

