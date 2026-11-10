import 'package:intl/intl.dart';

final _intCurrencyFormat = NumberFormat('#,##,##0', 'en_IN');
final _decCurrencyFormat = NumberFormat('#,##,##0.00', 'en_IN');
final _dateFormat = DateFormat('d MMM yyyy');
final _dateTimeFormat = DateFormat('d MMM yyyy, HH:mm');

/// Formats an amount consistently using `Rs.` across the application.
///
/// Drops trailing `.00` by default unless [alwaysShowDecimals] is true.
String formatCurrency(dynamic raw, {bool alwaysShowDecimals = false}) {
  final value = raw is num
      ? raw.toDouble()
      : double.tryParse(raw?.toString().trim() ?? '');
  if (value == null) return 'Rs. 0';

  final isNegative = value < 0;
  final abs = value.abs();
  final formatted = alwaysShowDecimals || abs != abs.roundToDouble()
      ? _decCurrencyFormat.format(abs)
      : _intCurrencyFormat.format(abs);

  return isNegative ? '-Rs. $formatted' : 'Rs. $formatted';
}

/// Parses a [DateTime] or ISO-8601 date string into a local date (`16 Sep 2026`).
String formatDate(dynamic raw) {
  if (raw == null) return '';
  if (raw is DateTime) {
    return _dateFormat.format(raw.toLocal());
  }
  final str = raw.toString().trim();
  if (str.isEmpty) return '';
  final parsed = DateTime.tryParse(str);
  if (parsed != null) {
    return _dateFormat.format(parsed.toLocal());
  }
  return str.split('T').first;
}

/// Parses a [DateTime] or ISO-8601 timestamp into `16 Sep 2026, 14:30`.
String formatDateTime(dynamic raw) {
  if (raw == null) return '';
  if (raw is DateTime) {
    return _dateTimeFormat.format(raw.toLocal());
  }
  final str = raw.toString().trim();
  if (str.isEmpty) return '';
  final parsed = DateTime.tryParse(str);
  if (parsed != null) {
    return _dateTimeFormat.format(parsed.toLocal());
  }
  return str.split('T').first;
}
