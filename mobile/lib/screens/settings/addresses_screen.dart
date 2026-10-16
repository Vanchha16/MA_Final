import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/order.dart';
import '../../services/checkout_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';
import '../checkout/address_form_screen.dart';

/// My addresses: the saved delivery addresses (default first). Tap one to
/// edit or delete it; Add new address at the bottom.
class AddressesScreen extends StatefulWidget {
  final CheckoutService? service;

  const AddressesScreen({super.key, this.service});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late final CheckoutService _service = widget.service ?? CheckoutService();
  List<Address>? _addresses;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.addresses();
      // Default first, like the checkout
      list.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
      if (mounted) {
        setState(() {
          _addresses = list;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit([Address? address]) async {
    final changed = await Navigator.of(context).push<Object>(MaterialPageRoute(builder: (_) => AddressFormScreen(initial: address, service: _service)));
    if (changed != null && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final addresses = _addresses;
    Widget body;
    if (_error != null && addresses == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
          PillButton(key: const Key('addresses_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: _load),
        ]),
      );
    } else if (addresses == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (addresses.isEmpty) {
      body = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(key: const Key('addresses_empty'), children: [
            const IconCircle(icon: Icons.location_on_rounded),
            const SizedBox(height: 18),
            Text(l.noAddresses, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(l.noAddressesSub, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ]),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: addresses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final a = addresses[i];
            final icon = switch (a.label) { 'Home' => Icons.home_rounded, 'Work' => Icons.work_rounded, _ => Icons.place_rounded };
            return Material(
              color: dark ? scheme.surfaceContainer : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: a.isDefault ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('address_row_${a.id}'),
                onTap: () => _edit(a),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(icon, color: scheme.primary, size: 21),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text('${a.label} · ${a.recipientName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                          if (a.isDefault) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
                              child: Text(l.defaultAddress, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text('${a.phone}\n${a.oneLine}', style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                    Icon(Icons.edit_outlined, color: scheme.onSurfaceVariant, size: 20),
                  ]),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Flexible(
                child: Text(l.myAddresses,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: PillButton(key: const Key('addresses_add'), label: l.addAddress, leadingIcon: Icons.add_location_alt_rounded, onPressed: () => _edit()),
      ),
    );
  }
}
