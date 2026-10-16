import 'package:ecommerce_app/core/theme/app_theme.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/models/order.dart';
import 'package:ecommerce_app/screens/catalog/reviews_screen.dart';
import 'package:ecommerce_app/screens/orders/order_details_screen.dart';
import 'package:ecommerce_app/widgets/review_sheet.dart';
import 'package:ecommerce_app/widgets/to_review_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/orders_fake.dart';
import 'fakes/review_fake.dart';
import 'fakes/shop_fakes.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
  await tester.pumpAndSettle();
}

/// A page with one button that opens the review sheet and keeps what it returned.
class _Opener extends StatefulWidget {
  final FakeReviewService service;
  final Review? existing;

  const _Opener(this.service, {this.existing});

  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  ReviewOutcome? outcome;
  bool closed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: FilledButton(
            key: const Key('open'),
            onPressed: () async {
              final o = await showReviewSheet(context, productId: 1, productName: demoProducts[0].name, existing: widget.existing, service: widget.service);
              setState(() {
                outcome = o;
                closed = true;
              });
            },
            child: const Text('Open'),
          ),
        ),
      );
}

Order _delivered() => Order(
      id: 7,
      number: 'AWS-20261014-0007',
      status: 'delivered',
      paymentMethod: PaymentMethod.cod,
      paymentStatus: 'paid',
      subtotal: 174,
      total: 174,
      itemCount: 2,
      shippingName: 'Demo Customer',
      shippingAddress: '#24 St. 271, Chamkar Mon, Phnom Penh',
      createdAt: DateTime.utc(2026, 10, 12),
      lines: [
        OrderLine(productId: 1, name: demoProducts[0].name, unitPrice: 169, quantity: 1),
        const OrderLine(productId: 3, name: 'One Piece Booster Pack #3', unitPrice: 5, quantity: 1, myRating: 4),
      ],
    );

