import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/order.dart';
import '../../services/receipt_export.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/order_receipt.dart';

/// Saves or shares the receipt as an image and says how it went.
Future<void> exportReceipt(BuildContext context, ReceiptExport export, Order order, {DateTime? paidAt, required bool share}) async {
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  try {
    final png = await export.image(context, order, paidAt: paidAt);
    if (share) {
      await export.share(png, order);
    } else {
      await export.save(png, order);
      say('Receipt saved as ${ReceiptExport.fileName(order)}.png');
    }
  } catch (_) {
    say(share ? 'Could not share the receipt. Please try again.' : 'Could not save the receipt. Please try again.');
  }
}

/// A sky-tinted pill for the receipt's Save / Share / View order actions.
class ReceiptAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const ReceiptAction({super.key, required this.label, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
        backgroundColor: dark ? scheme.surfaceContainerHighest : AppTheme.skyTint,
        foregroundColor: scheme.primary,
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 14.5),
      ),
    );
  }
}

/// Receipt (from Order details): the paid order's receipt with Save and Share.
class ReceiptScreen extends StatelessWidget {
  final Order order;
  final ReceiptExport export;

  const ReceiptScreen({super.key, required this.order, this.export = const ReceiptExport()});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Text('Receipt', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 20),
            Center(child: OrderReceipt(key: const Key('receipt_paper'), order: order)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: ReceiptAction(
                  key: const Key('receipt_save'),
                  label: 'Save receipt',
                  icon: Icons.download_rounded,
                  onPressed: () => exportReceipt(context, export, order, share: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ReceiptAction(
                  key: const Key('receipt_share'),
                  label: 'Share',
                  icon: Icons.share_rounded,
                  onPressed: () => exportReceipt(context, export, order, share: true),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
