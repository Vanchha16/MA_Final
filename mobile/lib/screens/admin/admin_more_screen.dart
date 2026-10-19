import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/admin.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/pill_button.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_widgets.dart';

const _violet = Color(0xFF7C3AED);
const _cyan = Color(0xFF06B6D4);

/// Admin More tab: Messages, Customers, Categories, Staff (owner only), then the
/// shop, the web admin, Settings and Log out.
class AdminMoreScreen extends StatelessWidget {
  final AdminService service;
  final int openMessages;
  final VoidCallback onShop;
  final VoidCallback? onChanged;

  const AdminMoreScreen({super.key, required this.service, required this.onShop, this.openMessages = 0, this.onChanged});

  Future<void> _logout(BuildContext context) async {
    final ok = await showLogoutDialog(context);
    if (ok != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Future<void> push(Widget page) async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      onChanged?.call();
    }

    Widget row(String key, IconData icon, Color color, String title, String sub, VoidCallback onTap, {int badge = 0}) => ListTile(
          key: Key('admin_more_$key'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 21)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (badge > 0) ...[AdminChip('$badge', AppTheme.coral), const SizedBox(width: 6)],
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ]),
          onTap: onTap,
        );
    Widget group(List<Widget> rows) => AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, r) in rows.indexed) ...[if (i > 0) Divider(height: 1, indent: 70, color: scheme.outlineVariant.withValues(alpha: 0.5)), r],
          ]),
        );
    final owner = context.watch<AuthProvider>().user?.isAdmin ?? false;
    // The Flask-Admin panel is for the owner; staff use the web admin
    final panel = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), owner ? '/admin' : '/dashboard');
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), children: [
        const Padding(padding: EdgeInsets.fromLTRB(0, 10, 0, 12), child: AdminTitleText('More')),
        group([
          row('messages', Icons.forum_rounded, _cyan, 'Messages', 'Questions from the Contact screen', () => push(AdminMessagesScreen(service: service)), badge: openMessages),
          row('customers', Icons.people_rounded, AppTheme.success, 'Customers', owner ? 'Orders, spending, block or unblock' : 'Orders and spending', () => push(AdminCustomersScreen(service: service))),
          row('categories', Icons.category_rounded, _violet, 'Categories', 'Add, rename or delete', () => push(AdminCategoriesScreen(service: service))),
          if (owner) row('staff', Icons.badge_rounded, AppTheme.abaNavy, 'Staff', 'Add staff, roles, passwords', () => push(AdminStaffScreen(service: service))),
        ]),
        const SizedBox(height: 12),
        group([
          row('shop', Icons.storefront_rounded, scheme.primary, 'Open the shop', 'See it the way customers do', onShop),
          row('web', Icons.language_rounded, AppTheme.amber, 'Web admin panel', 'Same tools on a computer: $panel', () {
            Clipboard.setData(ClipboardData(text: panel));
            adminSnack(context, 'Copied $panel');
          }),
          row('settings', Icons.settings_rounded, scheme.onSurfaceVariant, 'Settings', 'Theme, language', () => push(const SettingsScreen())),
        ]),
        const SizedBox(height: 18),
        PillButton.danger(key: const Key('admin_logout'), label: 'Log out', leadingIcon: Icons.logout_rounded, onPressed: () => _logout(context)),
      ]),
    );
  }
}

class AdminTitleText extends StatelessWidget {
  final String text;

  const AdminTitleText(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold));
}

// ---------------------------------------------------------------------------
// Categories
// ---------------------------------------------------------------------------

class AdminCategoriesScreen extends StatefulWidget {
  final AdminService service;

