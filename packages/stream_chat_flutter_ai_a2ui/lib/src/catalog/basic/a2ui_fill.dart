import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Gives [child] the whole length along [axis] it is given when that length
/// has a limit, such as the width of a column, and lets it take its own
/// length when it has none, such as the width in a row that scrolls.
///
/// Internal to the package.
@internal
class A2UIFill extends SingleChildRenderObjectWidget {
  /// Creates an [A2UIFill].
  const A2UIFill({super.key, required this.axis, super.child});

  /// The direction [child] fills.
  final Axis axis;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFill(axis);

  @override
  void updateRenderObject(BuildContext context, _RenderFill renderObject) => renderObject.axis = axis;
}

class _RenderFill extends RenderProxyBox {
  _RenderFill(this._axis);

  Axis get axis => _axis;
  Axis _axis;
  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsLayout();
  }

  BoxConstraints _filled(BoxConstraints constraints) {
    return switch (_axis) {
      Axis.horizontal when constraints.hasBoundedWidth => constraints.tighten(width: constraints.maxWidth),
      Axis.vertical when constraints.hasBoundedHeight => constraints.tighten(height: constraints.maxHeight),
      _ => constraints,
    };
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return _filled(constraints).smallest;
    return child.getDryLayout(_filled(constraints));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = _filled(constraints).smallest;
      return;
    }
    child.layout(_filled(constraints), parentUsesSize: true);
    size = child.size;
  }
}
