import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/profile_summary.dart';
import '../../../models/user.dart';
import '../../../widgets/sparkle.dart';
import '../../../widgets/user_avatar.dart';

/// Sky-to-aqua card styled like a trading card: thin inner frame, faint
/// sparkles and a logo watermark (Figma: Collector Card).
class CollectorCardShell extends StatelessWidget {
  final Widget child;

  const CollectorCardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.accent],
        ),
        boxShadow: [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.20), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -34,
            bottom: -40,
            child: Transform.rotate(
              angle: -12 * math.pi / 180,
              child: Opacity(opacity: 0.16, child: Image.asset('assets/logo_centered.png', width: 150)),
            ),
          ),
          const Positioned(right: 70, top: 16, child: Sparkle(size: 16, color: Color(0x8CFFFFFF))),
          const Positioned(right: 26, top: 64, child: Sparkle(size: 10, color: Color(0x73FFFFFF))),
          const Positioned(left: 150, top: 12, child: Sparkle(size: 8, color: Color(0x66FFFFFF))),
          // Inner "card frame" line
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

/// Signed-in header: avatar, name, email, Edit chip, tier badge, points and
/// progress to the next tier.
class CollectorCard extends StatelessWidget {
  final User user;
  final ProfileSummary? summary;
  final VoidCallback onEdit;

  const CollectorCard({super.key, required this.user, required this.summary, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final tier = summary?.tier;
    const white70 = Color(0xD9FFFFFF);

    return CollectorCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(user: user, size: 64, ring: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: white70, fontSize: 13)),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.22),
                shape: const StadiumBorder(),
                child: InkWell(
                  key: const Key('profile_edit'),
                  customBorder: const StadiumBorder(),
                  onTap: onEdit,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 14, 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 16, color: AppTheme.amber),
                    const SizedBox(width: 6),
                    Text(
                      tier == null ? 'Collector' : '${tier.name} Collector',
                      style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                summary == null ? '–' : fmt.format(summary!.points),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Text('pts', style: TextStyle(color: white70, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: tier?.progress ?? 0,
              minHeight: 6,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: 0.30),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  tier == null
                      ? 'Earn 1 point for every \$1'
                      : (tier.nextName == null
                          ? 'Top tier reached'
                          : '${fmt.format(tier.pointsToNext)} pts to ${tier.nextName}'),
                  style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              if (tier?.nextName != null)
                Text(tier!.nextName!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
