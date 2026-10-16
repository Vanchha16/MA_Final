import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/circle_back_button.dart';
import 'contact_screen.dart';

/// Help & contact: a card that opens Contact us, then common questions.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? scheme.surfaceContainer : Colors.white;

    final faqs = [(l.faq1q, l.faq1a), (l.faq2q, l.faq2a), (l.faq3q, l.faq3a), (l.faq4q, l.faq4a)];
    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
          child: Text(text, style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant)),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Flexible(
                child: Text(l.helpTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 18),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: const Key('help_contact'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: const Icon(Icons.support_agent_rounded, color: AppTheme.success, size: 22),
                ),
                title: Text(l.contactTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(l.helpContactSub),
                trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactScreen())),
              ),
            ),
            label(l.faq),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final (i, (q, a)) in faqs.indexed)
                  ExpansionTile(
                    key: Key('faq_$i'),
                    shape: const Border(),
                    leading: Icon(Icons.help_outline_rounded, color: scheme.primary),
                    title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    expandedAlignment: Alignment.centerLeft,
                    children: [Text(a, style: TextStyle(height: 1.45, color: scheme.onSurfaceVariant))],
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
