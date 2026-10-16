import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../providers/locale_provider.dart';
import '../../providers/shop_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/checkout_service.dart';
import '../../services/preferences_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/theme_reveal.dart';
import '../auth/login_screen.dart';
import 'about_screen.dart';
import 'addresses_screen.dart';
import 'help_screen.dart';

/// Settings (picked from the Settings previews, C): pick the look on three
/// little phones (the new theme spreads in a circle from the one tapped),
/// English or Khmer, which notifications to get, then addresses, help and about.
class SettingsScreen extends StatefulWidget {
  final PreferencesService? preferences;
  final CheckoutService? addresses;

  const SettingsScreen({super.key, this.preferences, this.addresses});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PreferencesService _prefsService = widget.preferences ?? PreferencesService();
  late final CheckoutService _addressService = widget.addresses ?? CheckoutService();
  NotifyPrefs? _prefs;
  int? _addressCount;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    if (context.read<ShopProvider>().signedIn) _loadAccount();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // No version line
    }
  }

  Future<void> _loadAccount() async {
    try {
      final (prefs, addresses) = await (_prefsService.get(), _addressService.addresses()).wait;
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _addressCount = addresses.length;
        });
      }
    } catch (_) {
      // The switches stay hidden until it loads
    }
  }

  /// Switches move right away and go back if saving fails.
  Future<void> _savePrefs(NotifyPrefs next) async {
    final before = _prefs;
    setState(() => _prefs = next);
    try {
      final saved = await _prefsService.save(next);
      if (mounted) setState(() => _prefs = saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _prefs = before);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
    }
  }

  void _setTheme(ThemeMode mode, GlobalKey from) {
    final theme = context.read<ThemeProvider>();
    if (theme.mode == mode) return;
    final box = from.currentContext?.findRenderObject() as RenderBox?;
    final reveal = ThemeReveal.maybeOf(context);
    if (box == null || reveal == null) {
      theme.setMode(mode);
      return;
    }
    reveal.run(box.localToGlobal(box.size.center(Offset.zero)), () => theme.setMode(mode));
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted && context.read<ShopProvider>().signedIn) await _loadAccount();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final signedIn = context.watch<ShopProvider>().signedIn;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget enter(int i, Widget child) => reduceMotion ? child : child.animate(delay: (80 * i).ms).fadeIn(duration: 300.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic);
    final prefs = _prefs;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Flexible(
                child: Text(l.settingsTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              key: const Key('settings_list'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                enter(0, _Label(l.appearance)),
                enter(0, _Card(padding: const EdgeInsets.fromLTRB(8, 16, 8, 14), child: _ThemePicker(onPick: _setTheme))),
                enter(1, _Label(l.language)),
                enter(1, const _Card(child: _LanguageSwitch())),
                enter(2, _Label(l.notifyMeAbout)),
                enter(
                  2,
                  _Card(
                    padding: EdgeInsets.zero,
                    child: !signedIn
                        ? _Row(
                            key: const Key('settings_notify_login'),
                            icon: Icons.notifications_rounded,
                            color: AppTheme.amber,
                            title: l.logInToChooseNotifications,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                          )
                        : prefs == null
                            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                            : Column(children: [
                                _Row(
                                  icon: Icons.local_shipping_rounded,
                                  color: const Color(0xFF7C3AED),
                                  title: l.notifyOrders,
                                  subtitle: l.notifyOrdersSub,
                                  trailing: Switch(key: const Key('notify_orders'), value: prefs.orders, onChanged: (v) => _savePrefs(prefs.copyWith(orders: v))),
                                ),
                                const _Divider(),
                                _Row(
                                  icon: Icons.local_offer_rounded,
                                  color: AppTheme.coral,
                                  title: l.notifyOffers,
                                  subtitle: l.notifyOffersSub,
                                  trailing: Switch(key: const Key('notify_offers'), value: prefs.offers, onChanged: (v) => _savePrefs(prefs.copyWith(offers: v))),
                                ),
                                const _Divider(),
                                _Row(
                                  icon: Icons.campaign_rounded,
                                  color: AppTheme.primaryDark,
                                  title: l.notifyNews,
                                  subtitle: l.notifyNewsSub,
                                  trailing: Switch(key: const Key('notify_news'), value: prefs.news, onChanged: (v) => _savePrefs(prefs.copyWith(news: v))),
                                ),
                              ]),
                  ),
                ),
                enter(3, _Label(l.more)),
                enter(
                  3,
                  _Card(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      if (signedIn) ...[
                        _Row(
                          key: const Key('settings_addresses'),
                          icon: Icons.location_on_rounded,
                          color: AppTheme.primaryDark,
                          title: l.myAddresses,
                          subtitle: _addressCount == null ? null : l.addressesSaved(_addressCount!),
                          onTap: () => _push(AddressesScreen(service: _addressService)),
                        ),
                        const _Divider(),
                      ],
                      _Row(
                        key: const Key('settings_help'),
                        icon: Icons.headset_mic_rounded,
                        color: AppTheme.success,
                        title: l.helpContact,
                        onTap: () => _push(const HelpScreen()),
                      ),
                      const _Divider(),
                      _Row(
                        key: const Key('settings_about'),
                        icon: Icons.info_rounded,
                        color: const Color(0xFF64748B),
                        title: l.about,
                        subtitle: _version.isEmpty ? null : l.version(_version),
                        onTap: () => _push(AboutScreen(version: _version)),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
        child: Text(text, style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Divider(height: 1, indent: 62, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5));
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Row({super.key, required this.icon, required this.color, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ]),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// System / Light / Dark as three little phones.
class _ThemePicker extends StatefulWidget {
  final void Function(ThemeMode mode, GlobalKey from) onPick;
  const _ThemePicker({required this.onPick});

  @override
  State<_ThemePicker> createState() => _ThemePickerState();
}

class _ThemePickerState extends State<_ThemePicker> {
  final _keys = {for (final m in ThemeMode.values) m: GlobalKey()};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mode = context.watch<ThemeProvider>().mode;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final (m, label) in [(ThemeMode.system, l.themeSystem), (ThemeMode.light, l.themeLight), (ThemeMode.dark, l.themeDark)])
          Flexible(
            child: _Phone(
              key: Key('theme_${m.name}'),
              previewKey: _keys[m]!,
              mode: m,
              label: label,
              selected: mode == m,
              onTap: () => widget.onPick(m, _keys[m]!),
            ),
          ),
      ],
    );
  }
}

class _Phone extends StatelessWidget {
  final GlobalKey previewKey;
  final ThemeMode mode;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Phone({super.key, required this.previewKey, required this.mode, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const duration = Duration(milliseconds: 250);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          AnimatedScale(
            scale: selected ? 1.05 : 1,
            duration: duration,
            child: AnimatedContainer(
              key: previewKey,
              duration: duration,
              width: 92,
              height: 144,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1.5),
                boxShadow: [if (selected) BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 14)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Row(children: [
                  Expanded(child: _MiniScreen(dark: mode == ThemeMode.dark)),
                  if (mode == ThemeMode.system) const Expanded(child: _MiniScreen(dark: true)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: duration,
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? scheme.primary : Colors.transparent,
                border: Border.all(color: selected ? scheme.primary : scheme.outline, width: 2),
              ),
              child: AnimatedScale(scale: selected ? 1 : 0, duration: duration, curve: Curves.easeOutBack, child: Icon(Icons.check_rounded, size: 12, color: scheme.onPrimary)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? scheme.primary : scheme.onSurface)),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// A tiny drawing of the app in light or dark colours.
class _MiniScreen extends StatelessWidget {
  final bool dark;
  const _MiniScreen({required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0F172A) : const Color(0xFFF6F9FE);
    final card = dark ? const Color(0xFF1E293B) : Colors.white;
    Widget box(double h) => Container(height: h, decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(5)));
    return Container(
      color: bg,
      padding: const EdgeInsets.all(6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(height: 6, width: 28, decoration: BoxDecoration(color: dark ? Colors.white70 : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 6),
        Container(height: 28, decoration: BoxDecoration(color: dark ? const Color(0xFF38BDF8) : AppTheme.primaryDark, borderRadius: BorderRadius.circular(6))),
        const SizedBox(height: 5),
        Row(children: [Expanded(child: box(32)), const SizedBox(width: 4), Expanded(child: box(32))]),
        const SizedBox(height: 5),
        box(20),
      ]),
    );
  }
}

/// English / ខ្មែរ with a pill that slides to the choice.
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final khmer = locale.isKhmer;
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: dark ? scheme.surfaceContainerHighest : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(26)),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: khmer ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? scheme.surfaceContainer : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
              ),
            ),
          ),
        ),
        Row(children: [
          for (final (code, label) in [('en', 'English'), ('km', 'ខ្មែរ')])
            Expanded(
              child: InkWell(
                key: Key('language_$code'),
                borderRadius: BorderRadius.circular(22),
                onTap: () => locale.setLocale(Locale(code)),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.language_rounded, size: 17, color: locale.locale.languageCode == code ? scheme.primary : scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(label,
                        style: TextStyle(
                          fontWeight: locale.locale.languageCode == code ? FontWeight.bold : FontWeight.w500,
                          color: locale.locale.languageCode == code ? scheme.primary : scheme.onSurfaceVariant,
                        )),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
