import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/checkout_service.dart';
import '../../widgets/pill_button.dart';
import 'address_form_screen.dart';

/// "Deliver to" picker: saved addresses with a radio, edit, and Add new.
/// Returns the chosen (or newly added) address, or null when dismissed.
Future<Address?> showAddressPicker(
  BuildContext context, {
  required List<Address> addresses,
  int? selectedId,
  required CheckoutService service,
}) {
  return showModalBottomSheet<Address>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddressPicker(
      addresses: addresses,
      selectedId: selectedId,
      service: service,
    ),
  );
}

class _AddressPicker extends StatefulWidget {
  final List<Address> addresses;
  final int? selectedId;
  final CheckoutService service;

  const _AddressPicker({
    required this.addresses,
    required this.selectedId,
    required this.service,
  });

  @override
  State<_AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<_AddressPicker> {
  late List<Address> _addresses = widget.addresses;

  Future<void> _edit([Address? address]) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) =>
            AddressFormScreen(initial: address, service: widget.service),
      ),
    );
    if (!mounted || result == null) return;
    if (result is Address && address == null) {
      Navigator.of(context).pop(result); // a new address is used right away
      return;
    }
    try {
      final fresh = await widget.service.addresses();
      if (mounted) setState(() => _addresses = fresh);
    } catch (_) {
      // The checkout reloads the list when the sheet closes
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Deliver to',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final a in _addresses)
                  ListTile(
                    key: Key('address_${a.id}'),
                    contentPadding: const EdgeInsets.only(left: 4),
                    leading: Icon(
                      a.id == widget.selectedId
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: a.id == widget.selectedId
                          ? scheme.primary
                          : scheme.outline,
                    ),
                    title: Text(
                      '${a.label} · ${a.recipientName}${a.isDefault ? '  (default)' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${a.phone}\n${a.oneLine}'),
                    isThreeLine: true,
                    trailing: IconButton(
                      key: Key('address_edit_${a.id}'),
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(a),
                    ),
                    onTap: () => Navigator.of(context).pop(a),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PillButton(
            key: const Key('address_add'),
            label: 'Add new address',
            leadingIcon: Icons.add_location_alt_rounded,
            color: scheme.brightness == Brightness.dark
                ? scheme.surfaceContainerHighest
                : const Color(0xFFE0F2FE),
            foregroundColor: scheme.primary,
            onPressed: () => _edit(),
          ),
        ],
      ),
    );
  }
}
