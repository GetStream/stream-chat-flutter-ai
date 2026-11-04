import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';

/// Builds a `Row`: its children side by side, filling the width it is given.
///
/// Its `justify` places them along the row, its `align` across it, and a
/// child's `weight` gives it a share of the free space.
///
/// Internal to the package.
@internal
Widget buildA2UIRow(BuildContext context, A2UIComponentScope scope) => _flexOf(scope, Axis.horizontal);

/// Builds a `Column`: its children one below the other, with `justify`,
/// `align` and weights as a `Row` has them.
///
/// A column in a chat has no height of its own, so its weights only count
/// when it is given a height.
///
/// Internal to the package.
@internal
Widget buildA2UIColumn(BuildContext context, A2UIComponentScope scope) => _flexOf(scope, Axis.vertical);

Widget _flexOf(A2UIComponentScope scope, Axis axis) {
  return A2UIFlex(
    axis: axis,
    justify: scope.hint('justify'),
    align: scope.hint('align'),
    children: [
      for (final child in scope.children())
        // The child's weight is its own property, so it is read again when the
        // child changes, not only when this component does.
        ListenableBuilder(
          key: ValueKey(child.key),
          listenable: a2uiListenableOf(child),
          builder: (context, _) {
            return A2UIFlexChild(weight: child.weight, fills: a2uiFillsWidth(child), child: scope.build(child));
          },
        ),
    ],
  );
}

/// The space between the children of a `Row`, a `Column` or a `List`.
///
/// Internal to the package.
@internal
const double a2uiSpacing = 8;

/// The lengths of the children of a flex along its main axis when some of
/// them share its free space: [natural] lengths for children without a
/// weight, and the rest of [available] shared by [weights] for the others.
///
/// Children without a weight keep their natural length, all shrinking in
/// proportion when they don't fit. Children with a weight above 0 share what
/// is left, in proportion to their weights. With no [available] length, every
/// child keeps its natural length.
///
/// Internal to the package.
@internal
List<double> a2uiFlexSlots({
  required List<double> natural,
  required List<double> weights,
  required double? available,
  required double spacing,
}) {
  if (available == null) return natural;
  final free = math.max<double>(0, available - spacing * math.max(0, natural.length - 1));
  // Weights only count relative to one another; scaling them to the largest
  // keeps their sum finite whatever the agent wrote.
  final largest = weights.fold<double>(0, math.max);
  final shares = [
    for (final weight in weights)
      if (weight > 0) weight / largest else 0.0,
  ];
  var fixed = 0.0;
  var totalShare = 0.0;
  for (var index = 0; index < natural.length; index += 1) {
    if (shares[index] > 0) {
      totalShare += shares[index];
    } else {
      fixed += natural[index];
    }
  }
  final scale = fixed > free && fixed > 0 ? free / fixed : 1.0;
  final remaining = math.max<double>(0, free - fixed * scale);
  return [
    for (var index = 0; index < natural.length; index += 1)
      if (shares[index] <= 0)
        natural[index] * scale
      else if (totalShare > 0)
        remaining * shares[index] / totalShare
      else
        0.0,
  ];
}

/// The lengths of the children of a flex along its main axis when none of
/// them shares its free space: each its [natural] length, and, when they
/// don't fit in [available], the children that can be shorter, down to their
/// [least] length, shorter in proportion to how much they can give.
///
/// Children that can't be shorter, such as an image, keep their length.
///
/// Internal to the package.
@internal
List<double> a2uiStackSlots({
  required List<double> natural,
  required List<double> least,
  required double available,
  required double spacing,
}) {
  final used = natural.fold<double>(0, (sum, length) => sum + length) + spacing * math.max(0, natural.length - 1);
  final excess = used - available;
  if (excess <= 0) return natural;
  final give = [
    for (var index = 0; index < natural.length; index += 1) math.max<double>(0, natural[index] - least[index]),
  ];
  final totalGive = give.fold<double>(0, (sum, length) => sum + length);
  if (totalGive <= 0) return natural;
  final share = math.min<double>(1, excess / totalGive);
  return [for (var index = 0; index < natural.length; index += 1) natural[index] - give[index] * share];
}

