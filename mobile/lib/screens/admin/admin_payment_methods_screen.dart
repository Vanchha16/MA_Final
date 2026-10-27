import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin.dart';
import '../../models/order.dart';
import '../../services/admin_service.dart';
import '../../widgets/payment_logo.dart';
import 'admin_widgets.dart';

/// Turn KHQR, ABA PayWay or cash on or off (picked layout A: one card of
/// switches). Turned-off methods are hidden at checkout. Owner only.
class AdminPaymentMethodsScreen extends StatefulWidget {
  final AdminService service;

  const AdminPaymentMethodsScreen({super.key, required this.service});

  @override
  State<AdminPaymentMethodsScreen> createState() => _AdminPaymentMethodsScreenState();
}

class _AdminPaymentMethodsScreenState extends State<AdminPaymentMethodsScreen> {
  List<PaymentMethodSetting>? _items;
  String? _error;
  final _saving = <PaymentMethod>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.service.paymentMethods();
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

  /// Flips the switch straight away and puts it back if the server says no
  /// (e.g. it is the last method still on).
  Future<void> _toggle(PaymentMethodSetting m, bool on) async {
    setState(() {
      _saving.add(m.method);
      _items = [for (final x in _items!) x.method == m.method ? x.copyWith(enabled: on) : x];
    });
    try {
      final items = await widget.service.setPaymentMethod(m.method, on);
      if (!mounted) return;
      setState(() => _items = items);
      adminSnack(context, on ? '${m.method.label} is back at checkout.' : '${m.method.label} is now hidden at checkout.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _items = [for (final x in _items!) x.method == m.method ? m : x]);
      adminSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving.remove(m.method));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            const AdminTitle('Payment methods', back: true),
            if (_error != null && items == null)
              AdminEmpty(icon: Icons.cloud_off_rounded, text: _error!, onRetry: _load)
            else if (items == null)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text('Choose how customers can pay at checkout.', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                  AdminCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final (i, m) in items.indexed) ...[
                        if (i > 0) Divider(height: 1, indent: 74, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                        _MethodRow(setting: m, saving: _saving.contains(m.method), onChanged: (on) => _toggle(m, on)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_rounded, size: 20, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Orders placed before a method was turned off can still be paid with it. At least one method has to stay on.',
                          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  final PaymentMethodSetting setting;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _MethodRow({required this.setting, required this.saving, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = setting.enabled;
    // Customers can pick it, but paying would fail without the bank's keys
    final noKeys = on && !setting.setUp;
    final status = !on ? 'Off · hidden at checkout' : (noKeys ? 'On · the server has no bank keys for it yet' : 'On · customers can choose it');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Opacity(opacity: on ? 1 : 0.45, child: PaymentLogo(setting.method)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(setting.method.label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: on ? scheme.onSurface : scheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(status, key: Key('admin_pay_status_${setting.method.apiValue}'), style: TextStyle(fontSize: 13, color: noKeys ? AppTheme.amber : scheme.onSurfaceVariant)),
          ]),
        ),
        Switch(key: Key('admin_pay_${setting.method.apiValue}'), value: on, onChanged: saving ? null : onChanged),
      ]),
    );
  }
}
