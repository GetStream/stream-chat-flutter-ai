import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import '../a2ui_test_app.dart';

void main() {
  test('the basic catalog has the eighteen components this package draws', () {
    expect(A2UICatalog.basic.types.toSet(), {
      'Text',
      'Image',
      'Icon',
      'Video',
      'AudioPlayer',
      'Row',
      'Column',
      'List',
      'Card',
      'Divider',
      'Tabs',
      'Modal',
      'Button',
      'TextField',
      'CheckBox',
      'ChoicePicker',
      'Slider',
      'DateTimeInput',
    });
  });

  test('a type the catalog does not have has no builder', () {
    expect(A2UICatalog.basic['Calendar'], isNull);
  });

  testWidgets('a replaced builder draws the components of its type', (tester) async {
    final catalog = A2UICatalog.basic.replacing('Text', (context, scope) => const Text('replaced'));

    await pumpSurface(tester, components: [_text], catalog: catalog);

    expect(find.text('replaced'), findsOneWidget);
  });

  test('replacing a type the catalog does not have asserts', () {
    expect(
      () => A2UICatalog.basic.replacing('Calendar', (context, scope) => const SizedBox()),
      throwsA(
        isA<AssertionError>().having(
          (error) => error.message,
          'message',
          startsWith("A2UICatalog has no builder for 'Calendar' to replace."),
        ),
      ),
    );
  });

  test('removing a type the catalog does not have asserts', () {
    expect(
      () => A2UICatalog.basic.removing(['Text', 'Txt']),
      throwsA(
        isA<AssertionError>().having(
          (error) => error.message,
          'message',
          startsWith('A2UICatalog has no builder for Txt to remove.'),
        ),
      ),
    );
  });

  testWidgets('a removed type shows nothing', (tester) async {
    await pumpSurface(tester, components: [_text], catalog: A2UICatalog.basic.removing(['Text']));

    expect(find.text('Ohrid'), findsNothing);
  });

  test('a removed type has no builder', () {
    expect(A2UICatalog.basic.removing(['Text'])['Text'], isNull);
  });

  test('removing keeps the other types', () {
    expect(A2UICatalog.basic.removing(['Text']).types, hasLength(17));
  });

  test('catalogs with the same builders are equal', () {
    expect(A2UICatalog.basic.removing(['Text']), A2UICatalog.basic.removing(['Text']));
  });

  test('catalogs with the same builders have the same hash code', () {
    expect(A2UICatalog.basic.removing(['Text']).hashCode, A2UICatalog.basic.removing(['Text']).hashCode);
  });

  test('catalogs with another builder for a type are not equal', () {
    expect(A2UICatalog.basic.replacing('Text', (context, scope) => const SizedBox()), isNot(A2UICatalog.basic));
  });
}

const _text = {'id': 'root', 'component': 'Text', 'text': 'Ohrid'};
