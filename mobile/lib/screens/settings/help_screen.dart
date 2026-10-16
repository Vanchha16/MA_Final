import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../widgets/circle_back_button.dart';

/// Help & contact: how to reach the shop (tap to copy) and common questions.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const phone = '+855 12 345 678';
  static const telegram = '@animeworldshop_kh';
  static const email = 'hello@animeworld.shop';
  static const address = '#88 St. 315, Boeung Kak 2, Toul Kork, Phnom Penh';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? scheme.surfaceContainer : Colors.white;

    void copy(String value) {
      Clipboard.setData(ClipboardData(text: value));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.copied(value)), behavior: SnackBarBehavior.floating));
    }

    Widget contact(String key, IconData icon, Color color, String title, String value) => ListTile(
          key: Key('help_$key'),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(value),
          trailing: Tooltip(message: l.tapToCopy, child: Icon(Icons.copy_rounded, size: 18, color: scheme.onSurfaceVariant)),
          onTap: () => copy(value),
        );

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
            label(l.contactUs),
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                contact('phone', Icons.call_rounded, AppTheme.success, l.callUs, phone),
                contact('telegram', Icons.send_rounded, AppTheme.primaryDark, l.telegram, telegram),
                contact('email', Icons.mail_rounded, AppTheme.coral, l.emailUs, email),
                contact('shop', Icons.storefront_rounded, const Color(0xFF7C3AED), l.visitShop, '$address\n${l.openHours}'),
              ]),
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
