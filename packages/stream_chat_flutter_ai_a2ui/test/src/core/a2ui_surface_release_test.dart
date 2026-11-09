import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

import 'a2ui_test_surfaces.dart';

// What a surface's listeners hear when the surface goes away.
void main() {
  test('a surface the agent deletes notifies its listeners that its root is gone', () {
    final processor = testProcessor()..apply([createPlanSurface(), updatePlanComponents()]);
    final roots = _rootsSeen(processor.surface('plan')!);

    processor.apply([deletePlanSurface()]);

    expect(roots, [null]);
  });

  test("a reset processor's surface notifies its listeners that its root is gone", () {
    final processor = testProcessor()..apply([createPlanSurface(), updatePlanComponents()]);
    final roots = _rootsSeen(processor.surface('plan')!);

    processor.reset();

    expect(roots, [null]);
  });

  test("a disposed processor's surface does not notify its listeners", () {
    final processor = A2UIProcessor(catalogs: A2UICatalogs())..apply([createPlanSurface(), updatePlanComponents()]);
    final roots = _rootsSeen(processor.surface('plan')!);

    processor.dispose();

    expect(roots, isEmpty);
  });

  test('a deleted surface without a root does not notify its listeners', () {
    final processor = testProcessor()..apply([createPlanSurface()]);
    final roots = _rootsSeen(processor.surface('plan')!);

    processor.apply([deletePlanSurface()]);

    expect(roots, isEmpty);
  });
}

// The roots [surface] has each time it notifies its listeners.
List<A2UINode?> _rootsSeen(A2UISurface surface) {
  final roots = <A2UINode?>[];
  surface.addListener(() => roots.add(surface.root));
  return roots;
}
