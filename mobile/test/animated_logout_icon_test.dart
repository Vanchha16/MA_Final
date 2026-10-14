import 'package:ecommerce_app/widgets/animated_logout_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _icon({bool reduceMotion = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Center(child: AnimatedLogoutIcon(size: 30, color: Colors.red)),
      ),
    );

void main() {
  testWidgets('loops the arrow animation', (tester) async {
    await tester.pumpWidget(_icon());
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isTrue);
    expect(find.bySemanticsLabel('Log out'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // disposes the ticker cleanly
  });

  testWidgets('stays still when reduce motion is on', (tester) async {
    await tester.pumpWidget(_icon(reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
