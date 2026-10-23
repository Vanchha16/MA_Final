import 'package:ecommerce_app/core/constants/api_constants.dart';
import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/widgets/server_address_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('what the user types becomes the API address', () {
    expect(ApiConstants.serverUrl('192.168.1.10'), 'http://192.168.1.10:5000/api');
    expect(ApiConstants.serverUrl(' 192.168.1.10:8000 '), 'http://192.168.1.10:8000/api');
    expect(ApiConstants.serverUrl('http://192.168.1.10:5000/api/'), 'http://192.168.1.10:5000/api');
    expect(ApiConstants.serverUrl('https://shop.example.com'), 'https://shop.example.com/api');
    expect(ApiConstants.serverUrl(''), isNull);
    expect(ApiConstants.serverUrl('not an address'), isNull);
    expect(ApiConstants.serverUrl('ftp://x'), isNull);
    expect(serverLabel('http://192.168.1.10:5000/api'), '192.168.1.10:5000');
  });

  testWidgets('the sheet saves a server that answers and remembers it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final pinged = <String>[];
    var answers = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showServerAddressSheet(context, ping: (url) async {
              pinged.add(url);
              return answers;
            }),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('server_field')), 'oops address');
    await tester.tap(find.byKey(const Key('server_save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an address like 192.168.1.10'), findsOneWidget);
    expect(pinged, isEmpty);

    await tester.enterText(find.byKey(const Key('server_field')), '192.168.1.10');
    await tester.tap(find.byKey(const Key('server_save')));
    await tester.pumpAndSettle();
    expect(pinged, ['http://192.168.1.10:5000/api']);
    expect(find.byKey(const Key('server_save_anyway')), findsOneWidget); // did not answer

    answers = true;
    await tester.tap(find.byKey(const Key('server_save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server_field')), findsNothing); // sheet closed
    expect(find.text('Server saved'), findsOneWidget);
    expect(ApiClient.instance.baseUrl, 'http://192.168.1.10:5000/api');
    expect((await SharedPreferences.getInstance()).getString(ApiClient.serverKey), 'http://192.168.1.10:5000/api');

    await ApiClient.instance.setServer(null); // back to the default for other tests
    expect(ApiClient.instance.usesDefaultServer, isTrue);
  });
}
