import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/admin.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/quantity_stepper.dart';
import 'admin_widgets.dart';

/// Admin dashboard (E with A's header): greeting and Shop switch, the paid
/// revenue with this week's bars, three counts, then Live activity where each
/// event has its one-tap action. Checks for new events every 20 seconds.
class AdminDashboardScreen extends StatefulWidget {
  final AdminService service;
  final VoidCallback onShop;
  final ValueChanged<AdminStats>? onStats;
  final ValueChanged<int>? onOpenTab;

  /// The clock for the greeting (tests pass a fixed time).
  final DateTime Function()? now;

  const AdminDashboardScreen({super.key, required this.service, required this.onShop, this.onStats, this.onOpenTab, this.now});

  static const checkEvery = Duration(seconds: 20);

  @override
  State<AdminDashboardScreen> createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminStats? _stats;
  List<ActivityEvent>? _events;
  String? _error;
  Timer? _poll;

  /// Events seen so far; ones that appear later get a soft highlight.
  final _seen = <String>{};
  final _fresh = <String>{};

  /// Done labels for actions taken here, until the next check brings the new state.
  final _done = <String, String>{};
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages()); // "2m", "1h"
    _load();
    _poll = Timer.periodic(AdminDashboardScreen.checkEvery, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Fetches the numbers and the feed again (after a change on another tab).
  Future<void> reload() => _load(quiet: true);

  Future<void> _load({bool quiet = false}) async {
    try {
      final (stats, events) = await (widget.service.stats(), widget.service.activity()).wait;
      if (!mounted) return;
      setState(() {
        final firstLoad = _events == null;
        _fresh
          ..clear()
          ..addAll(firstLoad ? const <String>[] : events.map((e) => e.id).where((id) => !_seen.contains(id)));
        _seen.addAll(events.map((e) => e.id));
        _stats = stats;
        _events = events;
        _error = null;
      });
      widget.onStats?.call(stats);
    } on ParallelWaitError catch (e) {
      final first = [e.errors.$1, e.errors.$2].whereType<AsyncError>().first.error;
      if (mounted && !quiet) setState(() => _error = first is ApiException ? first.message : '$first');
    } on ApiException catch (e) {
      if (mounted && !quiet) setState(() => _error = e.message);
    }
  }

  Future<void> _act(ActivityEvent e) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Ask first (reply text, stock count); show busy only while it is sent
    final reply = e.action == ActivityAction.reply ? await _askReply(e) : null;
    final count = e.action == ActivityAction.restock ? await _askStock() : null;
    final refund = e.action == ActivityAction.refund ? await _askRefund(e) : null;
    if ((e.action == ActivityAction.reply && reply == null) ||
        (e.action == ActivityAction.restock && count == null) ||
        (e.action == ActivityAction.refund && refund != true) ||
        !mounted) {
      return;
    }
    setState(() => _busy.add(e.id));
    try {
      final done = switch (e.action!) {
        ActivityAction.confirm => await widget.service.setOrderStatus(e.orderId!, 'confirmed').then((_) => l.doneConfirmed),
        ActivityAction.ship => await widget.service.setOrderStatus(e.orderId!, 'shipped').then((_) => l.doneShipped),
        ActivityAction.reply => await widget.service.reply(e.messageId!, reply!).then((_) => l.doneReplied),
        ActivityAction.restock => await widget.service.setStock(e.productId!, count!).then((_) => l.doneRestocked(count)),
        ActivityAction.refund => await widget.service.markRefunded(e.orderId!).then((_) => l.doneRefunded),
      };
      if (mounted) setState(() => _done[e.id] = done);
      unawaited(_load(quiet: true));
    } on ApiException catch (err) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err.message), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _busy.remove(e.id));
    }
  }

  /// Only after the money was sent back (bank transfer / ABA).
  Future<bool?> _askRefund(ActivityEvent e) => showConfirmDialog(
        context,
        icon: const Icon(Icons.currency_exchange_rounded, color: AppTheme.danger, size: 30),
        title: context.l10n.refundAskTitle,
        message: context.l10n.refundAskMessage(e.orderNumber ?? ''),
        confirmLabel: context.l10n.actRefund,
        confirmKey: const Key('admin_refund_confirm'),
      );

  Future<String?> _askReply(ActivityEvent e) {
    final l = context.l10n;
    return showReplySheet(context, question: e.message, title: l.replyTitle, hint: l.replyHint, send: l.sendReply);
  }

  Future<int?> _askStock() {
    var count = 10;
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final l = context.l10n;
        return StatefulBuilder(
          builder: (context, setSheet) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.restockTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 18),
              Center(child: QuantityStepper(value: count, min: 1, max: 999, keyPrefix: 'admin_stock', onChanged: (v) => setSheet(() => count = v))),
              const SizedBox(height: 18),
              PillButton(key: const Key('admin_stock_save'), label: l.saveStock, leadingIcon: Icons.inventory_rounded, onPressed: () => Navigator.of(context).pop(count)),
            ]),
          ),
        );
      },
    );
  }

  String _greeting(AppLocalizations l, String name) {
    final hour = (widget.now ?? DateTime.now)().hour;
    return hour < 12 ? l.goodMorning(name) : hour < 18 ? l.goodAfternoon(name) : l.goodEvening(name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final name = (user?.fullName ?? 'Admin').split(' ').first;
    final stats = _stats;
    final events = _events;
    final money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

    Widget enter(Widget child, int ms, {double dy = 20}) =>
        _reduceMotion ? child : child.animate(delay: ms.ms).fadeIn(duration: 400.ms).moveY(begin: dy, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
    Widget countUp(num value, TextStyle style, {String Function(num)? format}) => _reduceMotion
        ? Text(format?.call(value) ?? '${value.round()}', style: style)
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(format?.call(v) ?? '${v.round()}', style: style),
          );

    final header = Row(children: [
      Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: dark ? scheme.surfaceContainerHigh : AppTheme.skyTint, shape: BoxShape.circle),
        child: Image.asset('assets/logo_centered.png', semanticLabel: 'Anime World Shop logo'),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.adminTitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600)),
          Text(_greeting(l, name), key: const Key('admin_greeting'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        ]),
      ),
      OutlinedButton.icon(
        key: const Key('admin_open_shop'),
        onPressed: widget.onShop,
        icon: const Icon(Icons.storefront_rounded, size: 16),
        label: Text(l.adminShop),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
          foregroundColor: scheme.onSurface,
          iconColor: scheme.primary,
          textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    ]);

    final children = <Widget>[enter(header, 0, dy: 10), const SizedBox(height: 16)];
    if (_error != null && stats == null) {
      children.add(Column(children: [
        ErrorBanner(message: _error!),
        const SizedBox(height: 12),
        PillButton(key: const Key('admin_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: _load),
      ]));
    } else if (stats == null) {
      children.add(const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())));
    } else {
      children
        ..add(enter(_RevenueCard(stats: stats, money: money, countUp: countUp, reduceMotion: _reduceMotion), 120, dy: 28))
        ..add(const SizedBox(height: 12))
        ..add(Row(children: [
          for (final (i, (key, icon, color, n, label, tab)) in [
            ('to_handle', Icons.inbox_rounded, AppTheme.amber, stats.ordersToHandle, l.toHandle, 1),
            ('low_stock', Icons.warning_rounded, AppTheme.danger, stats.lowStock, l.lowStock, 2),
            ('messages', Icons.forum_rounded, AppTheme.accent, stats.openMessages, l.messagesLabel, 3),
          ].indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _pop(
                Material(
                  color: dark ? scheme.surfaceContainer : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: Key('admin_count_$key'),
                    onTap: () => widget.onOpenTab?.call(tab),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                          child: Icon(icon, color: color, size: 19),
                        ),
                        const SizedBox(height: 10),
                        countUp(n, const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                      ]),
                    ),
                  ),
                ),
                350 + i * 90,
              ),
            ),
          ],
        ]))
        ..add(enter(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
            child: Text(l.liveActivity, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          500,
        ));
      if (events == null || events.isEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(l.noActivity, key: const Key('admin_no_activity'), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ));
      } else {
        for (final (i, e) in events.indexed) {
          Widget row = _EventRow(
            key: ValueKey('admin_event_${e.id}'),
            event: e,
            done: _done[e.id],
            busy: _busy.contains(e.id),
            fresh: _fresh.contains(e.id) && !_reduceMotion,
            onAction: () => _act(e),
          );
          if (!_reduceMotion && i < 8) {
            row = row.animate(delay: (_fresh.contains(e.id) ? 0 : 560 + i * 90).ms).fadeIn(duration: 380.ms).moveX(begin: 40, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
          }
          children.add(row);
        }
      }
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 96), children: children), // room above the + button
      ),
    );
  }

  Widget _pop(Widget child, int ms) =>
      _reduceMotion ? child : child.animate(delay: ms.ms).fadeIn(duration: 250.ms).scaleXY(begin: 0.75, end: 1, duration: 450.ms, curve: Curves.easeOutBack);
}

