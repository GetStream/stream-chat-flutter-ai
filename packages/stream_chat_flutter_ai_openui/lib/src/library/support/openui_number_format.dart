import 'package:meta/meta.dart';

/// [value] as a program writes it, with at most [maxDecimals] decimals and
/// no separators for thousands: `1500` for `1500.0`, `12.5` and `0.33` for
/// `0.333` with 2 decimals.
///
/// `NaN` and the infinities are written as Dart writes them, and a value too
/// large for a fixed notation keeps its exponent, as in `1e+21`.
///
/// Internal to the package.
@internal
String openUIPlainNumber(num value, {int maxDecimals = 6}) {
  if (!value.isFinite) return value.toString();
  if (value == value.truncateToDouble() && value.abs() < 1e21) {
    // Written out in full: an integer past 2⁶³ would be clamped.
    final whole = value.toStringAsFixed(0);
    return whole == '-0' ? '0' : whole;
  }
  final fixed = value.toStringAsFixed(maxDecimals);
  if (fixed.contains('e')) return fixed;
  final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}
