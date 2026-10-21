import 'package:flutter/foundation.dart';

/// [bytes] as a file size the way iOS shows one: `512 bytes`, `2 KB`,
/// `2.4 MB`, decimal units.
@internal
String formatFileSize(int bytes) {
  if (bytes < 1000) return bytes == 1 ? '1 byte' : '$bytes bytes';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final digits = value >= 100 || unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