class _RevenueCard extends StatelessWidget {
  final AdminStats stats;
  final NumberFormat money;
  final Widget Function(num, TextStyle, {String Function(num)? format}) countUp;
  final bool reduceMotion;

  const _RevenueCard({required this.stats, required this.money, required this.countUp, required this.reduceMotion});

  String _day(BuildContext context, int daysAgo) {
    if (daysAgo == 0) return context.l10n.today;
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    try {
      return DateFormat.E(Localizations.localeOf(context).toString()).format(date);
    } catch (_) {
      return DateFormat.E('en').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final week = stats.week.length == 7 ? stats.week : List.filled(7, 0.0);
    final top = week.fold<double>(0, math.max);
    return Container(
      key: const Key('admin_revenue'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [AppTheme.cardStart, AppTheme.cardEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.revenuePaid, style: const TextStyle(color: Color(0xDDFFFFFF), fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
          countUp(stats.revenue, const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold), format: money.format),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l.thisWeek(money.format(stats.weekRevenue)), style: const TextStyle(color: Color(0xFFBBF7D0), fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
        ]),
        const SizedBox(height: 12),
        Semantics(
          label: [for (final (i, v) in week.indexed) '${_day(context, 6 - i)} ${money.format(v)}'].join(', '),
          child: SizedBox(
            height: 44,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (i, v) in week.indexed) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                    duration: Duration(milliseconds: 500 + i * 70),
                    curve: Curves.easeOutBack,
                    builder: (_, grow, _) => Container(
                      height: 44 * (top == 0 ? 0.06 : math.max(0.06, v / top)) * grow.clamp(0, 1.2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == 6 ? 1 : 0.45), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (var i = 6; i >= 0; i--)
            Expanded(child: Text(_day(context, i), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(color: Color(0xBBFFFFFF), fontSize: 11))),
        ]),
      ]),
    );
  }
}

