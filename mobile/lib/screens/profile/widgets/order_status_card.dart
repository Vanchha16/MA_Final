import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/profile_summary.dart';

/// "My Orders" card with To Pay / To Ship / To Receive / To Review shortcuts
/// and coral count badges (Figma: My Orders).
class OrderStatusCard extends StatelessWidget {
  final ProfileSummary? summary;
  final VoidCallback onViewAll;
  final ValueChanged<String> onStatus;

  const OrderStatusCard({super.key, required this.summary, required this.onViewAll, required this.onStatus});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      ('To Pay', Icons.payments_rounded, summary?.toPay ?? 0),
      ('To Ship', Icons.inventory_2_rounded, summary?.toShip ?? 0),
      ('To Receive', Icons.local_shipping_rounded, summary?.toReceive ?? 0),
      ('To Review', Icons.rate_review_rounded, summary?.toReview ?? 0),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('My Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('View all'), Icon(Icons.chevron_right_rounded, size: 18)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (label, icon, count) in items)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onStatus(label),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: dark ? const Color(0xFF0F1E33) : AppTheme.skyTint,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(icon, size: 24, color: scheme.primary),
                              ),
                              if (count > 0)
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 20),
                                    height: 20,
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppTheme.coral,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: dark ? scheme.surfaceContainerHigh : Colors.white, width: 2),
                                    ),
                                    child: Text('$count',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(label,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