  const AdminCategoriesScreen({super.key, required this.service});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<AdminCategory>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.service.categories();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit([AdminCategory? c]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _CategoryDialog(service: widget.service, category: c));
    if (saved == true) {
      await _load();
      if (mounted) adminSnack(context, c == null ? 'Category added.' : 'Category saved.');
    }
  }

  Future<void> _delete(AdminCategory c) async {
    if (c.productCount > 0) return adminSnack(context, '${c.name} still has ${c.productCount} products. Move or hide them first.');
    final ok = await showConfirmDialog(context,
        icon: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 30),
        title: 'Delete ${c.name}?',
        message: 'It has no products, so nothing else changes.',
        confirmLabel: 'Delete',
        confirmKey: const Key('admin_category_delete_confirm'));
    if (ok != true) return;
    try {
      await widget.service.deleteCategory(c.id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          const AdminTitle('Categories', back: true),
          if (_error != null && items == null)
            AdminEmpty(icon: Icons.cloud_off_rounded, text: _error!, onRetry: _load)
          else if (items == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AdminCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final (i, c) in items.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 70, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    ListTile(
                      key: Key('admin_category_${c.id}'),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: _violet.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.category_rounded, color: _violet)),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.productCount == 0 ? 'Empty' : '${c.productCount} products'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(key: Key('admin_category_edit_${c.id}'), tooltip: 'Edit', onPressed: () => _edit(c), icon: const Icon(Icons.edit_outlined)),
                        IconButton(
                          key: Key('admin_category_delete_${c.id}'),
                          tooltip: c.productCount == 0 ? 'Delete' : 'Has products',
                          onPressed: () => _delete(c),
                          icon: Icon(Icons.delete_outline_rounded, color: c.productCount == 0 ? AppTheme.danger : scheme.outlineVariant),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
        ]),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: PillButton(key: const Key('admin_category_new'), label: 'New category', leadingIcon: Icons.add_rounded, onPressed: () => _edit()),
      ),
    );
  }
}

/// New / Edit category. Owns its text fields so they live until the dialog has gone.
class _CategoryDialog extends StatefulWidget {
  final AdminService service;
  final AdminCategory? category;

  const _CategoryDialog({required this.service, this.category});

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late final _description = TextEditingController(text: widget.category?.description ?? '');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final d = _description.text.trim();
      await widget.service.saveCategory(id: widget.category?.id, name: _name.text.trim(), description: d.isEmpty ? null : d);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errors?['name']?.toString() ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(widget.category == null ? 'New category' : 'Edit category'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const Key('admin_category_name'), controller: _name, inputFormatters: [LengthLimitingTextInputFormatter(100)], autofocus: true, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Name', errorText: _error)),
          const SizedBox(height: 10),
          TextField(key: const Key('admin_category_description'), controller: _description, inputFormatters: [LengthLimitingTextInputFormatter(1000)], decoration: const InputDecoration(labelText: 'Description (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(key: const Key('admin_category_save'), onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      );
}

// ---------------------------------------------------------------------------
// Customers
// ---------------------------------------------------------------------------

class AdminCustomersScreen extends StatefulWidget {
  final AdminService service;

  const AdminCustomersScreen({super.key, required this.service});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  List<Customer>? _items;
  String? _error;
  int _filter = 0;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.service.customers();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = _items;
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final c in all ?? const <Customer>[])
        if ((_filter == 0 || (_filter == 1) == c.isActive) && (q.isEmpty || '${c.fullName} ${c.email} ${c.phone ?? ''}'.toLowerCase().contains(q))) c,
    ];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const AdminTitle('Customers', back: true),
            AdminSearch(hint: 'Name, email or phone', onChanged: (v) => setState(() => _q = v)),
            const SizedBox(height: 12),
            AdminFilters(
              keyPrefix: 'admin_customers_filter',
              items: [('All', all?.length), ('Active', all?.where((c) => c.isActive).length), ('Blocked', all?.where((c) => !c.isActive).length)],
              selected: _filter,
              onSelected: (i) => setState(() => _filter = i),
            ),
            const SizedBox(height: 12),
            if (_error != null && all == null)
              AdminEmpty(icon: Icons.cloud_off_rounded, text: _error!, onRetry: _load)
            else if (all == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (shown.isEmpty)
              const AdminEmpty(icon: Icons.people_rounded, text: 'No customers here.')
            else
              for (final c in shown)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: AdminCard(
                    inkKey: Key('admin_customer_${c.id}'),
                    onTap: () async {
                      final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AdminCustomerScreen(service: widget.service, customer: c)));
                      if (changed == true) _load();
                    },
                    child: Row(children: [
                      CircleAvatar(radius: 24, backgroundColor: (c.isActive ? scheme.primary : AppTheme.danger).withValues(alpha: 0.15), child: Text(c.initials, style: TextStyle(color: c.isActive ? scheme.primary : AppTheme.danger, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(c.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            if (!c.isActive) ...[const SizedBox(width: 6), const AdminChip('Blocked', AppTheme.danger)],
                          ]),
                          Text(c.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                          const SizedBox(height: 3),
                          Text('${c.orderCount} orders · ${formatPrice(c.totalSpent)} spent', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                    ]),
                  ),
                ),
          ]),
        ),
      ),
    );
  }
}

