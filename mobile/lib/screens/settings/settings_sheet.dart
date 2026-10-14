import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

/// Quick settings from the Profile gear: appearance (dark mode) and language.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = context.watch<ThemeProvider>();
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Appearance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                key: const Key('theme_mode'),
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                ],
                selected: {theme.mode},
                onSelectionChanged: (s) => theme.setMode(s.first),
              ),
              const SizedBox(height: 20),
              Text('Language', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.translate_rounded),
                title: const Text('English'),
                trailing: Chip(label: Text('Khmer soon', style: TextStyle(color: scheme.onSurfaceVariant))),
              ),
            ],
          ),
        ),
      );
    },
  );
}
