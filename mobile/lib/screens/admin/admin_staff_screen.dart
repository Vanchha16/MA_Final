import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/pill_button.dart';
import 'admin_widgets.dart';

const _violet = Color(0xFF7C3AED);

AdminChip _roleChip(StaffMember s) => s.isAdmin ? const AdminChip('Admin', _violet) : const AdminChip('Staff', AppTheme.accent);

String _lastLogin(StaffMember s) => s.lastLoginAt == null ? 'Never signed in' : 'Last login ${timeago.format(s.lastLoginAt!.toLocal())}';

/// Staff and admin accounts (picked layout A: list, then a page per person). Owner only.
class AdminStaffScreen extends StatefulWidget {
  final AdminService service;

  const AdminStaffScreen({super.key, required this.service});

  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  List<StaffMember>? _items;
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
      final items = await widget.service.staff();
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

  Future<void> _open([StaffMember? s]) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AdminStaffMemberScreen(service: widget.service, member: s)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = context.watch<AuthProvider>().user?.id;
    final all = _items;
    final q = _q.trim().toLowerCase();
    bool Function(StaffMember) test = switch (_filter) { 1 => (s) => s.isAdmin, 2 => (s) => !s.isAdmin, _ => (_) => true };
    final shown = [
      for (final s in all ?? const <StaffMember>[])
        if (test(s) && (q.isEmpty || '${s.fullName} ${s.email} ${s.phone ?? ''}'.toLowerCase().contains(q))) s,
    ];
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const AdminTitle('Staff', back: true),
            AdminSearch(hint: 'Name, email or phone', onChanged: (v) => setState(() => _q = v)),
            const SizedBox(height: 12),
            AdminFilters(
              keyPrefix: 'admin_staff_filter',
              items: [('All', all?.length), ('Admins', all?.where((s) => s.isAdmin).length), ('Staff', all?.where((s) => !s.isAdmin).length)],
              selected: _filter,
              onSelected: (i) => setState(() => _filter = i),
            ),
            const SizedBox(height: 12),
            if (_error != null && all == null)
              AdminEmpty(icon: Icons.cloud_off_rounded, text: _error!, onRetry: _load)
            else if (all == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (shown.isEmpty)
              const AdminEmpty(icon: Icons.badge_rounded, text: 'Nobody here.')
            else
              for (final s in shown)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: AdminCard(
                    inkKey: Key('admin_staff_${s.id}'),
                    onTap: () => _open(s),
                    child: Row(children: [
                      CircleAvatar(radius: 24, backgroundColor: (s.isActive ? scheme.primary : AppTheme.danger).withValues(alpha: 0.15), child: Text(s.initials, style: TextStyle(color: s.isActive ? scheme.primary : AppTheme.danger, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(s.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                            const SizedBox(width: 6),
                            _roleChip(s),
                            if (!s.isActive) ...[const SizedBox(width: 4), const AdminChip('Disabled', AppTheme.danger)],
                          ]),
                          Text(s.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                          const SizedBox(height: 3),
                          Text(s.id == me ? 'You' : _lastLogin(s), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                    ]),
                  ),
                ),
          ]),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: PillButton(key: const Key('admin_staff_new'), label: 'Add staff', leadingIcon: Icons.person_add_rounded, onPressed: () => _open()),
      ),
    );
  }
}

/// Add a staff account ([member] null), or change one: name, phone, role, a new
/// password, Disable / Enable. Pops true when something was saved.
class AdminStaffMemberScreen extends StatefulWidget {
  final AdminService service;
  final StaffMember? member;

  const AdminStaffMemberScreen({super.key, required this.service, this.member});

  @override
  State<AdminStaffMemberScreen> createState() => _AdminStaffMemberScreenState();
}

