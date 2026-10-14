import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/profile_summary.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/animated_logout_icon.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/menu_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/round_icon_button.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../settings/settings_sheet.dart';
import 'edit_profile_screen.dart';
import 'widgets/collector_card.dart';
import 'widgets/order_status_card.dart';

/// Profile tab (Figma: "28 - Profile" / "28b - Profile (Guest)").
class ProfileScreen extends StatefulWidget {
  /// Injected in tests; the real API otherwise.
  final ProfileService? service;

  const ProfileScreen({super.key, this.service});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _service = widget.service ?? ProfileService();
  ProfileSummary? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (context.read<AuthProvider>().isLoggedIn) _load();
  }

  Future<void> _load() async {
    try {
      final summary = await _service.summary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature is coming in the next update')));
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditProfileScreen(service: _service)));
    _load();
  }

  Future<void> _confirmLogout() async {
    final ok = await showLogoutDialog(context);
    if (ok != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Widget _topBar({required bool signedIn}) => Row(
        children: [
          Expanded(child: Text('Profile', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))),
          if (signedIn) ...[
            RoundIconButton(icon: Icons.notifications_rounded, tooltip: 'Notifications', onPressed: () => _comingSoon('Notifications')),
            const SizedBox(width: 10),
          ],
          RoundIconButton(icon: Icons.settings_rounded, tooltip: 'Settings', onPressed: () => showSettingsSheet(context)),
        ],
      );

  List<MenuItemData> get _infoItems => [
        MenuItemData(icon: Icons.headset_mic_rounded, label: 'Help & Contact', onTap: () => _comingSoon('Help & Contact')),
        MenuItemData(icon: Icons.info_rounded, label: 'About App', onTap: () => _comingSoon('About App')),
      ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) return _GuestProfile(topBar: _topBar(signedIn: false), infoItems: _infoItems);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              _topBar(signedIn: true),
              const SizedBox(height: 16),
              CollectorCard(user: user, summary: _summary, onEdit: _openEdit),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error!),
                Center(child: TextButton(onPressed: _load, child: const Text('Try again'))),
              ],
              const SizedBox(height: 16),
              OrderStatusCard(
                summary: _summary,
                onViewAll: () => _comingSoon('My Orders'),
                onStatus: (status) => _comingSoon('$status orders'),
              ),
              const SizedBox(height: 16),
              MenuCard(items: [
                MenuItemData(
                  icon: Icons.favorite_rounded,
                  label: 'My Wishlist',
                  badge: null,
                  onTap: () => _comingSoon('Wishlist'),
                ),
                MenuItemData(icon: Icons.location_on_rounded, label: 'Addresses', onTap: () => _comingSoon('Addresses')),
                ..._infoItems,
              ]),
              const SizedBox(height: 20),
              PillButton.danger(
                key: const Key('profile_logout'),
                label: 'Log out',
                leading: const AnimatedLogoutIcon(size: 20, color: Colors.white),
                onPressed: _confirmLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guests ("Just browsing"): invite them to log in or sign up.
class _GuestProfile extends StatelessWidget {
  final Widget topBar;
  final List<MenuItemData> infoItems;

  const _GuestProfile({required this.topBar, required this.infoItems});

  @override
  Widget build(BuildContext context) {
    const benefits = [
      'Track every order in one place',
      'Save figures and cards to your wishlist',
      'Earn points and unlock Silver & Gold',
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            topBar,
            const SizedBox(height: 16),
            CollectorCardShell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                        child: const Icon(Icons.workspace_premium_rounded, size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Join the collectors club',
                                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Free to join. Takes 30 seconds.', style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final b in benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(b, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: PillButton(
                          key: const Key('guest_login'),
                          label: 'Login',
                          color: Colors.white,
                          foregroundColor: AppTheme.primaryDark,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('guest_signup'),
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white, width: 1.5),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Sign up'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MenuCard(items: infoItems),
          ],
        ),
      ),
    );
  }
}

/// "Log out?" confirmation (Figma: "28c - Logout Confirm"). Returns true to log out.
Future<bool?> showLogoutDialog(BuildContext context) {
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
                // Plays continuously while the dialog is open
                child: const Center(
                  child: AnimatedLogoutIcon(size: 30, color: AppTheme.danger, pause: Duration(milliseconds: 500)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Log out?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "You'll need to log in again to see your orders and wishlist.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillButton.danger(
                      key: const Key('logout_confirm'),
                      label: 'Log out',
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
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