/// Where each of the children of [lengths] starts along a flex's main axis of
/// [length], placed by [justify] with at least [spacing] between them.
///
/// Internal to the package.
@internal
List<double> a2uiFlexOffsets({
  required List<double> lengths,
  required double length,
  required String? justify,
  required double spacing,
}) {
  final count = lengths.length;
  final used = lengths.fold<double>(0, (sum, child) => sum + child);
  final free = math.max<double>(0, length - used - spacing * math.max(0, count - 1));
  var start = 0.0;
  var gap = spacing;
  switch (justify) {
    case 'center':
      start = free / 2;
    case 'end':
      start = free;
    case 'spaceBetween' when count > 1:
      gap += free / (count - 1);
    case 'spaceAround' when count > 0:
      start = free / count / 2;
      gap += free / count;
    case 'spaceEvenly':
      start = free / (count + 1);
      gap += free / (count + 1);
  }
  final offsets = <double>[];
  var position = start;
  for (final child in lengths) {
    offsets.add(position);
    position += child + gap;
  }
  return offsets;
}

/// A child of an [A2UIFlex], with its [weight].
///
/// Internal to the package.
@internal
class A2UIFlexChild extends ParentDataWidget<_A2UIFlexParentData> {
  /// Creates an [A2UIFlexChild].
  ///
  /// A child that [fills] the width it is given, such as a text field, takes
  /// a share of the free space of a row with a width as if its weight were 1
  /// when it has no weight of its own.
  const A2UIFlexChild({super.key, required this.weight, this.fills = false, required super.child});

  /// The child's share of the free space, or `null` when it has none.
  final double? weight;

  /// Whether the child fills the width it is given.
  final bool fills;

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as _A2UIFlexParentData;
    if (parentData.weight == weight && parentData.fills == fills) return;
    parentData
      ..weight = weight
      ..fills = fills;
    renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => A2UIFlex;
}

/// Lays out its children along [axis], as a `Row` or a `Column` places them.
///
/// Internal to the package.
@internal
class A2UIFlex extends MultiChildRenderObjectWidget {
  /// Creates an [A2UIFlex].
  const A2UIFlex({super.key, required this.axis, required this.justify, required this.align, super.children});

  /// The direction the children follow.
  final Axis axis;

  /// How the children are placed along [axis]: `start` (the default),
  /// `center`, `end`, `spaceBetween`, `spaceAround`, `spaceEvenly`, or
  /// `stretch`, which gives every child without a weight a weight of 1.
  final String? justify;

  /// How the children are placed across [axis]: `stretch` (the default),
  /// `start`, `center` or `end`.
  final String? align;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderA2UIFlex(
      axis: axis,
      justify: justify,
      align: align ?? 'stretch',
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderA2UIFlex renderObject) {
    renderObject
      ..axis = axis
      ..justify = justify
      ..align = align ?? 'stretch'
      ..textDirection = Directionality.of(context);
  }
}

class _A2UIFlexParentData extends ContainerBoxParentData<RenderBox> {
  double? weight;
  bool fills = false;
}

// The layout of a `Row` or a `Column`.
//
// When a child has a weight, or `justify` is `stretch`, or a row with a width
// has a child that fills its width, which counts as a weight of 1, the
// children share the free space: children without a weight keep their
// natural length, the
// length they take with no limit, shrinking together when they don't fit,
// and weighted children share the rest. Otherwise each child keeps its
// natural length, and when they don't fit, only the children that can be
// shorter, such as text, are.
//
// Across the main axis, `stretch` gives each of a row's children a frame as
// tall as the tallest, and each of a column's children one as wide as the
// column, which a child that fills, such as a divider or a card, fills.
class _RenderA2UIFlex extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _A2UIFlexParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _A2UIFlexParentData> {
  _RenderA2UIFlex({
    required this._axis,
    required this._justify,
    required this._align,
    required this._textDirection,
  });

  Axis get axis => _axis;
  Axis _axis;
  set axis(Axis value) {
    if (_axis == value) return;
    _axis = value;
    markNeedsLayout();
  }

  String? get justify => _justify;
  String? _justify;
  set justify(String? value) {
    if (_justify == value) return;
    _justify = value;
    markNeedsLayout();
  }

