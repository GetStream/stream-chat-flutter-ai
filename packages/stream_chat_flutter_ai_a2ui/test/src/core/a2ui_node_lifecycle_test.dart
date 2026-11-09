import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

void main() {
  test('a node is disposed when its component leaves the tree', () {
    final (:processor, :title) = _planWithTitle();

    _dropTitle(processor);

    expect(() => title.addListener(() {}), throwsFlutterError);
  });

  test('a node is disposed when its surface is deleted', () {
    final (:processor, :title) = _planWithTitle();

    processor.apply([deletePlanSurface()]);

    expect(() => title.addListener(() {}), throwsFlutterError);
  });

  test('a disposed node has no properties', () {
    final (:processor, :title) = _planWithTitle();

    _dropTitle(processor);

    expect(title.property('text'), isNull);
  });

  test('a disposed node has no children', () {
    final processor = testProcessor()..apply([createPlanSurface(), updatePlanComponents()]);
    final root = processor.surface('plan')!.root!;

    processor.apply([deletePlanSurface()]);

    expect(root.children('children'), isEmpty);
  });

  test('a disposed node writes nothing', () {
    final processor = testProcessor()..apply([createPlanSurface(), updatePlanComponents()]);
    final surface = processor.surface('plan')!;
    final email = rootChild(surface, 'email');
    processor.apply([
      updatePlanComponents(
        components: [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['title'],
          },
        ],
      ),
    ]);

    email.write('value', 'other@example.com');

    expect(surface.read('/email'), 'person@example.com');
  });
}

({A2UIProcessor processor, A2UINode title}) _planWithTitle() {
  final processor = testProcessor()..apply([createPlanSurface(), updatePlanComponents()]);
  return (processor: processor, title: rootChild(processor.surface('plan')!, 'title'));
}

// Leaves only `pace` under the root, so the title's component leaves the tree.
void _dropTitle(A2UIProcessor processor) {
  processor.apply([
    updatePlanComponents(
      components: [
        {
          'id': 'root',
          'component': 'Column',
          'children': ['pace'],
        },
      ],
    ),
  ]);
}
