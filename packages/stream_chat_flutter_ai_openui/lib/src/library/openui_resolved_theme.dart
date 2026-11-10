import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_core_flutter/core.dart';

/// An [OpenUIThemeData] with every value set, which the OpenUI components
/// draw with.
///
/// Resolution order is: the view's own theme, then the nearest [OpenUITheme],
/// then the defaults from the app's [StreamTheme].
///
/// Internal to the package.
@immutable
@internal
final class OpenUIResolvedTheme {
  const OpenUIResolvedTheme._(this._data);

  /// Resolves the theme at [context], with [override], the view's own theme,
  /// layered on top.
  factory OpenUIResolvedTheme.resolve(BuildContext context, {OpenUIThemeData? override}) {
    return OpenUIResolvedTheme.fromData(OpenUITheme.of(context).merge(override), StreamTheme.of(context));
  }

  /// Fills [data]'s unset values from [stream].
  factory OpenUIResolvedTheme.fromData(OpenUIThemeData data, StreamTheme stream) {
    return OpenUIResolvedTheme._(OpenUIThemeData.defaults(stream).merge(data));
  }

  final OpenUIThemeData _data;

  /// This theme with [body] in place of its body style and [text] in place of
  /// its primary text color, each when given.
  OpenUIResolvedTheme copyWith({TextStyle? body, Color? text}) =>
      OpenUIResolvedTheme._(_data.copyWith(body: body, text: text));

  /// See [OpenUIThemeData.accent].
  Color get accent => _data.accent!;

  /// See [OpenUIThemeData.onAccent].
  Color get onAccent => _data.onAccent!;

  /// See [OpenUIThemeData.text].
  Color get text => _data.text!;

  /// See [OpenUIThemeData.secondaryText].
  Color get secondaryText => _data.secondaryText!;

  /// See [OpenUIThemeData.tertiaryText].
  Color get tertiaryText => _data.tertiaryText!;

  /// See [OpenUIThemeData.surface].
  Color get surface => _data.surface!;

  /// See [OpenUIThemeData.sunkenSurface].
  Color get sunkenSurface => _data.sunkenSurface!;

  /// See [OpenUIThemeData.subtleFill].
  Color get subtleFill => _data.subtleFill!;

  /// See [OpenUIThemeData.border].
  Color get border => _data.border!;

  /// See [OpenUIThemeData.success].
  Color get success => _data.success!;

  /// See [OpenUIThemeData.warning].
  Color get warning => _data.warning!;

  /// See [OpenUIThemeData.error].
  Color get error => _data.error!;

  /// See [OpenUIThemeData.info].
  Color get info => _data.info!;

  /// See [OpenUIThemeData.neutral].
  Color get neutral => _data.neutral!;

  /// See [OpenUIThemeData.chartPalette].
  List<Color> get chartPalette => _data.chartPalette!;

  /// See [OpenUIThemeData.xsSpacing].
  double get xsSpacing => _data.xsSpacing!;

  /// See [OpenUIThemeData.sSpacing].
  double get sSpacing => _data.sSpacing!;

  /// See [OpenUIThemeData.mSpacing].
  double get mSpacing => _data.mSpacing!;

  /// See [OpenUIThemeData.lSpacing].
  double get lSpacing => _data.lSpacing!;

  /// See [OpenUIThemeData.xlSpacing].
  double get xlSpacing => _data.xlSpacing!;

  /// See [OpenUIThemeData.xxlSpacing].
  double get xxlSpacing => _data.xxlSpacing!;

  /// See [OpenUIThemeData.smallCornerRadius].
  double get smallCornerRadius => _data.smallCornerRadius!;

  /// See [OpenUIThemeData.mediumCornerRadius].
  double get mediumCornerRadius => _data.mediumCornerRadius!;

  /// See [OpenUIThemeData.cornerRadius].
  double get cornerRadius => _data.cornerRadius!;

  /// See [OpenUIThemeData.pillCornerRadius].
  double get pillCornerRadius => _data.pillCornerRadius!;

  /// See [OpenUIThemeData.title].
  TextStyle get title => _data.title!;

  /// See [OpenUIThemeData.heading].
  TextStyle get heading => _data.heading!;

  /// See [OpenUIThemeData.body].
  TextStyle get body => _data.body!;

  /// See [OpenUIThemeData.bodyLarge].
  TextStyle get bodyLarge => _data.bodyLarge!;

  /// See [OpenUIThemeData.bodySmall].
  TextStyle get bodySmall => _data.bodySmall!;

  /// See [OpenUIThemeData.caption].
  TextStyle get caption => _data.caption!;

  /// See [OpenUIThemeData.code].
  TextStyle get code => _data.code!;

  /// See [OpenUIThemeData.metric].
  TextStyle get metric => _data.metric!;

  @override
  bool operator ==(Object other) => identical(this, other) || other is OpenUIResolvedTheme && other._data == _data;

  @override
  int get hashCode => _data.hashCode;
}
