import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../providers/shop_provider.dart';
import '../../services/catalog_service.dart';
import '../../services/shop_service.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';
import '../auth/login_screen.dart';
import '../shell/main_shell.dart';
import '../shop/shop_actions.dart';
import 'widgets/wishlist_board_view.dart';
import 'widgets/wishlist_select_view.dart';
import 'widgets/wishlist_swipe_view.dart';
import '../../l10n/l10n.dart';

/// The three ways to look at the wishlist. Swipe is the default; the
/// customer can switch to Board or Select and the choice is remembered.
enum WishlistView {
  swipe('Swipe', Icons.style_rounded),
  board('Board', Icons.dashboard_rounded),
  select('Select', Icons.checklist_rounded);

  final String label;
  final IconData icon;
  const WishlistView(this.label, this.icon);
}

/// Wishlist tab (Figma: Wishlist G - Swipe, C - Board, D - Select).
/// All three views share the same list and actions: remove (with Undo),
/// move to cart (one of each, taken off the wishlist) and open the product.
class WishlistScreen extends StatefulWidget {
  final CatalogService? catalogService;

  const WishlistScreen({super.key, this.catalogService});

  /// The chosen view is remembered on this device.
  static const viewPrefKey = 'wishlist_view';

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Product>? _items;
  String? _error;
  bool? _signedIn;
  WishlistView _view = WishlistView.swipe;

  /// True while this screen changes the wishlist itself, so the heart
  /// watcher below does not mistake our own change for one made elsewhere.
  bool _busy = false;

  /// Bumped when the list is loaded fresh, so the swipe view deals a new deck.
  int _round = 0;

  @override
  void initState() {
    super.initState();
    _loadView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shop = context.watch<ShopProvider>();
    if (_signedIn != shop.signedIn) {
      _signedIn = shop.signedIn;
      if (shop.signedIn) {
        _load();
      } else {
        setState(() => _items = null);
      }
    } else if (shop.signedIn && _items != null && !_busy && !setEquals(shop.wishlistIds, {for (final p in _items!) p.id})) {
      // A heart was tapped on another screen
      _load();
    }
  }