void main() {
  testWidgets('rating sheet: stars set the word, tags and comment are posted, then Thanks', (tester) async {
    final service = FakeReviewService();
    await _pump(tester, _Opener(service));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('Rate your figure'), findsOneWidget);
    expect(find.text('Tap a star to rate'), findsOneWidget);
    // Post does nothing until a star is picked
    await tester.ensureVisible(find.byKey(const Key('review_post')));
    await tester.tap(find.byKey(const Key('review_post')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(service.saved, isEmpty);

    await tester.tap(find.byKey(const Key('review_star_4')));
    await tester.pumpAndSettle();
    expect(find.text('Very good'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review_star_5')));
    await tester.pumpAndSettle();
    expect(find.text('Excellent'), findsOneWidget);

    await tester.tap(find.byKey(const Key('review_tag_quality')));
    await tester.tap(find.byKey(const Key('review_tag_packaging')));
    await tester.enterText(find.byKey(const Key('review_comment')), '  Love it!  ');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review_post')));
    await tester.tap(find.byKey(const Key('review_post')));
    await tester.pump(const Duration(milliseconds: 400));

    final (product, stars, comment, tags) = service.saved.single;
    expect((product, stars, comment), (1, 5, 'Love it!'));
    expect(tags, ['quality', 'packaging']);
    expect(find.text('Thanks for your review!'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2)); // the sheet closes by itself
    final state = tester.state<_OpenerState>(find.byType(_Opener));
    expect(state.outcome?.review?.rating, 5);
    expect(find.byKey(const Key('review_thanks')), findsNothing);
  });

  testWidgets('rating sheet shows the server error and stays open', (tester) async {
    final service = FakeReviewService()..failSave = true;
    await _pump(tester, _Opener(service));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review_star_3')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review_post')));
    await tester.tap(find.byKey(const Key('review_post')));
    await tester.pumpAndSettle();
    expect(find.text('Keep it under 1000 characters'), findsOneWidget);
    expect(find.text('Rate your figure'), findsOneWidget);
  });

  testWidgets('editing: Save changes, and Delete asks first', (tester) async {
    final service = FakeReviewService();
    final mine = Review(id: 9, user: 'Demo Customer', rating: 3, comment: 'Okay', tags: const ['value'], createdAt: DateTime.now(), isMine: true);
    service.all.insert(0, mine);
    await _pump(tester, _Opener(service, existing: mine));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('Edit your review'), findsOneWidget);
    expect(find.text('Okay'), findsWidgets); // the word and the comment
    expect(tester.widget<FilterChip>(find.byKey(const Key('review_tag_value'))).selected, isTrue);
    await tester.ensureVisible(find.byKey(const Key('review_delete')));
    await tester.tap(find.byKey(const Key('review_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete your review?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review_delete_confirm')));
    await tester.pumpAndSettle();
    expect(service.deleted, [1]);
    expect(tester.state<_OpenerState>(find.byType(_Opener)).outcome?.deleted, isTrue);
  });

  testWidgets('Reviews page: score, star filters, comments filter and my review first', (tester) async {
    final service = FakeReviewService();
    service.all.insert(0, Review(id: 9, user: 'Demo Customer', rating: 4, comment: 'Mine', createdAt: DateTime.now(), isMine: true));
    await _pump(tester, ReviewsScreen(product: demoProducts[0], service: service, canReview: true));

    expect(tester.widget<Text>(find.byKey(const Key('reviews_score'))).data, '4.5'); // (5+4+5+4) / 4
    expect(find.text('4 reviews'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.byKey(const Key('review_edit_mine')), findsOneWidget);
    expect(find.byKey(const Key('reviews_write')), findsNothing); // already reviewed

    await tester.ensureVisible(find.byKey(const Key('reviews_filter_5')));
    await tester.tap(find.byKey(const Key('reviews_filter_5')));
    await tester.pumpAndSettle();
    expect(find.text('Box arrived perfect.'), findsOneWidget);
    expect(find.text('Great paint work.'), findsNothing);
    expect(find.text('Mine'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('reviews_filter_comments')));
    await tester.tap(find.byKey(const Key('reviews_filter_comments')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review_3')), findsNothing); // stars only, no comment
    expect(find.text('Great paint work.'), findsOneWidget);
  });

  testWidgets('order details: Rate it on a delivered item, then its stars show', (tester) async {
    final reviews = FakeReviewService();
    await _pump(tester, OrderDetailsScreen(order: _delivered(), service: FakeOrderService(), reviewService: reviews));

    expect(find.byKey(const Key('details_rate_1')), findsOneWidget);
    expect(find.byKey(const Key('details_rate_3')), findsNothing); // already rated
    expect(find.byKey(const Key('details_my_rating_3')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('details_rate_1')));
    await tester.tap(find.byKey(const Key('details_rate_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review_star_5')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review_post')));
    await tester.tap(find.byKey(const Key('review_post')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(reviews.saved.single.$2, 5);
    expect(find.byKey(const Key('details_rate_1')), findsNothing);
    expect(find.byKey(const Key('details_my_rating_1')), findsOneWidget);
    expect(find.text('Review posted'), findsOneWidget);
  });

  testWidgets('the Rate it notification opens the order with the sheet up', (tester) async {
    await _pump(tester, OrderDetailsScreen(order: _delivered(), service: FakeOrderService(), reviewService: FakeReviewService(), rateFirst: true));
    expect(find.text('Rate your figure'), findsOneWidget);
  });

  testWidgets('To review sheet lists delivered items and ticks them once rated', (tester) async {
    final service = FakeReviewService()
      ..pending = [ToReviewItem(product: demoProducts[0], orderId: 7, orderNumber: 'AWS-20261014-0007')];
    await _pump(tester, Scaffold(body: Builder(builder: (context) => Center(child: FilledButton(key: const Key('open'), onPressed: () => showToReviewSheet(context, service: service), child: const Text('Open'))))));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('1 waiting'), findsOneWidget);
    await tester.tap(find.byKey(Key('to_review_rate_${demoProducts[0].id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review_star_4')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review_post')));
    await tester.tap(find.byKey(const Key('review_post')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('1 waiting'), findsNothing);
  });

  testWidgets('To review sheet when nothing is waiting', (tester) async {
    await _pump(tester, Scaffold(body: Builder(builder: (context) => Center(child: FilledButton(key: const Key('open'), onPressed: () => showToReviewSheet(context, service: FakeReviewService()), child: const Text('Open'))))));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.text('All caught up!'), findsOneWidget);
  });
}
