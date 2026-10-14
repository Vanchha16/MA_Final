import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/shop_provider.dart';
import 'round_icon_button.dart';

/// Round cart button with a coral badge showing the live cart count.
class CartButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CartButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<ShopProvider>().cartCount;
    return Badge(
      key: const Key('cart_badge'),
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppTheme.coral,
      offset: const Offset(-2, 2),
      child: RoundIconButton(icon: Icons.shopping_cart_outlined, tooltip: 'Cart', onPressed: onPressed),
    );
  }
}
