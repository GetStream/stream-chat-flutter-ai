import 'package:flutter_test/flutter_test.dart';

import 'a2ui_test_surfaces.dart';

void main() {
  test('root is null until the root component arrives', () {
    final processor = testProcessor()..apply([createPlanSurface()]);

    expect(processor.surface('plan')!.root, isNull);
  });

  test('the surface notifies when the root component arrives', () {
    final processor = testProcessor()..apply([createPlanSurface()]);
    var notified = 0;
    processor.surface('plan')!.addListener(() => notified += 1);

    processor.apply([updatePlanComponents()]);

    expect(notified, 1);
  });

  test('root has the id root', () {
    final surface = planSurface();

    expect(surface.root!.id, 'root');
  });

  test("root has its component's type", () {
    final surface = planSurface();

    expect(surface.root!.type, 'Column');
  });

  test('root is the same node each time it is asked for', () {
    final surface = planSurface();

    expect(surface.root, same(surface.root));
  });

  test('the surface notifies when the root component is replaced', () {
    final processor = testProcessor()..apply([createPlanSurface(), updatePlanComponents()]);
    final surface = processor.surface('plan')!;
    var notified = 0;
    surface.addListener(() => notified += 1);

    processor.apply([
      updatePlanComponents(
        components: [
          {'id': 'root', 'component': 'Text', 'text': 'Replaced'},
        ],
      ),
    ]);

    // A root of another type is removed, then added: two changes.
    expect(notified, 2);
  });

  test('root is the replacing component once the root is replaced', () {
    final processor = testProcessor()..apply([createPlanSurface(), updatePlanComponents()]);
    final surface = processor.surface('plan')!;

    processor.apply([
      updatePlanComponents(
        components: [
          {'id': 'root', 'component': 'Text', 'text': 'Replaced'},
        ],
      ),
    ]);

    expect(surface.root!.type, 'Text');
  });

  test('root is null once the surface is deleted', () {
    final processor = testProcessor()..apply([createPlanSurface(), updatePlanComponents()]);
    final surface = processor.surface('plan')!;

    processor.apply([deletePlanSurface()]);

    expect(surface.root, isNull);
  });
}
