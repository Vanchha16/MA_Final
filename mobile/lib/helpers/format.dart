import 'package:intl/intl.dart';

final _whole = NumberFormat.currency(symbol: r'$', decimalDigits: 0);
final _cents = NumberFormat.currency(symbol: r'$', decimalDigits: 2);

/// One place for prices: "$169", "$4.50", "$1,250".
String formatPrice(num value) => value == value.roundToDouble() ? _whole.format(value) : _cents.format(value);
