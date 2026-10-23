import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import '../core/theme/app_theme.dart';

enum ToastKind { success, removed, info, warning, error }

/// The app's short messages (picked option K): a black "island" at the top that
/// grows out of a dot, then opens to show a small coloured title over the message.
/// One at a time; hides after [duration], or swipe it up.
///
/// The add-to-cart, wishlist and promo code toasts have their own designs.
class AppToast {
  static OverlayEntry? _entry;

  static void success(BuildContext context, String message, {String? action, VoidCallback? onAction}) =>
      show(context, message, kind: ToastKind.success, action: action, onAction: onAction);

  /// Something was taken away; pass [onUndo] to offer Undo. (The message already
  /// says "Removed ...", so the title does not repeat it.)
  static void removed(BuildContext context, String message, {VoidCallback? onUndo}) => show(
        context,
        message,
        kind: ToastKind.removed,
        title: onUndo == null ? 'All set' : 'Changed your mind?',
        action: onUndo == null ? null : 'Undo',
        onAction: onUndo,
      );

  static void info(BuildContext context, String message) => show(context, message, kind: ToastKind.info);

  static void warning(BuildContext context, String message, {String? action, VoidCallback? onAction}) =>
      show(context, message, kind: ToastKind.warning, action: action, onAction: onAction);

  static void error(BuildContext context, String message) => show(context, message, kind: ToastKind.error);

  static void show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.success,
    String? title,
    String? action,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
    Key? key,
  }) {
    if (!context.mounted) return; // e.g. an Undo tapped after leaving the screen
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        top: MediaQuery.paddingOf(context).top + 8,
        // The overlay has no Material above it: without one the text gets
        // Flutter's yellow "missing Material" underline
        child: Material(type: MaterialType.transparency, child: _Island(
          key: key,
          kind: kind,
          title: title ?? _title(kind),
          message: message,
          action: action,
          onAction: onAction,
          duration: duration,
          onGone: () {
            if (_entry == entry) _entry = null;
            if (entry.mounted) entry.remove();
          },
        )),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Removes the message on screen at once.
  static void hide() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  static String _title(ToastKind kind) => switch (kind) {
        ToastKind.success => 'Done',
        ToastKind.removed => 'All set',
        ToastKind.info => 'Good to know',
        ToastKind.warning => 'Heads up',
        ToastKind.error => 'Oops',
      };
}

class _Island extends StatefulWidget {
  final ToastKind kind;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onGone;

  const _Island({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    required this.action,
    required this.onAction,
    required this.duration,
    required this.onGone,
  });

  @override
  State<_Island> createState() => _IslandState();
}

class _IslandState extends State<_Island> with SingleTickerProviderStateMixin {
  static const _dot = 46.0;
  static const _open = Duration(milliseconds: 280);

  /// 0 = a dot, 1 = full width. After that the island opens to show the title.
  late final _grow = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  bool _opened = false;
  bool _closing = false;
  double _drag = 0;
  Timer? _timer;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_still) {
        _grow.value = 1;
        setState(() => _opened = true);
        return;
      }
      await _grow.animateTo(1, curve: Curves.easeOutCubic);
      if (mounted && !_closing) setState(() => _opened = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _grow.dispose();
    super.dispose();
  }

  /// Folds the title away, shrinks back to a dot, then goes.
  void _close() {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    if (_still) return widget.onGone();
    setState(() => _opened = false);
    // A Timer (not Future.delayed) so dispose can cancel it
    _timer = Timer(_open, () async {
      await _grow.animateBack(0, duration: const Duration(milliseconds: 260), curve: Curves.easeInCubic);
      if (mounted) widget.onGone();
    });
  }

  void _tapAction() {
    widget.onAction?.call();
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (circle, ink, icon) = _look(widget.kind);
    return LayoutBuilder(builder: (context, box) {
      final full = box.maxWidth;
      return GestureDetector(
        onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(-80.0, 0.0)),
        onVerticalDragEnd: (d) {
          if (_drag < -24 || (d.primaryVelocity ?? 0) < -300) {
            _close();
          } else {
            setState(() => _drag = 0);
          }
        },
        child: Transform.translate(
          offset: Offset(0, _drag),
          child: AnimatedBuilder(
            animation: _grow,
            builder: (context, _) {
              final g = _grow.value;
              final textIn = ((g - 0.6) / 0.4).clamp(0.0, 1.0);
              return Opacity(
                opacity: (g * 4).clamp(0.0, 1.0),
                child: Center(
                  child: Container(
                    width: _dot + (full - _dot) * g,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(_opened ? 27 : 23),
                      border: dark ? Border.all(color: const Color(0x26FFFFFF)) : null,
                      boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))],
                    ),
                    // The content is laid out at full width while the island grows
                    child: OverflowBox(
                      fit: OverflowBoxFit.deferToChild,
                      alignment: Alignment.centerLeft,
                      minWidth: full,
                      maxWidth: full,
                      child: _Resize(
                        still: _still,
                        duration: _open,
                        child: Semantics(
                          container: true,
                          liveRegion: true,
                          label: '${widget.title}. ${widget.message}',
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(7, 7, 10, _opened ? 10 : 7),
                            child: Row(children: [
                              AnimatedContainer(
                                duration: _open,
                                width: _opened ? 40 : 32,
                                height: _opened ? 40 : 32,
                                decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
                                child: Icon(icon, color: Colors.white, size: _opened ? 22 : 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Opacity(
                                  opacity: textIn,
                                  child: ExcludeSemantics(
                                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      if (_opened)
                                        Text(widget.title, style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                                      Text(
                                        widget.message,
                                        maxLines: _opened ? 3 : 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.25),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                              if (widget.action != null) ...[
                                const SizedBox(width: 8),
                                Opacity(
                                  opacity: textIn,
                                  child: Material(
                                    color: const Color(0xFF27272A),
                                    shape: const StadiumBorder(),
                                    child: InkWell(
                                      customBorder: const StadiumBorder(),
                                      onTap: _tapAction,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        child: Text(widget.action!, style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 13)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }

  /// Circle colour, title/action colour (bright, for the black island), icon.
  static (Color, Color, IconData) _look(ToastKind kind) => switch (kind) {
        ToastKind.success => (AppTheme.success, const Color(0xFF4ADE80), Icons.check_rounded),
        ToastKind.removed => (AppTheme.primaryDark, const Color(0xFF38BDF8), Icons.delete_outline_rounded),
        ToastKind.info => (const Color(0xFF0E7490), const Color(0xFF22D3EE), Icons.lightbulb_outline_rounded),
        ToastKind.warning => (const Color(0xFFB45309), const Color(0xFFFBBF24), Icons.priority_high_rounded),
        ToastKind.error => (AppTheme.danger, const Color(0xFFF87171), Icons.close_rounded),
      };
}

/// Animates the island opening; with reduce motion it just takes the new size
/// (an AnimatedSize with a zero duration trips over itself during layout).
class _Resize extends StatelessWidget {
  final bool still;
  final Duration duration;
  final Widget child;

  const _Resize({required this.still, required this.duration, required this.child});

  @override
  Widget build(BuildContext context) =>
      still ? child : AnimatedSize(duration: duration, curve: Curves.easeOutCubic, alignment: Alignment.topCenter, child: child);
}
