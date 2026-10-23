import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/shop_provider.dart';
import 'wishlist_fx.dart';

/// Wishlist icon in the bottom navigation bar with a coral count badge.
/// A flying heart lands in it ([WishlistFx]) and it bounces.
class WishlistTabIcon extends StatefulWidget {
  final bool selected;

  const WishlistTabIcon({super.key, this.selected = false});

  @override
  State<WishlistTabIcon> createState() => _WishlistTabIconState();
}

class _WishlistTabIconState extends State<WishlistTabIcon> {
  final _target = GlobalKey();
  AnimationController? _pop;

  @override
  void initState() {
    super.initState();
    WishlistFx.register(_target, () => _pop?.forward(from: 0));
  }

  @override
  void dispose() {
    WishlistFx.unregister(_target);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = context.select<ShopProvider, int>((s) => s.wishlistIds.length);
    return Badge(
      key: Key(widget.selected ? 'tab_wishlist_badge_selected' : 'tab_wishlist_badge'),
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppTheme.coral,
      child: Icon(widget.selected ? Icons.favorite_rounded : Icons.favorite_border_rounded),
    )
        .animate(key: _target, autoPlay: false, onInit: (c) => _pop = c)
        .scaleXY(end: 1.35, duration: 140.ms, curve: Curves.easeOut)
        .then()
        .scaleXY(end: 1 / 1.35, duration: 450.ms, curve: Curves.elasticOut);
  }
}
