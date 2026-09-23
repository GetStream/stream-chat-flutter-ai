/// Interpolation helpers shared by the component theme datas.
///
/// Internal. Every field on those classes is nullable, and `null` means "derive
/// it from the ambient [ThemeData]" rather than zero, transparent or empty — so
/// a field only one side sets cannot be interpolated towards, and these helpers
/// swap at the midpoint instead.
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Whether both sides set a field, the only case worth interpolating.
@internal
bool bothSet(Object? a, Object? b) => a != null && b != null;

/// Picks the nearer side, for a field only one of them sets.
///
/// Don't interpolate instead: `null` means "derive from the theme", not zero or
/// transparent, so [Color.lerp] would fade a border through transparency and
/// [lerpDouble] would grow a box from zero.
@internal
T? swapAtMidpoint<T>(T? a, T? b, double t) => t < 0.5 ? a : b;

/// [lerpDouble] where both sides set the value, a swap where only one does.
@internal
double? lerpDoubleOrSwap(double? a, double? b, double t) =>
    bothSet(a, b) ? lerpDouble(a, b, t) : swapAtMidpoint(a, b, t);

/// [Color.lerp] where both sides set the color, a swap where only one does.
@internal
Color? lerpColorOrSwap(Color? a, Color? b, double t) => bothSet(a, b) ? Color.lerp(a, b, t) : swapAtMidpoint(a, b, t);

/// [TextStyle.lerp] where both sides set the style, a swap where only one does.
@internal
TextStyle? lerpTextStyleOrSwap(TextStyle? a, TextStyle? b, double t) =>
    bothSet(a, b) ? TextStyle.lerp(a, b, t) : swapAtMidpoint(a, b, t);

/// Lays [override] over [base]; a `null` override leaves [base] as it is.
///
/// As with [TextStyle.merge], an `inherit: false` override replaces [base]
/// outright — so a caller that needs a property to survive, such as a color,
/// has to restore it afterwards.
@internal
TextStyle mergeTextStyle(TextStyle base, TextStyle? override) => base.merge(override);
