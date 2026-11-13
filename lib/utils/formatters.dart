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

/// Formats a service price unit for display (e.g. 'per_tree' -> 'Per Tree', 'per_kanal' -> 'Per Kanal').
String formatPriceUnit(String? unit) {
  if (unit == null || unit.trim().isEmpty) return '';
  final normalized = unit.trim().toLowerCase();
  switch (normalized) {
    case 'per_tree':
    case 'tree':
    case 'per tree':
      return 'Per Tree';
    case 'per_kanal':
    case 'kanal':
    case 'per kanal':
      return 'Per Kanal';
    case 'per_acre':
    case 'acre':
    case 'per acre':
      return 'Per Acre';
    case 'per_visit':
    case 'visit':
    case 'per visit':
      return 'Per Visit';
    case 'fixed':
      return 'Fixed';
    case 'per_hour':
    case 'hour':
    case 'per hour':
      return 'Per Hour';
    case 'per_day':
    case 'day':
    case 'per day':
      return 'Per Day';
    default:
      final words = unit.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
      return words
          .map((w) => w.isNotEmpty
              ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}'
              : '')
          .join(' ');
  }
}

/// Returns a clean suffix like `/ Tree` or `/ Kanal` or `/ Visit`.
String formatPriceUnitSuffix(String? unit) {
  final formatted = formatPriceUnit(unit);
  if (formatted.isEmpty) return '';
  if (formatted.toLowerCase().startsWith('per ')) {
    return '/ ${formatted.substring(4)}';
  }
  if (formatted.toLowerCase() == 'fixed') {
    return '(Fixed)';
  }
  return '/ $formatted';
}
