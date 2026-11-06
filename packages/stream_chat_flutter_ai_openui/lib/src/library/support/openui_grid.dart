import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

/// [children] in equal columns, as many as fit at [minItemWidth] each, up to
/// [maxColumns] and the number of children, [spacing] apart; the children of
/// a row are as tall as its tallest.
///
/// Where the width isn't bounded, the children make one row of
/// [minItemWidth] each. It has intrinsic sizes, so it can be measured in an
/// intrinsic pass.
///
/// Internal to the package.
@internal
class OpenUIResponsiveGrid extends MultiChildRenderObjectWidget {
  /// Creates the grid of [children].
  const OpenUIResponsiveGrid({
    super.key,
    required this.minItemWidth,
    required this.maxColumns,
    required this.spacing,
    required super.children,
  });

  /// The narrowest a column is.
  final double minItemWidth;

  /// The most columns there are.
  final int maxColumns;

  /// The space between columns and between rows.
  final double spacing;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderGrid(
    minItemWidth: minItemWidth,
    maxColumns: maxColumns,
    spacing: spacing,
    textDirection: Directionality.of(context),
  );

  @override
  void updateRenderObject(BuildContext context, _RenderGrid renderObject) {
    renderObject
      ..minItemWidth = minItemWidth
      ..maxColumns = maxColumns
      ..spacing = spacing
      ..textDirection = Directionality.of(context);
  }
}

class _GridParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _GridParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _GridParentData> {
  _RenderGrid({
    required this._minItemWidth,
    required this._maxColumns,
    required this._spacing,
    required this._textDirection,
  });

  double _minItemWidth;
  set minItemWidth(double value) {
    if (value == _minItemWidth) return;
    _minItemWidth = value;
    markNeedsLayout();
  }

  int _maxColumns;
  set maxColumns(int value) {
    if (value == _maxColumns) return;
    _maxColumns = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _GridParentData) child.parentData = _GridParentData();
  }

  List<RenderBox> get _children {
    final children = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    return children;
  }

  // The columns and the width of each in [width].
  (int, double) _columns(double width, int count) {
    final most = math.max(1, math.min(_maxColumns, count));
    if (!width.isFinite) return (most, _minItemWidth);
    final fit = ((width + _spacing) / (_minItemWidth + _spacing)).floor();
    final columns = fit.clamp(1, most);
    return (columns, math.max(0, (width - _spacing * (columns - 1)) / columns));
  }

  // The size the children take in [width], each row as tall as [heightOf]
  // gives its tallest child at the column width.
  Size _measure(double width, double Function(RenderBox child, double itemWidth) heightOf) {
    final children = _children;
    if (children.isEmpty) return Size(width.isFinite ? width : 0, 0);
    final (columns, itemWidth) = _columns(width, children.length);
    var height = 0.0;
    for (var start = 0; start < children.length; start += columns) {
      var row = 0.0;
      for (final child in children.skip(start).take(columns)) {
        row = math.max(row, heightOf(child, itemWidth));
      }
      height += row + (start == 0 ? 0 : _spacing);
    }
    return Size(width.isFinite ? width : columns * itemWidth + (columns - 1) * _spacing, height);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _children.fold(0, (widest, child) => math.max(widest, child.getMinIntrinsicWidth(double.infinity)));
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = _children;
    final columns = math.max(1, math.min(_maxColumns, children.length));
    final widest = children.fold(
      _minItemWidth,
      (widest, child) => math.max(widest, child.getMaxIntrinsicWidth(height)),
    );
    return children.isEmpty ? 0 : columns * widest + (columns - 1) * _spacing;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _measure(width, (child, itemWidth) => child.getMinIntrinsicHeight(itemWidth)).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _measure(width, (child, itemWidth) => child.getMaxIntrinsicHeight(itemWidth)).height;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final size = _measure(
      constraints.maxWidth,
      (child, itemWidth) => child.getDryLayout(BoxConstraints.tightFor(width: itemWidth)).height,
    );
    return constraints.constrain(size);
  }

  @override
  void performLayout() {
    final children = _children;
    final width = constraints.maxWidth;
    if (children.isEmpty) {
      size = constraints.constrain(Size(width.isFinite ? width : 0, 0));
      return;
    }
    final (columns, itemWidth) = _columns(width, children.length);
    final rowWidth = columns * itemWidth + (columns - 1) * _spacing;
    var y = 0.0;
    for (var start = 0; start < children.length; start += columns) {
      final row = children.skip(start).take(columns).toList();
      // Each child at its own height first, then those shorter than the row
      // again at the row's height.
      var height = 0.0;
      for (final child in row) {
        child.layout(BoxConstraints.tightFor(width: itemWidth), parentUsesSize: true);
        height = math.max(height, child.size.height);
      }
      for (final (index, child) in row.indexed) {
        if (child.size.height < height) {
          child.layout(BoxConstraints.tightFor(width: itemWidth, height: height), parentUsesSize: true);
        }
        final x = index * (itemWidth + _spacing);
        (child.parentData! as _GridParentData).offset = Offset(
          _textDirection == TextDirection.rtl ? rowWidth - x - itemWidth : x,
          y,
        );
      }
      y += height + _spacing;
    }
    size = constraints.constrain(Size(width.isFinite ? width : rowWidth, y - _spacing));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
