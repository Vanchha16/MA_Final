import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/shop_info.dart';
import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/order.dart';
import '../../providers/shop_provider.dart';
import '../../services/contact_service.dart';
import '../../services/order_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pill_button.dart';
import '../auth/login_screen.dart';

/// Opens a link in another app (phone, Telegram, mail, maps). Returns false when it could not.
typedef LinkLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchOutside(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

/// Contact us (picked from the Contact previews, C): the support card with
/// Telegram first plus call, email and visit, then a message form (topic,
/// which order, the message) whose reply arrives in Notifications.
class ContactScreen extends StatefulWidget {
  final ContactService? service;
  final OrderService? orderService;
  final LinkLauncher launcher;

  /// The clock for "Online" / "Closed now" (tests pass a fixed time).
  final DateTime Function()? now;

  const ContactScreen({super.key, this.service, this.orderService, this.launcher = _launchOutside, this.now});

  static const telegramBlue = Color(0xFF229ED9);
  static const maxLength = 1000;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  late final ContactService _service = widget.service ?? ContactService();
  late final OrderService _orderService = widget.orderService ?? OrderService();
  final _message = TextEditingController();
  ContactTopic? _topic;
  List<Order>? _orders;
  bool _loadingOrders = false;
  int? _orderId;
  bool _sending = false;
  String? _error;

  /// Set once sent: the order it was about (or '' for none). Shows the thank-you card.
  String? _sentAbout;

  @override
  void initState() {
    super.initState();
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  Future<void> _open(Uri uri, String value) async {
    var opened = false;
    try {
      opened = await widget.launcher(uri);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    // No app for it (e.g. no phone app on the web): copy the value instead
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    AppToast.error(context, context.l10n.couldNotOpen(value));
  }

  void _pickTopic(ContactTopic topic) {
    setState(() => _topic = topic);
    if (topic.aboutAnOrder && _orders == null && !_loadingOrders) _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final orders = await _orderService.list();
      if (mounted) {
        setState(() {
          _orders = orders.take(10).toList();
          _orderId = _orders!.isEmpty ? null : _orders!.first.id; // newest first
        });
      }
    } on ApiException {
      if (mounted) setState(() => _orders = const []); // the picker just stays hidden
    } finally {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    final topic = _topic ?? ContactTopic.other;
    final orderId = topic.aboutAnOrder ? _orderId : null;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _service.send(topic: topic, message: text, orderId: orderId);
      final order = (_orders ?? const <Order>[]).where((o) => o.id == orderId).firstOrNull;
      if (mounted) setState(() => _sentAbout = order?.number ?? '');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _again() => setState(() {
        _sentAbout = null;
        _topic = null;
        _message.clear();
      });

  String _stage(BuildContext context, Order o) {
    final l = context.l10n;
    return switch (o.stage) {
      OrderStage.toPay => l.stageToPay,
      OrderStage.waitingConfirm => l.stageWaiting,
      OrderStage.packing => l.stagePacking,
      OrderStage.onTheWay => o.isPickup ? l.stageReady : l.stageOnTheWay,
      OrderStage.delivered => o.isPickup ? l.stagePickedUp : l.stageDelivered,
      OrderStage.cancelled => l.stageCancelled,
    };
  }

  Widget _enter(Widget child, int ms) => _reduceMotion ? child : child.animate(delay: ms.ms).fadeIn(duration: 400.ms).moveY(begin: 24, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final cardColor = dark ? scheme.surfaceContainer : Colors.white;
    final signedIn = context.watch<ShopProvider>().signedIn;
    BoxDecoration card() => BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: dark ? null : [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
        );
    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
          child: Text(text, style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant)),
        );

    final online = ShopInfo.isOpen((widget.now ?? DateTime.now)());
    final statusColor = online ? AppTheme.success : scheme.onSurfaceVariant;
    Widget dot = Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: online ? AppTheme.success : const Color(0xFF94A3B8), shape: BoxShape.circle, border: Border.all(color: cardColor, width: 2)),
    );
    final ring = online && !_reduceMotion
        ? Container(width: 14, height: 14, decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.45), shape: BoxShape.circle))
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(begin: 1, end: 2.2, duration: 1100.ms, curve: Curves.easeOut)
            .fadeOut(duration: 1100.ms)
        : null;

    Widget outlined(String key, IconData icon, String text, VoidCallback onTap) => Expanded(
          child: OutlinedButton.icon(
            key: Key('contact_$key'),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: const StadiumBorder(),
              side: BorderSide(color: scheme.outlineVariant),
              foregroundColor: scheme.onSurface,
              iconColor: scheme.primary,
              textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );

    final support = Container(
      padding: const EdgeInsets.all(16),
      decoration: card(),
      child: Column(children: [
        Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 56,
              height: 56,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: dark ? scheme.surfaceContainerHighest : AppTheme.skyTint, shape: BoxShape.circle),
              child: Image.asset('assets/logo_centered.png', semanticLabel: 'Anime World Shop logo'),
            ),
            if (ring != null) Positioned(right: 1, bottom: 1, child: ring),
            Positioned(right: 1, bottom: 1, child: dot),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.supportName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(online ? l.supportOnline : l.supportOffline,
                  key: const Key('contact_status'), style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        PillButton(
          key: const Key('contact_telegram'),
          label: l.chatTelegram,
          leadingIcon: Icons.send_rounded,
          color: ContactScreen.telegramBlue,
          foregroundColor: Colors.white,
          onPressed: () => _open(ShopInfo.telegramUri, ShopInfo.telegram),
        ),
        const SizedBox(height: 10),
        Row(children: [
          outlined('call', Icons.call_rounded, l.callShort, () => _open(ShopInfo.phoneUri, ShopInfo.phone)),
          const SizedBox(width: 8),
          outlined('email', Icons.mail_rounded, l.emailUs, () => _open(ShopInfo.emailUri, ShopInfo.email)),
          const SizedBox(width: 8),
          outlined('visit', Icons.directions_rounded, l.visitShort, () => _open(ShopInfo.mapsUri, ShopInfo.address)),
        ]),
      ]),
    );

    final Widget formCard;
    if (!signedIn) {
      formCard = Material(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: const Key('contact_login'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.13), shape: BoxShape.circle),
            child: Icon(Icons.lock_open_rounded, color: scheme.primary, size: 20),
          ),
          title: Text(l.loginToMessage, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(l.loginToMessageSub),
          trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
        ),
      );
    } else if (_sentAbout != null) {
      Widget check = Container(
        width: 72,
        height: 72,
        decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
      );
      if (!_reduceMotion) check = check.animate().scaleXY(begin: 0.4, end: 1, duration: 550.ms, curve: Curves.easeOutBack);
      formCard = Container(
        key: const Key('contact_sent'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 16),
        decoration: card(),
        child: Column(children: [
          check,
          const SizedBox(height: 14),
          Text(l.messageSent, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(_sentAbout!.isEmpty ? l.messageSentGeneral : l.messageSentAbout(_sentAbout!),
              textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 8),
          TextButton(key: const Key('contact_send_another'), onPressed: _again, child: Text(l.sendAnother, style: const TextStyle(fontWeight: FontWeight.bold))),
        ]),
      );
    } else {
      final fill = dark ? scheme.surfaceContainerHigh : const Color(0xFFF1F5F9);
      final topics = [
        (ContactTopic.order, l.topicOrder),
        (ContactTopic.payment, l.topicPayment),
        (ContactTopic.product, l.topicProduct),
        (ContactTopic.other, l.topicOther),
      ];
      final orders = _orders ?? const <Order>[];
      final showOrders = (_topic?.aboutAnOrder ?? false) && orders.isNotEmpty;
      Widget plane = const Icon(Icons.send_rounded, color: Colors.white, size: 20);
      if (_sending && !_reduceMotion) {
        plane = plane.animate().move(end: const Offset(140, -40), duration: 600.ms, curve: Curves.easeInCubic).rotate(end: -0.08, duration: 600.ms).fadeOut(duration: 600.ms);
      }
      formCard = Container(
        key: const Key('contact_form'),
        padding: const EdgeInsets.all(16),
        decoration: card(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.whatAbout, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (topic, text) in topics)
              ChoiceChip(
                key: Key('contact_topic_${topic.name}'),
                label: Text(text),
                selected: _topic == topic,
                showCheckmark: false,
                onSelected: (_) => _pickTopic(topic),
                shape: const StadiumBorder(),
                side: BorderSide(color: _topic == topic ? scheme.primary : scheme.outlineVariant),
                selectedColor: scheme.primary,
                backgroundColor: cardColor,
                labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _topic == topic ? scheme.onPrimary : scheme.onSurface),
              ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !showOrders
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(25)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          key: const Key('contact_order'),
                          value: _orderId,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(18),
                          icon: Icon(Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
                          onChanged: (id) => setState(() => _orderId = id),
                          items: [
                            for (final o in orders)
                              DropdownMenuItem(
                                value: o.id,
                                child: Row(children: [
                                  Icon(Icons.receipt_long_rounded, size: 18, color: scheme.onSurfaceVariant),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(l.orderNumber(o.number), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  Text(' · ${_stage(context, o)}', style: TextStyle(color: scheme.onSurfaceVariant)),
                                ]),
                              ),
                            DropdownMenuItem(value: null, child: Text(l.noSpecificOrder)),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('contact_message'),
            controller: _message,
            minLines: 4,
            maxLines: 6,
            enabled: !_sending,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(ContactScreen.maxLength)],
            decoration: InputDecoration(
              hintText: l.messageHint,
              filled: true,
              fillColor: fill,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(message: _error!)],
          const SizedBox(height: 14),
          PillButton(
            key: const Key('contact_send'),
            label: _sending ? l.sending : l.sendMessage,
            leading: plane,
            // Stays solid while sending so the paper plane can fly off it
            onPressed: _message.text.trim().isEmpty ? null : (_sending ? () {} : _send),
          ),
          const SizedBox(height: 8),
          Text(l.replyNote, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
        ]),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Flexible(
                child: Text(l.contactTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 14),
            _enter(support, 0),
            _enter(label(l.orSendMessage), 120),
            _enter(
              AnimatedSwitcher(
                duration: Duration(milliseconds: _reduceMotion ? 0 : 400),
                switchInCurve: Curves.easeOut,
                layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                child: KeyedSubtree(key: ValueKey(_sentAbout != null), child: formCard),
              ),
              160,
            ),
            _enter(label(l.shopLabel), 260),
            _enter(
              Material(
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: const Key('contact_shop'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.13), shape: BoxShape.circle),
                    child: const Icon(Icons.storefront_rounded, color: Color(0xFF7C3AED), size: 20),
                  ),
                  title: Text(l.shopShortAddress, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l.openHours),
                  trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                  onTap: () => _open(ShopInfo.mapsUri, ShopInfo.address),
                ),
              ),
              300,
            ),
          ],
        ),
      ),
    );
  }
}
