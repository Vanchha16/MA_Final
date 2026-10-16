import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/checkout_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/pill_text_field.dart';

/// Add or edit a delivery address. Pops with the saved [Address], or with
/// true after the address was deleted.
class AddressFormScreen extends StatefulWidget {
  final Address? initial;
  final CheckoutService? service;

  const AddressFormScreen({super.key, this.initial, this.service});

  static const provinces = [
    'Phnom Penh',
    'Kandal',
    'Siem Reap',
    'Battambang',
    'Preah Sihanouk',
    'Kampot',
    'Kep',
    'Takeo',
    'Kampong Cham',
    'Kampong Speu',
    'Kampong Chhnang',
    'Kampong Thom',
    'Prey Veng',
    'Svay Rieng',
    'Tbong Khmum',
    'Pursat',
    'Banteay Meanchey',
    'Pailin',
    'Oddar Meanchey',
    'Preah Vihear',
    'Stung Treng',
    'Kratie',
    'Mondulkiri',
    'Ratanakiri',
    'Koh Kong',
  ];

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  static final _phoneRe = RegExp(r'^(\+855|0)\d{8,9}$');
  late final CheckoutService _service = widget.service ?? CheckoutService();
  final _formKey = GlobalKey<FormState>();
  late final _user = context.read<AuthProvider>().user;
  late final _name = TextEditingController(
    text: widget.initial?.recipientName ?? _user?.fullName ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.initial?.phone ?? _user?.phone ?? '',
  );
  late final _street = TextEditingController(
    text: widget.initial?.street ?? '',
  );
  late final _city = TextEditingController(text: widget.initial?.city ?? '');
  late String _label = widget.initial?.label ?? 'Home';
  late String _province = widget.initial?.province ?? 'Phnom Penh';
  late bool _isDefault = widget.initial?.isDefault ?? false;
  bool _saving = false;
  String? _error;
  Map<String, dynamic> _fieldErrors = {};

  bool get _editing => widget.initial?.id != null;

  @override
  void dispose() {
    for (final c in [_name, _phone, _street, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final saved = await _service.saveAddress(
        Address(
          id: widget.initial?.id,
          label: _label,
          recipientName: _name.text.trim(),
          phone: _phone.text.replaceAll(RegExp(r'[\s\-().]'), ''),
          street: _street.text.trim(),
          city: _city.text.trim(),
          province: _province,
          isDefault: _isDefault,
        ),
      );
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.errors ?? {};
        _error = _fieldErrors.isNotEmpty
            ? 'Please fix the highlighted fields'
            : e.message;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      icon: const Icon(
        Icons.wrong_location_outlined,
        size: 30,
        color: Color(0xFFDC2626),
      ),
      title: 'Delete this address?',
      message: '${widget.initial!.label} · ${widget.initial!.oneLine}',
      confirmLabel: 'Delete',
      confirmKey: const Key('address_delete_confirm'),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.deleteAddress(widget.initial!.id!);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  String? _required(String? v, String what) =>
      (v == null || v.trim().isEmpty) ? '$what is required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Row(
                children: [
                  const CircleBackButton(),
                  const SizedBox(width: 14),
                  Text(
                    _editing ? 'Edit address' : 'New address',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, icon) in [
                    ('Home', Icons.home_rounded),
                    ('Work', Icons.work_rounded),
                    ('Other', Icons.place_rounded),
                  ])
                    ChoiceChip(
                      key: Key('address_label_$label'),
                      avatar: Icon(icon, size: 18),
                      label: Text(label),
                      selected: _label == label,
                      onSelected: (_) => setState(() => _label = label),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              PillTextField(
                fieldKey: const Key('address_name'),
                maxLength: 100,
                controller: _name,
                label: 'Recipient name',
                icon: Icons.person_rounded,
                errorText: _fieldErrors['recipient_name'],
                textInputAction: TextInputAction.next,
                validator: (v) => _required(v, 'Name'),
              ),
              const SizedBox(height: 14),
              PillTextField(
                fieldKey: const Key('address_phone'),
                maxLength: 30,
                controller: _phone,
                label: 'Phone number',
                hint: '012 345 678',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                errorText: _fieldErrors['phone'],
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final missing = _required(v, 'Phone number');
                  if (missing != null) return missing;
                  return _phoneRe.hasMatch(
                        v!.replaceAll(RegExp(r'[\s\-().]'), ''),
                      )
                      ? null
                      : 'Enter a Cambodian number, e.g. 012 345 678';
                },
              ),
              const SizedBox(height: 14),
              PillTextField(
                fieldKey: const Key('address_street'),
                maxLength: 255,
                controller: _street,
                label: 'House no. and street',
                hint: '#24 St. 271',
                icon: Icons.signpost_rounded,
                errorText: _fieldErrors['street'],
                textInputAction: TextInputAction.next,
                validator: (v) => _required(v, 'Street address'),
              ),
              const SizedBox(height: 14),
              PillTextField(
                fieldKey: const Key('address_city'),
                maxLength: 100,
                controller: _city,
                label: 'Sangkat / Khan',
                hint: 'Tuol Tumpung 2, Chamkar Mon',
                icon: Icons.location_city_rounded,
                errorText: _fieldErrors['city'],
                validator: (v) => _required(v, 'District'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: const Key('address_province'),
                initialValue: AddressFormScreen.provinces.contains(_province)
                    ? _province
                    : 'Phnom Penh',
                decoration: InputDecoration(
                  labelText: 'Province / city',
                  prefixIcon: const Icon(Icons.map_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                items: [
                  for (final p in AddressFormScreen.provinces)
                    DropdownMenuItem(value: p, child: Text(p)),
                ],
                onChanged: (v) => setState(() => _province = v ?? 'Phnom Penh'),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                key: const Key('address_default'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Use as my default address'),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
              ),
              const SizedBox(height: 12),
              PillButton(
                key: const Key('address_save'),
                label: 'Save address',
                leadingIcon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
              if (_editing) ...[
                const SizedBox(height: 12),
                PillButton.danger(
                  key: const Key('address_delete'),
                  label: 'Delete address',
                  leadingIcon: Icons.delete_outline_rounded,
                  onPressed: _delete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