class _EventRow extends StatelessWidget {
  final ActivityEvent event;
  final String? done;
  final bool busy;
  final bool fresh;
  final VoidCallback onAction;

  const _EventRow({super.key, required this.event, required this.done, required this.busy, required this.fresh, required this.onAction});

  static (IconData, Color) _look(ActivityKind k) => switch (k) {
        ActivityKind.paid => (Icons.payments_rounded, AppTheme.success),
        ActivityKind.order => (Icons.receipt_long_rounded, AppTheme.amber),
        ActivityKind.cancelled => (Icons.remove_shopping_cart_rounded, AppTheme.danger),
        ActivityKind.message => (Icons.forum_rounded, AppTheme.accent),
        ActivityKind.soldOut => (Icons.warning_rounded, AppTheme.danger),
      };

  String? _statusText(AppLocalizations l) => switch (event.status) {
        'pending' => l.stageWaiting,
        'confirmed' => l.stagePacking,
        'shipped' => l.stageOnTheWay,
        'delivered' => l.stageDelivered,
        'cancelled' => l.stageCancelled,
        'answered' => l.doneReplied,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    var (icon, color) = _look(event.kind);
    if (done != null && event.action == ActivityAction.ship) (icon, color) = (Icons.local_shipping_rounded, AppTheme.success);
    final label = switch (event.action) {
      ActivityAction.confirm => l.actConfirm,
      ActivityAction.ship => l.actShip,
      ActivityAction.reply => l.actReply,
      ActivityAction.restock => l.actRestock,
      ActivityAction.refund => l.actRefund,
      null => null,
    };

    Widget? footer;
    if (done != null) {
      footer = Container(
        key: Key('admin_done_${event.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.success),
          const SizedBox(width: 6),
          Flexible(child: Text(done!, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12.5))),
        ]),
      );
    } else if (label != null) {
      footer = FilledButton(
        key: Key('admin_action_${event.id}'),
        onPressed: busy ? null : onAction,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          shape: const StadiumBorder(),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 12.5),
        ),
        child: busy ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary)) : Text(label),
      );
    } else if (_statusText(l) case final status?) {
      footer = Text(status, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12));
    }

    final cardColor = dark ? scheme.surfaceContainer : Colors.white;
    Widget card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: dark ? null : [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              const SizedBox(width: 8),
              Text(timeago.format(event.at.toLocal(), locale: 'en_short'), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5)),
            ]),
            const SizedBox(height: 2),
            Text(event.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
            if (footer != null) ...[
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, alignment: Alignment.centerLeft, child: FadeTransition(opacity: a, child: child)),
                child: footer,
              ),
            ],
          ]),
        ),
        if (event.imageUrl != null) ...[
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(imageUrl: event.imageUrl!, width: 44, height: 44, fit: BoxFit.cover, errorWidget: (_, _, _) => const SizedBox(width: 44, height: 44)),
          ),
        ],
      ]),
    );
    if (fresh) {
      // A new event glows sky blue and fades back to the card color
      card = card.animate().custom(
            duration: 1600.ms,
            builder: (_, v, child) => DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.6 * (1 - v)), width: 1.5),
                color: (dark ? scheme.primary : AppTheme.skyTint).withValues(alpha: (dark ? 0.18 : 0.45) * (1 - v)),
              ),
              child: child,
            ),
          );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: card),
      ]),
    );
  }
}
