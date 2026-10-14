import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/icon_title.dart';

/// Placeholder - will become the real Home (banners, categories, products).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = user?.fullName.split(' ').first;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IconTitle(
                firstName == null ? 'Hi there!' : 'Hi, $firstName!',
                icon: Icons.waving_hand_rounded,
                iconColor: AppTheme.amber,
              ),
              const SizedBox(height: 4),
              Text('What are you collecting today?', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16)),
              const Spacer(),
              const Center(child: IconCircle(icon: Icons.storefront_rounded)),
              const SizedBox(height: 16),
              const Text('The shop is being stocked', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Figures and trading cards arrive in the next update.',
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
