import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'pill_button.dart';

/// Rounded "are you sure?" pop-up (Figma: 28c Logout Confirm): an icon in a
/// soft red circle, a title, a short message, Cancel and a solid red button.
/// Returns true when the red button is tapped.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required Widget icon,
  required String title,
  required String message,
  required String confirmLabel,
  Key? confirmKey,
  Widget? extra,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Center(child: icon),
              ),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
              if (extra != null) ...[const SizedBox(height: 16), extra],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('confirm_cancel'),
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(shape: const StadiumBorder(), minimumSize: const Size(0, 48)),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton.danger(key: confirmKey, label: confirmLabel, onPressed: () => Navigator.of(context).pop(true)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
