import 'package:flutter/material.dart';

import '../../widgets/circle_back_button.dart';

/// Privacy policy or Terms of use: a title and a few short, numbered sections.
class LegalScreen extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;

  const LegalScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Flexible(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 18),
            for (final (i, (heading, body)) in sections.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  key: Key('legal_$i'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: dark ? scheme.surfaceContainer : Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.13), shape: BoxShape.circle),
                      child: Text('${i + 1}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(heading, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                        const SizedBox(height: 4),
                        Text(body, style: TextStyle(height: 1.5, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