  String get align => _align;
  String _align;
  set align(String value) {
    if (_align == value) return;
    _align = value;
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  bool get _isRow => _axis == Axis.horizontal;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _A2UIFlexParentData) child.parentData = _A2UIFlexParentData();
  }

  // The share of the free space [child] takes, when the main axis is
  // [bounded]. A child that fills its width would be as wide as the row, so
  // in a row with a width it shares what the others leave instead.
  double _weightOf(RenderBox child, {required bool bounded}) {
    final parentData = child.parentData! as _A2UIFlexParentData;
    final weight = parentData.weight;
    if (weight != null && weight > 0) return weight;
    if (_justify == 'stretch') return 1;
    if (_isRow && bounded && parentData.fills) return 1;
    return 0;
  }

  bool _fillsWithoutWeight(RenderBox child) {
    final parentData = child.parentData! as _A2UIFlexParentData;
    final weight = parentData.weight;
    return parentData.fills && (weight == null || weight <= 0);
  }

  double _main(Size size) => _isRow ? size.width : size.height;
  double _cross(Size size) => _isRow ? size.height : size.width;

  BoxConstraints _constraints({required double maxMain, required double maxCross}) {
    return _isRow
        ? BoxConstraints(maxWidth: maxMain, maxHeight: maxCross)
        : BoxConstraints(maxWidth: maxCross, maxHeight: maxMain);
  }

  // The length [child] can be along the main axis at the least, given
  // [cross] across it. Asked only when the children don't fit.
  double _leastLength(RenderBox child, double cross) {
    return _isRow ? child.getMinIntrinsicWidth(cross) : child.getMinIntrinsicHeight(cross);
  }

  // How the children are laid out within [constraints]: each child measured
  // by [layoutChild], which lays it out or asks for its dry layout.
  ({Size size, List<Size> sizes, List<double> lengths, List<double> maxLengths, double crossLength}) _arrange(
    BoxConstraints constraints,
    Size Function(RenderBox child, BoxConstraints constraints) layoutChild,
  ) {
    final children = getChildrenAsList();
    final maxMain = _isRow ? constraints.maxWidth : constraints.maxHeight;
    final maxCross = _isRow ? constraints.maxHeight : constraints.maxWidth;
    final availableMain = maxMain.isFinite ? maxMain : null;
    final availableCross = maxCross.isFinite ? maxCross : double.infinity;
    final weights = [for (final child in children) _weightOf(child, bounded: availableMain != null)];
    final sharesFreeSpace = weights.any((weight) => weight > 0);
    final shares = sharesFreeSpace && availableMain != null;
    // A child's natural length is the length it takes when nothing limits it.
    // Beside a child that fills its width, an unweighted child takes at most
    // an equal share of the row, so a long text wraps rather than leaving the
    // field no width.
    final naturalLimit = shares && _isRow && children.any(_fillsWithoutWeight)
        ? math.max<double>(0, availableMain - a2uiSpacing * (children.length - 1)) / children.length
        : double.infinity;
    final natural = [
      for (var index = 0; index < children.length; index += 1)
        if (shares && weights[index] > 0)
          0.0
        else
          _main(layoutChild(children[index], _constraints(maxMain: naturalLimit, maxCross: availableCross))),
    ];
    final List<double> maxLengths;
    if (availableMain == null) {
      maxLengths = List.filled(children.length, double.infinity);
    } else if (shares) {
      maxLengths = a2uiFlexSlots(natural: natural, weights: weights, available: availableMain, spacing: a2uiSpacing);
    } else if (_fits(natural, availableMain)) {
      maxLengths = natural;
    } else {
      maxLengths = a2uiStackSlots(
        natural: natural,
        least: [for (final child in children) _leastLength(child, availableCross)],
        available: availableMain,
        spacing: a2uiSpacing,
      );
    }
    final measured = [
      for (var index = 0; index < children.length; index += 1)
        layoutChild(children[index], _constraints(maxMain: maxLengths[index], maxCross: availableCross)),
    ];
    final lengths = [
      for (var index = 0; index < children.length; index += 1)
        if (shares && weights[index] > 0) maxLengths[index] else _main(measured[index]),
    ];
    final contentMain =
        lengths.fold<double>(0, (sum, length) => sum + length) + a2uiSpacing * math.max(0, children.length - 1);
    final widest = measured.fold<double>(0, (widest, size) => math.max<double>(widest, _cross(size)));
    final crossLength = !_isRow && _align == 'stretch' && availableCross.isFinite ? availableCross : widest;
    final mainLength = availableMain ?? contentMain;
    final size = constraints.constrain(_isRow ? Size(mainLength, crossLength) : Size(crossLength, mainLength));
    return (size: size, sizes: measured, lengths: lengths, maxLengths: maxLengths, crossLength: _cross(size));
  }

  static bool _fits(List<double> natural, double available) {
    final used = natural.fold<double>(0, (sum, length) => sum + length);
    return used + a2uiSpacing * math.max(0, natural.length - 1) <= available;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _arrange(constraints, (child, constraints) => child.getDryLayout(constraints)).size;
  }

  @override
  void performLayout() {
    final children = getChildrenAsList();
    final arrangement = _arrange(constraints, (child, constraints) {
      child.layout(constraints, parentUsesSize: true);
      return child.size;
    });
    size = arrangement.size;
    final stretches = _align == 'stretch';
    final offsets = a2uiFlexOffsets(
      lengths: arrangement.lengths,
      length: _main(size),
      justify: _justify,
      spacing: a2uiSpacing,
    );
    for (var index = 0; index < children.length; index += 1) {
      final child = children[index];
      final childCross = stretches ? arrangement.crossLength : _cross(arrangement.sizes[index]);
      // A child is placed in a frame of its length and, when the children
      // stretch, of the cross length: one that takes its own size, such as an
      // image, keeps it, and one that fills, such as a vertical divider,
      // fills the frame. It is laid out again with the length it was measured
      // with, as text given only its measured width can wrap differently.
      child.layout(_constraints(maxMain: arrangement.maxLengths[index], maxCross: childCross), parentUsesSize: true);
      final crossOffset = switch (_align) {
        'center' => (arrangement.crossLength - _cross(child.size)) / 2,
        'end' => arrangement.crossLength - _cross(child.size),
        _ => 0.0,
      };
      final parentData = child.parentData! as _A2UIFlexParentData;
      if (_isRow) {
        // Right to left, a frame's start is its right edge.
        final x = _textDirection == TextDirection.rtl ? size.width - offsets[index] - child.size.width : offsets[index];
        parentData.offset = Offset(x, crossOffset);
      } else {
        final x = _textDirection == TextDirection.rtl ? size.width - crossOffset - child.size.width : crossOffset;
        parentData.offset = Offset(x, offsets[index]);
      }
    }
  }

  // Along the main axis, the children follow one another; across it, the
  // flex is as wide or tall as its laid-out children make it.
  double _mainIntrinsic(double extent, double Function(RenderBox, double) of) {
    final children = getChildrenAsList();
    return children.fold<double>(0, (sum, child) => sum + of(child, extent)) +
        a2uiSpacing * math.max(0, children.length - 1);
  }

  double _crossIntrinsic(double extent) {
    final constraints = _isRow ? BoxConstraints(maxWidth: extent) : BoxConstraints(maxHeight: extent);
    return _cross(computeDryLayout(constraints));
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    if (_isRow) return _mainIntrinsic(height, (child, extent) => child.getMinIntrinsicWidth(extent));
    // A column is as narrow as its widest child can be, such as text wrapped
    // at its longest word; its dry layout without a width limit would give
    // its widest line instead.
    return getChildrenAsList().fold<double>(0, (width, child) => math.max(width, child.getMinIntrinsicWidth(height)));
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (_isRow) return _mainIntrinsic(height, (child, extent) => child.getMaxIntrinsicWidth(extent));
    return _crossIntrinsic(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (!_isRow) return _mainIntrinsic(width, (child, extent) => child.getMinIntrinsicHeight(extent));
    return _crossIntrinsic(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (!_isRow) return _mainIntrinsic(width, (child, extent) => child.getMaxIntrinsicHeight(extent));
    return _crossIntrinsic(width);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
}
