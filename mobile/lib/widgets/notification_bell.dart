import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/shop_provider.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/shop/shop_actions.dart';
import 'round_icon_button.dart';

/// The bell on Home and Profile, with a red count of unread messages.
/// Opens Notifications (guests are asked to log in).
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  Future<void> _open(BuildContext context) async {
    final shop = context.read<ShopProvider>();
    if (!shop.signedIn) return ShopActions.askToLogin(context, 'Log in to see your notifications');
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    await shop.refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select<ShopProvider, int>((s) => s.unreadNotifications);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RoundIconButton(
          key: const Key('notification_bell'),
          icon: unread > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
          tooltip: unread > 0 ? 'Notifications, $unread new' : 'Notifications',
          onPressed: () => _open(context),
        ),
        if (unread > 0)
          Positioned(
            right: -2,
            top: -2,
            child: IgnorePointer(
              child: Container(
                key: const Key('notification_badge'),
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.coral,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dark ? scheme.surface : Colors.white, width: 2),
                ),
                child: Text(unread > 99 ? '99+' : '$unread', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ],
    );
  }
}
