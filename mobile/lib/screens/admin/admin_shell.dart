import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/admin.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../shell/main_shell.dart';
import 'admin_dashboard_screen.dart';

/// The app for an admin account (picked from the Admin previews: E with A's
/// header): Dashboard, Orders, a raised + to add a product, Products, More.
/// "Shop" on the dashboard switches to the customer app.
class AdminShell extends StatefulWidget {
  static const ordersTab = 1, productsTab = 2, moreTab = 3;

  final AdminService? service;

  const AdminShell({super.key, this.service});

  /// Replaces everything with the admin area (after login, or from Profile).
  static void open(BuildContext context) =>
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AdminShell()), (_) => false);

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final AdminService _service = widget.service ?? AdminService();
  int _index = 0;

  /// Kept in sync by the dashboard, for the badges.
  AdminStats? _stats;

  void _openShop() => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);

  void _addProduct() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ComingNext(title: context.l10n.addProduct, icon: Icons.add_box_rounded)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final toHandle = _stats?.ordersToHandle ?? 0;
    final messages = _stats?.openMessages ?? 0;
    Widget badge(int n, Widget icon) =>
        Badge(isLabelVisible: n > 0, label: Text('$n'), backgroundColor: AppTheme.coral, textColor: Colors.white, child: icon);

    // Tabs 0-3 map to the bar's slots 0, 1, 3, 4 (slot 2 is under the + button)
    final slot = _index < 2 ? _index : _index + 1;
    return Scaffold(
      body: IndexedStack(index: _index, children: [
        AdminDashboardScreen(
          service: _service,
          onShop: _openShop,
          onStats: (s) => setState(() => _stats = s),
          onOpenTab: (tab) => setState(() => _index = tab),
        ),
        _ComingNext(title: l.navOrders, icon: Icons.receipt_long_rounded, inTab: true),
        _ComingNext(title: l.navProducts, icon: Icons.inventory_2_rounded, inTab: true),
        _ComingNext(title: l.navMore, icon: Icons.more_horiz_rounded, inTab: true, showLogout: true),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Tooltip(
        message: l.addProduct,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.surface, width: 4),
            boxShadow: [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: FloatingActionButton(
            key: const Key('admin_add_product'),
            onPressed: _addProduct,
            elevation: 0,
            shape: const CircleBorder(),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(boxShadow: [
          if (!dark) BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ]),
        child: NavigationBar(
          selectedIndex: slot,
          onDestinationSelected: (i) {
            if (i == 2) return _addProduct();
            setState(() => _index = i < 2 ? i : i - 1);
          },
          destinations: [
            NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined), selectedIcon: const Icon(Icons.space_dashboard_rounded), label: l.navDashboard),
            NavigationDestination(
              key: const Key('admin_tab_orders'),
              icon: badge(toHandle, const Icon(Icons.receipt_long_outlined)),
              selectedIcon: badge(toHandle, const Icon(Icons.receipt_long_rounded)),
              label: l.navOrders,
            ),
            const NavigationDestination(icon: SizedBox(width: 56), label: '', enabled: false),
            NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: l.navProducts),
            NavigationDestination(
              key: const Key('admin_tab_more'),
              icon: badge(messages, const Icon(Icons.more_horiz_rounded)),
              label: l.navMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stand-in for the admin pages that are designed next (orders, products, more).
class _ComingNext extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool inTab;
  final bool showLogout;

  const _ComingNext({required this.title, required this.icon, this.inTab = false, this.showLogout = false});

  Future<void> _logout(BuildContext context) async {
    final ok = await showLogoutDialog(context);
    if (ok != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconCircle(icon: icon),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(l.adminComingSoon, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (showLogout) ...[
            const SizedBox(height: 24),
            PillButton.danger(key: const Key('admin_logout'), label: l.logOut, leadingIcon: Icons.logout_rounded, onPressed: () => _logout(context)),
          ],
        ]),
      ),
    );
    return inTab ? SafeArea(child: body) : Scaffold(appBar: AppBar(title: Text(title)), body: body);
  }
}
