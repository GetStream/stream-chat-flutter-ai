import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_translations.dart';

/// [value] with at most [maxDecimals] decimals, written with [translations]'s
/// separators, such as `1,234.5` in English.
///
/// A value too large for a fixed notation keeps its exponent, as in `1e+21`.
///
/// Internal to the package.
@internal
String openUIFormatNumber(double value, int maxDecimals, OpenUITranslations translations) {
  final fixed = value.toStringAsFixed(maxDecimals);
  if (fixed.contains('e')) return fixed;
  final parts = fixed.split('.');
  final integer = parts.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => translations.groupSeparator);
  final fraction = parts.length > 1 ? parts[1].replaceFirst(RegExp(r'0+$'), '') : '';
  return fraction.isEmpty ? integer : '$integer${translations.decimalSeparator}$fraction';
}