/// One customer: contact, spending, addresses, orders, and Block / Unblock.
class AdminCustomerScreen extends StatefulWidget {
  final AdminService service;
  final Customer customer;

  const AdminCustomerScreen({super.key, required this.service, required this.customer});

  @override
  State<AdminCustomerScreen> createState() => _AdminCustomerScreenState();
}

class _AdminCustomerScreenState extends State<AdminCustomerScreen> {
  late Customer _c = widget.customer;
  bool _busy = false, _changed = false;

  @override
  void initState() {
    super.initState();
    widget.service.customer(widget.customer.id).then((c) {
      if (mounted) setState(() => _c = c);
    }, onError: (_) {});
  }

  Future<void> _toggle() async {
    final block = _c.isActive;
    if (block) {
      final ok = await showConfirmDialog(context,
          icon: const Icon(Icons.block_rounded, color: AppTheme.danger, size: 30),
          title: 'Block ${_c.fullName}?',
          message: 'They are signed out at once and cannot log in until you unblock them.',
          confirmLabel: 'Block',
          confirmKey: const Key('admin_block_confirm'));
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final c = await widget.service.setCustomerActive(_c.id, !block);
      if (!mounted) return;
      setState(() {
        _c = Customer(id: c.id, fullName: c.fullName, email: c.email, phone: c.phone, isActive: c.isActive, orderCount: c.orderCount, totalSpent: c.totalSpent, createdAt: c.createdAt, addresses: _c.addresses, orders: _c.orders);
        _changed = true;
      });
      adminSnack(context, block ? '${_c.fullName} is blocked.' : '${_c.fullName} can log in again.');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final joined = _c.createdAt == null ? '' : 'Joined ${DateFormat('d MMM yyyy').format(_c.createdAt!.toLocal())}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const AdminTitle('Customer', back: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AdminCard(
                  child: Column(children: [
                    CircleAvatar(radius: 34, backgroundColor: scheme.primary.withValues(alpha: 0.14), child: Text(_c.initials, style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 22))),
                    const SizedBox(height: 10),
                    Text(_c.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                    Text(_c.email, style: TextStyle(color: scheme.onSurfaceVariant)),
                    if (_c.phone != null) Text(_c.phone!, style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      AdminChip(_c.isActive ? 'Active' : 'Blocked', _c.isActive ? AppTheme.success : AppTheme.danger),
                      if (joined.isNotEmpty) AdminChip(joined, scheme.onSurfaceVariant),
                    ]),
                    const Divider(height: 24),
                    Row(children: [
                      Expanded(child: Column(children: [Text('${_c.orderCount}', key: const Key('admin_customer_orders'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('orders', style: TextStyle(color: scheme.onSurfaceVariant))])),
                      Expanded(child: Column(children: [Text(formatPrice(_c.totalSpent), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('spent', style: TextStyle(color: scheme.onSurfaceVariant))])),
                    ]),
                  ]),
                ),
                if (_c.addresses.isNotEmpty) ...[
                  const AdminLabel('ADDRESSES'),
                  AdminCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final a in _c.addresses)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('${a.label} · ${a.recipientName}, ${a.oneLine}', style: const TextStyle(height: 1.35)),
                        ),
                    ]),
                  ),
                ],
                if (_c.orders.isNotEmpty) ...[
                  const AdminLabel('ORDERS'),
                  AdminCard(
                    child: Column(children: [
                      for (final o in _c.orders)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Expanded(child: Text(o.number, style: const TextStyle(fontWeight: FontWeight.w600))),
                            AdminChip(orderStatusLook(o.status).$1, orderStatusLook(o.status).$2),
                            const SizedBox(width: 10),
                            Text(formatPrice(o.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                        ),
                    ]),
                  ),
                ],
              ]),
            ),
          ]),
        ),
        // Only the owner can block; staff just look
        bottomNavigationBar: !(context.watch<AuthProvider>().user?.isAdmin ?? false) ? null : Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
          child: _c.isActive
              ? PillButton.danger(key: const Key('admin_customer_block'), label: 'Block customer', leadingIcon: Icons.block_rounded, loading: _busy, onPressed: _toggle)
              : PillButton(key: const Key('admin_customer_unblock'), label: 'Unblock customer', leadingIcon: Icons.check_circle_rounded, loading: _busy, onPressed: _toggle),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

