import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class MenuItemData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Small coral count badge, e.g. unread notifications. Hidden when null or 0.
  final int? badge;

  const MenuItemData({required this.icon, required this.label, required this.onTap, this.badge});
}

/// White rounded card with list rows: tinted icon tile, label, badge, chevron
/// (Figma: Menu Row inside a menu card).
class MenuCard extends StatelessWidget {
  final List<MenuItemData> items;

  const MenuCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 66, color: scheme.outlineVariant.withValues(alpha: 0.5)),
              _MenuRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final MenuItemData item;

  const _MenuRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: item.onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF0F1E33) : AppTheme.skyTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(item.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
              if ((item.badge ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.coral, borderRadius: BorderRadius.circular(10)),
                  child: Text('${item.badge}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
