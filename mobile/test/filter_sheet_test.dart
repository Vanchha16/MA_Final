import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/screens/home/widgets/filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/shop_fakes.dart';

/// Opens the sheet from a button and keeps what it returns.
class _Host extends StatefulWidget {
  final FakeCatalogService catalog;
  final ProductQuery query;

  const _Host(this.catalog, this.query);

  @override
  State<_Host> createState() => _HostState();
}

ProductQuery? result;

class _HostState extends State<_Host> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              result = await FilterSheet.show(
                context,
                query: widget.query,
                categories: [figures, boosters],
                series: [onePiece, pokemon],
                brands: const ['Bandai', 'Good Smile Company', 'The Pokemon Company'],
                countResults: widget.catalog.count,
              );
            },
            child: const Text('open'),
          ),
        ),
      );
}

Future<void> _open(WidgetTester tester, {ProductQuery query = const ProductQuery()}) async {
  result = null;
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: _Host(FakeCatalogService(), query)));
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600)); // sheet slides up, first count arrives
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200, scrollable: find.descendant(of: find.byKey(const Key('filter_scroll')), matching: find.byType(Scrollable)).first);
  }
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // debounce + count
}

String _button(WidgetTester tester) =>
    (tester.widget<FilledButton>(find.byKey(const Key('filter_apply'))).child as Text).data!;

void main() {
  testWidgets('the button shows the live number of matching products', (tester) async {
    await _open(tester);
    expect(_button(tester), 'Show 12 results');

    await _tap(tester, find.byKey(const Key('filter_brand_Bandai')));
    expect(_button(tester), 'Show 10 results');
    expect(find.text('1 selected'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('1 on'), -200,
        scrollable: find.descendant(of: find.byKey(const Key('filter_scroll')), matching: find.byType(Scrollable)).first);

    await _tap(tester, find.byKey(const Key('filter_brand_Good Smile Company')));
    expect(_button(tester), 'Show 11 results'); // several brands at once
    expect(find.text('2 selected'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('filter_apply')));
    expect(result!.brands, ['Bandai', 'Good Smile Company']);
  });

  testWidgets('no matches turns the button off', (tester) async {
    await _open(tester);
    await _tap(tester, find.byKey(const Key('filter_series_2'))); // Pokemon
    await _tap(tester, find.byKey(const Key('filter_brand_Bandai')));
    expect(_button(tester), 'No matches');
    expect(tester.widget<FilledButton>(find.byKey(const Key('filter_apply'))).onPressed, isNull);
  });

  testWidgets('quick price picks set the range and tap again to clear', (tester) async {
    await _open(tester);
    await _tap(tester, find.byKey(const Key('filter_price_0'))); // Under $25
    expect(find.text(r'$0 - $25'), findsOneWidget);
    expect(_button(tester), 'Show 10 results'); // the $5 packs; $169 Luffy and $145 box are out

    await _tap(tester, find.byKey(const Key('filter_price_0')));
    expect(find.text(r'$0 - $200+'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('filter_price_3'))); // $100+
    await _tap(tester, find.byKey(const Key('filter_apply')));
    expect(result!.minPrice, 100);
    expect(result!.maxPrice, isNull);
  });

  testWidgets('sort, category and series come back in the query', (tester) async {
    await _open(tester);
    await _tap(tester, find.byKey(const Key('filter_sort_price_asc')));
    await _tap(tester, find.byKey(const Key('filter_cat_6')));
    await _tap(tester, find.byKey(const Key('filter_series_more'))); // See all
    expect(find.text('Show less'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('filter_series_1')));
    await _tap(tester, find.byKey(const Key('filter_apply')));

    expect(result!.sort, ProductSort.priceAsc);
    expect(result!.categoryId, 6);
    expect(result!.seriesId, 1);
  });

  testWidgets('Reset clears everything', (tester) async {
    await _open(tester, query: const ProductQuery(categoryId: 6, brands: ['Bandai'], inStockOnly: true, sort: ProductSort.name));
    expect(find.text('3 on'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('filter_reset')));
    expect(find.byKey(const Key('filter_on_count')), findsNothing);
    expect(_button(tester), 'Show 12 results');

    await _tap(tester, find.byKey(const Key('filter_apply')));
    expect(result!.activeFilterCount, 0);
    expect(result!.sort, ProductSort.newest);
  });
}
