import 'package:ecommerce_app/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BuildContext> _pump(WidgetTester tester, {bool reduceMotion = false}) async {
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    // Above the Navigator, so the toast's overlay sees it too
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
    home: Scaffold(body: Builder(builder: (context) {
      ctx = context;
      return const SizedBox();
    })),
  ));
  return ctx;
}

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('opens to a title over the message, then hides by itself', (tester) async {
    final context = await _pump(tester);
    AppToast.success(context, 'Profile updated');
    await _frames(tester);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Profile updated'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await _frames(tester, 12);
    expect(find.text('Profile updated'), findsNothing);
  });

  testWidgets('Undo runs once and closes the island', (tester) async {
    final context = await _pump(tester);
    var undone = 0;
    AppToast.removed(context, 'Removed Luffy', onUndo: () => undone++);
    await _frames(tester);
    expect(find.text('Changed your mind?'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await _frames(tester, 12);
    expect(undone, 1);
    expect(find.text('Removed Luffy'), findsNothing);
  });

  testWidgets('a new message replaces the one on screen', (tester) async {
    final context = await _pump(tester);
    AppToast.error(context, 'Cannot connect to server');
    await _frames(tester, 3);
    AppToast.warning(context, 'Only 5 available for this item');
    await _frames(tester);
    expect(find.text('Cannot connect to server'), findsNothing);
    expect(find.text('Heads up'), findsOneWidget);
    expect(find.text('Only 5 available for this item'), findsOneWidget);
  });

  testWidgets('swiping it up dismisses it', (tester) async {
    final context = await _pump(tester);
    AppToast.info(context, 'Google sign-in is coming in the next update');
    await _frames(tester);
    await tester.drag(find.text('Good to know'), const Offset(0, -60));
    await _frames(tester, 12);
    expect(find.text('Good to know'), findsNothing);
  });

  testWidgets('with reduce motion it is shown open straight away', (tester) async {
    final context = await _pump(tester, reduceMotion: true);
    AppToast.success(context, 'Password changed');
    await tester.pump();
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);
    expect(find.bySemanticsLabel('Done. Password changed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