  Future<void> _loadView() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(WishlistScreen.viewPrefKey);
      final view = WishlistView.values.where((v) => v.name == saved).firstOrNull;
      if (view != null && mounted) setState(() => _view = view);
    } catch (_) {
      // Only a convenience; Swipe is the default
    }
  }

  Future<void> _setView(WishlistView view) async {
    setState(() => _view = view);
    try {
      await (await SharedPreferences.getInstance()).setString(WishlistScreen.viewPrefKey, view.name);
    } catch (_) {
      // Only a convenience
    }
  }

  /// [newDeck] false keeps the swipe view where it is (used after Undo).
  Future<void> _load({bool newDeck = true}) async {
    _busy = true;
    try {
      final items = await context.read<ShopProvider>().loadWishlist();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        if (newDeck) _round++;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      _busy = false;
    }
  }

  void _snack(String message, {SnackBarAction? action}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    // Undo/View snacks still go away by themselves, so they never sit over the buttons
    ..showSnackBar(SnackBar(content: Text(message), action: action, persist: false, duration: const Duration(seconds: 4), behavior: SnackBarBehavior.floating));

  List<int> _ids(List<Product> products) => [for (final p in products) p.id];

  /// Removes right away and offers Undo. [onUndo] lets the swipe view bring its card back.
  Future<void> _remove(List<Product> products, {VoidCallback? onUndo}) async {
    final ids = _ids(products);
    final shop = context.read<ShopProvider>();
    _busy = true;
    setState(() => _items = _items!.where((p) => !ids.contains(p.id)).toList());
    try {
      await shop.removeManyFromWishlist(ids);
      _snack(
        products.length == 1 ? 'Removed ${products.first.name}' : 'Removed ${products.length} items',
        action: SnackBarAction(label: 'Undo', onPressed: () => _restore(products, onUndo)),
      );
    } on ApiException catch (e) {
      _snack(e.message);
      _busy = false;
      await _load(newDeck: false);
    } finally {
      _busy = false;
    }
  }

  Future<void> _restore(List<Product> products, VoidCallback? onUndo) async {
    try {
      await context.read<ShopProvider>().restoreWishlist(_ids(products));
      onUndo?.call();
      await _load(newDeck: false);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  /// Adds one of each to the cart and takes them off the wishlist.
  /// Returns false when nothing could be moved (e.g. sold out).
  Future<bool> _moveToCart(List<Product> products) async {
    final shop = context.read<ShopProvider>();
    final navigator = Navigator.of(context);
    _busy = true;
    try {
      final result = await shop.moveToCart(_ids(products));
      if (!mounted) return false;
      setState(() => _items = _items!.where((p) => !result.moved.contains(p.id)).toList());
      _snack(_movedMessage(products, result), action: result.moved.isEmpty ? null : SnackBarAction(label: 'View', onPressed: () => ShopActions.openCart(navigator)));
      return result.moved.isNotEmpty;
    } on ApiException catch (e) {
      _snack(e.message);
      return false;
    } finally {
      _busy = false;
    }
  }

  String _movedMessage(List<Product> products, MoveToCartResult result) {
    final moved = result.moved.length, skipped = result.skipped.length;
    if (moved == 0) return skipped == 1 ? 'This item is sold out' : 'These items are sold out';
    final what = moved == 1 ? products.firstWhere((p) => p.id == result.moved.first).name : '$moved items';
    return skipped == 0 ? 'Moved $what to your cart' : 'Moved $what to your cart. $skipped sold out stayed saved.';
  }

  void _open(Product product) => ShopActions.openProduct(context, product, catalog: widget.catalogService);

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<ShopProvider>().signedIn;
    final items = _items;
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (!signedIn) {
      body = const _GuestState();
    } else if (_error != null && items == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            PillButton(key: const Key('wishlist_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: _load),
          ],
        ),
      );
    } else if (items == null) {
      body = const _LoadingState();
    } else if (items.isEmpty) {
      body = _EmptyState(onShop: () => MainShell.requestedTab.value = 0);
    } else {
      body = switch (_view) {
        WishlistView.swipe => WishlistSwipeView(
            key: ValueKey('deck_$_round'),
            items: items,
            onMove: (p) => _moveToCart([p]),
            onRemove: (p, undo) => _remove([p], onUndo: undo),
            onOpen: _open,
            onStartOver: _load,
          ),
        WishlistView.board => WishlistBoardView(
            items: items,
            onRemove: (p) => _remove([p]),
            onOpen: _open,
            onRefresh: _load,
          ),
        WishlistView.select => WishlistSelectView(
            items: items,
            onRemove: _remove,
            onMove: _moveToCart,
            onOpen: _open,
          ),
      };
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.wishlistTitle, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        if (items != null && items.isNotEmpty)
                          Text(
                            context.l10n.savedItems(items.length),
                            key: const Key('wishlist_count'),
                            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (signedIn && items != null && items.isNotEmpty) _ViewSwitch(value: _view, onChanged: _setView),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Swipe / Board / Select, as three icon buttons in a pill.
class _ViewSwitch extends StatelessWidget {
  final WishlistView value;
  final ValueChanged<WishlistView> onChanged;

  const _ViewSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: dark ? scheme.surfaceContainerHigh : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final view in WishlistView.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                key: Key('view_${view.name}'),
                tooltip: '${view.label} view',
                isSelected: view == value,
                onPressed: () => onChanged(view),
                style: IconButton.styleFrom(
                  fixedSize: const Size(40, 36),
                  minimumSize: const Size(40, 36),
                  padding: EdgeInsets.zero,
                  backgroundColor: view == value ? (dark ? scheme.surfaceContainerHighest : Colors.white) : Colors.transparent,
                  foregroundColor: view == value ? accent : scheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                icon: Icon(view.icon, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onShop;

  const _EmptyState({required this.onShop});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: const Key('wishlist_empty'),
          children: [
            const IconCircle(icon: Icons.favorite_rounded, color: AppTheme.coral),
            const SizedBox(height: 18),
            const Text('No saved items yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Tap the heart on any figure, plush or card to keep it here for later.',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            PillButton(key: const Key('wishlist_shop'), label: 'Start shopping', leadingIcon: Icons.storefront_outlined, onPressed: onShop),
          ],
        ),
      ),
    );
  }
}

class _GuestState extends StatelessWidget {
  const _GuestState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconCircle(icon: Icons.favorite_rounded, color: AppTheme.coral),
            const SizedBox(height: 18),
            const Text('Log in to see your wishlist', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Saved items stay on your account, on every device.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            PillButton(
              key: const Key('wishlist_login'),
              label: 'Log in',
              leadingIcon: Icons.login_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Shimmer.fromColors(
      key: const Key('wishlist_loading'),
      enabled: !reduceMotion,
      baseColor: dark ? scheme.surfaceContainerHighest : const Color(0xFFE8F1FA),
      highlightColor: dark ? scheme.surfaceContainerHigh : const Color(0xFFF7FBFF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 8, 36, 120),
        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28))),
      ),
    );
  }
}
