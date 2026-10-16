import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/screens/admin/admin_products_screen.dart';
import 'package:ecommerce_app/widgets/pill_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/admin_fake.dart';

void main() {
  testWidgets('a pill field stops at its maximum length', (tester) async {
    final name = TextEditingController();
    addTearDown(name.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: PillTextField(fieldKey: const Key('name'), controller: name, label: 'Name', icon: Icons.person, maxLength: 100)),
    ));
    await tester.enterText(find.byKey(const Key('name')), 'N' * 150);
    await tester.pump();
    expect(name.text.length, 100);
  });

  testWidgets('admin price fields take only digits and a dot', (tester) async {
    tester.view.physicalSize = const Size(412, 1400) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final s = FakeAdminService();
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: AdminProductFormScreen(service: s, pickPhotos: () async => [])));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('admin_product_price')), 'nan');
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('admin_product_price'))).controller!.text, isEmpty);
    await tester.enterText(find.byKey(const Key('admin_product_price')), '12.50');
    await tester.enterText(find.byKey(const Key('admin_product_name')), 'Z' * 200);
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('admin_product_price'))).controller!.text, '12.50');
    expect(tester.widget<TextField>(find.byKey(const Key('admin_product_name'))).controller!.text.length, 150);

    await tester.tap(find.byKey(const Key('admin_product_save')));
    await tester.pumpAndSettle();
    expect(s.savedProducts.last['price'], 12.5);
  });
}