class _AdminStaffMemberScreenState extends State<AdminStaffMemberScreen> {
  late StaffMember? _m = widget.member;
  late final _name = TextEditingController(text: widget.member?.fullName ?? '');
  late final _email = TextEditingController();
  late final _phone = TextEditingController(text: widget.member?.phone ?? '');
  final _password = TextEditingController();
  late String _role = widget.member?.role ?? 'staff';
  bool _resetting = false, _busy = false, _changed = false;
  Map<String, dynamic> _errors = {};

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isMe => _m != null && _m!.id == context.read<AuthProvider>().user?.id;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = {};
    });
    final phone = _phone.text.trim();
    try {
      if (_m == null) {
        await widget.service.addStaff(fullName: _name.text.trim(), email: _email.text.trim(), password: _password.text, phone: phone.isEmpty ? null : phone, role: _role);
        if (!mounted) return;
        adminSnack(context, '${_name.text.trim()} can sign in now.');
      } else {
        await widget.service.updateStaff(_m!.id, {
          'full_name': _name.text.trim(),
          'phone': phone.isEmpty ? null : phone,
          if (!_isMe) 'role': _role,
          if (_resetting) 'password': _password.text,
        });
        if (!mounted) return;
        adminSnack(context, _resetting ? 'Saved. Give ${_name.text.trim()} the new password.' : '${_name.text.trim()} saved.');
      }
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors ?? {});
      if (e.errors == null) adminSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setActive(bool active) async {
    if (!active) {
      final ok = await showConfirmDialog(context,
          icon: const Icon(Icons.block_rounded, color: AppTheme.danger, size: 30),
          title: 'Disable ${_m!.fullName}?',
          message: 'They are signed out at once and cannot sign in until you enable them again.',
          confirmLabel: 'Disable',
          confirmKey: const Key('admin_staff_disable_confirm'));
      if (ok != true) return;
    }
    setState(() => _busy = true);
    try {
      final m = await widget.service.updateStaff(_m!.id, {'is_active': active});
      if (!mounted) return;
      setState(() {
        _m = m;
        _changed = true;
      });
      adminSnack(context, active ? '${m.fullName} can sign in again.' : '${m.fullName} is disabled.');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _deco(String label, String key, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: _errors[key]?.toString(),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  Widget _roleButton(String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    final on = _role == value;
    return Expanded(
      child: Material(
        color: on ? scheme.primary : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          key: Key('admin_staff_role_$value'),
          customBorder: const StadiumBorder(),
          onTap: _isMe ? null : () => setState(() => _role = value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: on ? scheme.onPrimary : scheme.onSurfaceVariant)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = _m;
    final roleNote = _isMe
        ? "You can't change your own role."
        : _role == 'admin'
            ? 'Everything, including staff and promo codes.'
            : 'Orders, products, categories, messages and reviews. Customers view only.';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            AdminTitle(m == null ? 'Add staff' : 'Staff member', back: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (m != null)
                  AdminCard(
                    child: Column(children: [
                      CircleAvatar(radius: 34, backgroundColor: (m.isActive ? scheme.primary : AppTheme.danger).withValues(alpha: 0.14), child: Text(m.initials, style: TextStyle(color: m.isActive ? scheme.primary : AppTheme.danger, fontWeight: FontWeight.bold, fontSize: 22))),
                      const SizedBox(height: 10),
                      Text(m.fullName, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      Text(m.email, style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        _roleChip(m),
                        AdminChip(m.isActive ? 'Active' : 'Disabled', m.isActive ? AppTheme.success : AppTheme.danger, key: const Key('admin_staff_status')),
                      ]),
                      const SizedBox(height: 6),
                      Text(_isMe ? 'This is you' : _lastLogin(m), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                    ]),
                  ),
                const AdminLabel('DETAILS'),
                TextField(key: const Key('admin_staff_name'), controller: _name, inputFormatters: [LengthLimitingTextInputFormatter(100)], textCapitalization: TextCapitalization.words, decoration: _deco('Name', 'full_name')),
                if (m == null) ...[
                  const SizedBox(height: 10),
                  TextField(key: const Key('admin_staff_email'), controller: _email, inputFormatters: [LengthLimitingTextInputFormatter(150)], keyboardType: TextInputType.emailAddress, decoration: _deco('Email', 'email')),
                ],
                const SizedBox(height: 10),
                TextField(key: const Key('admin_staff_phone'), controller: _phone, inputFormatters: [LengthLimitingTextInputFormatter(30)], keyboardType: TextInputType.phone, decoration: _deco('Phone (optional)', 'phone', hint: '012 345 678')),
                const AdminLabel('ROLE'),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: adminCardColor(context), borderRadius: BorderRadius.circular(30), boxShadow: adminShadow(context)),
                  child: Row(children: [_roleButton('staff', 'Staff'), _roleButton('admin', 'Admin')]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                  child: Text(_errors['role']?.toString() ?? roleNote, style: TextStyle(fontSize: 12.5, color: _errors['role'] != null ? AppTheme.danger : scheme.onSurfaceVariant)),
                ),
                const AdminLabel('PASSWORD'),
                if (m == null || _resetting) ...[
                  TextField(key: const Key('admin_staff_password'), controller: _password, inputFormatters: [LengthLimitingTextInputFormatter(72)], autocorrect: false, enableSuggestions: false,
                      decoration: _deco(m == null ? 'Password' : 'New password', 'password', hint: 'At least 8 characters')),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                    child: Text('Give them this password. They can change it in Profile.', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ),
                ] else
                  OutlinedButton.icon(
                    key: const Key('admin_staff_reset'),
                    onPressed: () => setState(() => _resetting = true),
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Reset password'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder(), textStyle: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
          ]),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
          child: Row(children: [
            if (m != null && !_isMe) ...[
              Expanded(
                child: m.isActive
                    ? PillButton.danger(key: const Key('admin_staff_disable'), label: 'Disable', leadingIcon: Icons.block_rounded, onPressed: _busy ? null : () => _setActive(false))
                    : PillButton(key: const Key('admin_staff_enable'), label: 'Enable', leadingIcon: Icons.check_circle_rounded, color: AppTheme.success, onPressed: _busy ? null : () => _setActive(true)),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: PillButton(key: const Key('admin_staff_save'), label: m == null ? 'Add staff' : 'Save', leadingIcon: Icons.check_rounded, loading: _busy, onPressed: _save)),
          ]),
        ),
      ),
    );
  }
}
