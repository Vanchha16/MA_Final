import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/pill_button.dart';

/// Pieces shared by the admin pages so they look like the dashboard.

const _cyan = Color(0xFF06B6D4);

/// Order status -> (label, color).
(String, Color) orderStatusLook(String status, {bool pickup = false}) => switch (status) {
      'pending' => ('Pending', AppTheme.amber),
      'confirmed' => ('Confirmed', _cyan),
      'shipped' => (pickup ? 'Ready' : 'Shipped', AppTheme.primaryDark),
      'delivered' => (pickup ? 'Picked up' : 'Delivered', AppTheme.success),
      _ => ('Cancelled', const Color(0xFF64748B)),
    };

/// Short label for the list's one-tap button.
String nextStepShort(String status, {bool pickup = false}) =>
    switch (status) { 'confirmed' => 'Confirm', 'shipped' => pickup ? 'Ready' : 'Ship', 'delivered' => pickup ? 'Picked up' : 'Delivered', _ => 'Cancel' };

/// Label for the details page's main button.
String nextStepLong(String status, {bool pickup = false}) => switch (status) {
      'confirmed' => 'Mark confirmed',
      'shipped' => pickup ? 'Mark ready' : 'Mark shipped',
      'delivered' => pickup ? 'Mark picked up' : 'Mark delivered',
      _ => 'Cancel order',
    };

Color adminCardColor(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Theme.of(context).brightness == Brightness.dark ? scheme.surfaceContainer : Colors.white;
}

List<BoxShadow>? adminShadow(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? null
    : [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))];

/// Page title row: an optional back button, the title, then a trailing chip.
class AdminTitle extends StatelessWidget {
  final String title;
  final bool back;
  final Widget? trailing;

  const AdminTitle(this.title, {super.key, this.back = false, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Row(children: [
          if (back) ...[const CircleBackButton(), const SizedBox(width: 12)],
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
          ?trailing,
        ]),
      );
}

class AdminChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const AdminChip(this.text, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5)),
        ]),
      );
}

class AdminSearch extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const AdminSearch({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: adminCardColor(context),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          ),
        ),
      );
}

/// A row of filter chips with counts; the selected one is solid.
class AdminFilters extends StatelessWidget {
  final List<(String, int?)> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final String keyPrefix;

  const AdminFilters({super.key, required this.items, required this.selected, required this.onSelected, required this.keyPrefix});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A handful of chips: build them all (a lazy list would skip the ones off screen)
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        for (final (i, (label, count)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          ChoiceChip(
            key: Key('${keyPrefix}_$i'),
            label: Text(count == null ? label : '$label  $count'),
            selected: i == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(i),
            shape: const StadiumBorder(),
            side: BorderSide(color: i == selected ? scheme.primary : scheme.outlineVariant),
            selectedColor: scheme.primary,
            backgroundColor: adminCardColor(context),
            labelStyle: TextStyle(fontWeight: FontWeight.w600, color: i == selected ? scheme.onPrimary : scheme.onSurface),
          ),
        ],
      ]),
    );
  }
}

/// White rounded card (surface in dark mode) with the soft blue shadow.
class AdminCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Key? inkKey;

  const AdminCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14), this.inkKey});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: adminShadow(context)),
        child: Material(
          color: adminCardColor(context),
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(key: inkKey, onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );
}

class AdminLabel extends StatelessWidget {
  final String text;

  const AdminLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
        child: Text(text, style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// Empty or error message in the middle of a list page.
class AdminEmpty extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  const AdminEmpty({super.key, required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            PillButton(key: const Key('admin_list_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: onRetry),
          ],
        ]),
      );
}

void adminSnack(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

/// Bottom sheet to answer a Contact message; returns the answer, or null.
Future<String?> showReplySheet(BuildContext context, {required String question, String title = 'Reply to the customer', String hint = 'Your answer goes to their Notifications', String send = 'Send reply'}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReplySheet(question: question, title: title, hint: hint, send: send),
    );

/// Owns its text field so it is cleaned up only after the sheet has gone.
class _ReplySheet extends StatefulWidget {
  final String question, title, hint, send;

  const _ReplySheet({required this.question, required this.title, required this.hint, required this.send});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final answer = _text.text.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(widget.question, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        TextField(
          key: const Key('admin_reply_text'),
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(2000)],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: widget.hint,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
        PillButton(
          key: const Key('admin_reply_send'),
          label: widget.send,
          leadingIcon: Icons.send_rounded,
          onPressed: answer.isEmpty ? null : () => Navigator.of(context).pop(answer),
        ),
      ]),
    );
  }
}
