import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/l10n.dart';
import '../../widgets/circle_back_button.dart';

/// About: the logo, what the shop sells, the app version and the image credit.
class AboutScreen extends StatelessWidget {
  final String version;

  const AboutScreen({super.key, this.version = ''});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget logo = Image.asset('assets/logo_centered.png', width: 120, height: 120, semanticLabel: 'Anime World Shop logo');
    if (!reduceMotion) logo = logo.animate().scaleXY(begin: 0.6, duration: 500.ms, curve: Curves.easeOutBack).fadeIn();

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Text(l.aboutTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(32, 24, 32, 24), children: [
              Center(child: logo),
              const SizedBox(height: 16),
              Text('Anime World Shop', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              if (version.isNotEmpty)
                Text(l.version(version), key: const Key('about_version'), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Text(l.aboutTagline, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.45)),
              const SizedBox(height: 24),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Text(l.aboutMadeBy, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45)),
              const SizedBox(height: 12),
              Text(l.aboutCredit, key: const Key('about_credit'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.45)),
            ]),
          ),
        ]),
      ),
    );
  }
}
