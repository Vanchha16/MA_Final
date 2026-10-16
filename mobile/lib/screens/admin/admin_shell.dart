import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/admin.dart';
import '../../services/admin_service.dart';
import '../shell/main_shell.dart';
import 'admin_dashboard_screen.dart';
import 'admin_more_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';

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
  final _dashboard = GlobalKey<AdminDashboardScreenState>();
  final _orders = GlobalKey<AdminOrdersScreenState>();
  final _products = GlobalKey<AdminProductsScreenState>();
  int _index = 0;

  /// Kept in sync by the dashboard, for the badges.
  AdminStats? _stats;

  void _openShop() => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (_) => false);

  /// Something changed on one tab: refresh the others' numbers.
  void _changed() {
    _dashboard.currentState?.reload();
    _orders.currentState?.reload();
    _products.currentState?.reload();
  }

  Future<void> _addProduct() async {
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AdminProductFormScreen(service: _service)));
    if (added == true) _changed();
  }

  void _openTab(int tab) {
    setState(() => _index = tab);
    if (tab == AdminShell.productsTab) _products.currentState?.showLowStock();
  }

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
          key: _dashboard,
          service: _service,
          onShop: _openShop,
          onStats: (s) => setState(() => _stats = s),
          onOpenTab: _openTab,
        ),
        AdminOrdersScreen(key: _orders, service: _service, onChanged: _changed),
        AdminProductsScreen(key: _products, service: _service, onChanged: _changed),
        AdminMoreScreen(service: _service, onShop: _openShop, openMessages: messages, onChanged: _changed),
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
            if (i == 2) {
              _addProduct();
              return;
            }
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
            NavigationDestination(key: const Key('admin_tab_products'), icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: l.navProducts),
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
