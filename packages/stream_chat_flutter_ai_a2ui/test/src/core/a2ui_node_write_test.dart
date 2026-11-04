import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';

import 'a2ui_test_surfaces.dart';

void main() {
  test('canWrite is true for a property bound to the data model', () {
    final email = rootChild(planSurface(), 'email');

    expect(email.canWrite('value'), isTrue);
  });

  test('canWrite is false for a literal property', () {
    final title = rootChild(planSurface(), 'title');

    expect(title.canWrite('text'), isFalse);
  });

  test('write changes the data model path the property is bound to', () {
    final surface = planSurface();

    rootChild(surface, 'email').write('value', 'other@example.com');

    expect(surface.read('/email'), 'other@example.com');
  });

  test("write does nothing for a property that isn't bound", () {
    final title = rootChild(planSurface(), 'title')..write('text', 'Something else');

    expect(title.property('text'), 'A weekend in Ohrid');
  });

  test("write reports a path that can't be written", () {
    final errors = <A2UIError>[];
    final surface = planSurface(
      components: [
        {
          'id': 'root',
          'component': 'TextField',
          'label': 'First name',
          'value': {'@path': '/name/first'},
        },
      ],
      data: {'name': 'Ana'},
      errors: errors,
    );

    surface.root!.write('value', 'Ana');

    expect(errors.single.code, A2UIErrorCode.dataError);
  });
}
