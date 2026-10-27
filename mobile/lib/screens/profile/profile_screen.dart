import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/profile_summary.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/animated_logout_icon.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/menu_card.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/round_icon_button.dart';
import '../../widgets/to_review_sheet.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../settings/about_screen.dart';
import '../settings/addresses_screen.dart';
import '../settings/help_screen.dart';
import '../settings/settings_screen.dart';
import '../orders/orders_screen.dart';
import '../admin/admin_shell.dart';
import '../shell/main_shell.dart';
import 'edit_profile_screen.dart';
import 'widgets/collector_card.dart';
import 'widgets/order_status_card.dart';
import '../../l10n/l10n.dart';

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

  Future<void> _openOrders() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
    if (mounted) await _load(); // order counts may have changed
  }

  Future<void> _openToReview() async {
    final rated = await showToReviewSheet(context);
    if (rated == true && mounted) await _load(); // the To review count went down
  }

  Future<void> _open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));


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
          Expanded(child: Text(context.l10n.profileTitle, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold))),
          if (signedIn) ...[
            const NotificationBell(),
            const SizedBox(width: 10),
          ],
          RoundIconButton(icon: Icons.settings_rounded, tooltip: context.l10n.settingsTitle, onPressed: () => _open(const SettingsScreen())),
        ],
      );

  List<MenuItemData> get _infoItems => [
        MenuItemData(icon: Icons.headset_mic_rounded, label: context.l10n.helpContact, onTap: () => _open(const HelpScreen())),
        MenuItemData(icon: Icons.info_rounded, label: context.l10n.aboutApp, onTap: () => _open(const AboutScreen())),
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
                onViewAll: _openOrders,
                onStatus: (label) => label == context.l10n.toReview ? _openToReview() : _openOrders(),
              ),
              const SizedBox(height: 16),
              MenuCard(items: [
                if (context.watch<AuthProvider>().user?.isStaff ?? false)
                  MenuItemData(icon: Icons.admin_panel_settings_rounded, label: context.l10n.adminTitle, onTap: () => AdminShell.open(context)),
                MenuItemData(
                  icon: Icons.favorite_rounded,
                  label: context.l10n.myWishlist,
                  badge: null,
                  onTap: () => MainShell.requestedTab.value = MainShell.wishlistTab,
                ),
                MenuItemData(icon: Icons.location_on_rounded, label: context.l10n.addresses, onTap: () => _open(const AddressesScreen())),
                ..._infoItems,
              ]),
              const SizedBox(height: 20),
              PillButton.danger(
                key: const Key('profile_logout'),
                label: context.l10n.logOut,
                leadingIcon: Icons.logout_rounded,
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
                            Text('Free to join. Takes 30 seconds.', style: TextStyle(color: Color(0xEBFFFFFF), fontSize: 13)),
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
Future<bool?> showLogoutDialog(BuildContext context) => showConfirmDialog(
      context,
      // Plays continuously while the dialog is open
      icon: const AnimatedLogoutIcon(size: 30, color: AppTheme.danger, pause: Duration(milliseconds: 500)),
      title: 'Log out?',
      message: "You'll need to log in again to see your orders and wishlist.",
      confirmLabel: 'Log out',
      confirmKey: const Key('logout_confirm'),
    );