class AdminMessagesScreen extends StatefulWidget {
  final AdminService service;

  const AdminMessagesScreen({super.key, required this.service});

  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  List<AdminMessage>? _items;
  String? _error;
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.service.messages();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _reply(AdminMessage m) async {
    final text = await showReplySheet(context, question: m.message);
    if (text == null || !mounted) return;
    try {
      await widget.service.reply(m.id, text);
      if (!mounted) return;
      adminSnack(context, 'Reply sent to ${m.customerName}.');
      await _load();
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    }
  }

  static String _topic(String t) => switch (t) { 'order' => 'An order', 'payment' => 'Payment', 'product' => 'A product', _ => 'Something else' };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = _items;
    final shown = [for (final m in all ?? const <AdminMessage>[]) if (m.open == (_filter == 0)) m];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const AdminTitle('Messages', back: true),
            AdminFilters(
              keyPrefix: 'admin_messages_filter',
              items: [('Open', all?.where((m) => m.open).length), ('Answered', all?.where((m) => !m.open).length)],
              selected: _filter,
              onSelected: (i) => setState(() => _filter = i),
            ),
            const SizedBox(height: 12),
            if (_error != null && all == null)
              AdminEmpty(icon: Icons.cloud_off_rounded, text: _error!, onRetry: _load)
            else if (all == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (shown.isEmpty)
              AdminEmpty(icon: Icons.forum_rounded, text: _filter == 0 ? 'No questions waiting. Nice!' : 'No answered messages yet.')
            else
              for (final m in shown)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: AdminCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        CircleAvatar(radius: 18, backgroundColor: scheme.primary.withValues(alpha: 0.14), child: Text(m.customerName.isEmpty ? '?' : m.customerName[0].toUpperCase(), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(m.customerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Text(timeago.format(m.createdAt.toLocal()), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: [AdminChip(_topic(m.topic), _cyan), if (m.orderNumber != null) AdminChip(m.orderNumber!, scheme.onSurfaceVariant)]),
                      const SizedBox(height: 8),
                      Text(m.message, style: const TextStyle(height: 1.4)),
                      const SizedBox(height: 10),
                      if (m.open)
                        FilledButton.icon(
                          key: Key('admin_message_reply_${m.id}'),
                          onPressed: () => _reply(m),
                          icon: const Icon(Icons.reply_rounded, size: 18),
                          label: const Text('Reply'),
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 38), shape: const StadiumBorder(), textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.reply_rounded, color: AppTheme.success, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(m.reply ?? '', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600, fontSize: 13))),
                          ]),
                        ),
                    ]),
                  ),
                ),
          ]),
        ),
      ),
    );
  }
}
