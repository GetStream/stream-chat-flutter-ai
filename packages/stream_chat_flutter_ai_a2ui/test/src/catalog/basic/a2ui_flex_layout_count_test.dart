import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';

import '../../a2ui_test_app.dart';

// Rows and Columns nested ten deep lay out the component at the bottom once a
// frame, however deep it is.
void main() {
  for (final type in ['Row', 'Column']) {
    testWidgets('a Text in $type nested 10 deep is laid out once', (tester) async {
      final counter = _LayoutCounter();
      await pumpSurface(
        tester,
        components: _nested(type, depth: 10),
        catalog: A2UICatalog.basic.replacing('Text', (context, scope) => _Counted(counter: counter)),
      );

      expect(counter.layouts, 1);
    });
  }

  testWidgets('a Text in Rows and Columns nested 10 deep in turn is laid out once', (tester) async {
    final counter = _LayoutCounter();
    await pumpSurface(
      tester,
      components: _nested('Row', depth: 10, alternate: true),
      catalog: A2UICatalog.basic.replacing('Text', (context, scope) => _Counted(counter: counter)),
    );

    expect(counter.layouts, 1);
  });
}

// [depth] components of [type], each the only child of the one before, around
// a Text; with [alternate], Rows and Columns take turns.
List<Map<String, Object?>> _nested(String type, {required int depth, bool alternate = false}) {
  String typeAt(int level) => !alternate || level.isEven ? type : (type == 'Row' ? 'Column' : 'Row');
  return [
    for (var level = 0; level < depth; level += 1)
      {
        'id': level == 0 ? 'root' : 'f$level',
        'component': typeAt(level),
        'children': [if (level == depth - 1) 'leaf' else 'f${level + 1}'],
      },
    {'id': 'leaf', 'component': 'Text', 'text': 'Ohrid'},
  ];
}

class _LayoutCounter {
  int layouts = 0;
}

class _Counted extends LeafRenderObjectWidget {
  const _Counted({required this.counter});

  final _LayoutCounter counter;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCounted(counter);
}

class _RenderCounted extends RenderBox {
  _RenderCounted(this.counter);

  final _LayoutCounter counter;

  static const _size = Size(40, 20);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(_size);

  @override
  double computeMinIntrinsicWidth(double height) => _size.width;

  @override
  double computeMaxIntrinsicWidth(double height) => _size.width;

  @override
  double computeMinIntrinsicHeight(double width) => _size.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _size.height;

  @override
  void performLayout() {
    counter.layouts += 1;
    size = constraints.constrain(_size);
  }
}
