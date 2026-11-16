import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_json.dart';

void main() {
  group('openUIPlainJson', () {
    test('gives a whole number as an int', () {
      final json = openUIPlainJson(const OpenUINumber(2));

      expect(json, isA<int>());
      expect(json, 2);
    });

    test('keeps a fraction as a double', () {
      expect(openUIPlainJson(const OpenUINumber(1.5)), 1.5);
    });

    test('gives -0 as the int 0', () {
      // -0.0 written as an int literal would be 0.
      // ignore: prefer_int_literals
      expect(openUIPlainJson(const OpenUINumber(-0.0)), isA<int>());
    });

    test('keeps a whole number past 2^53 - 1 as a double', () {
      expect(openUIPlainJson(const OpenUINumber(9007199254740992)), isA<double>());
      expect(openUIPlainJson(const OpenUINumber(-9007199254740991)), isA<int>());
    });

    test('gives a number that is not finite as null', () {
      expect(openUIPlainJson(const OpenUINumber(double.nan)), isNull);
      expect(openUIPlainJson(const OpenUINumber(double.infinity)), isNull);
    });

    test('gives the whole numbers inside lists and maps as ints', () {
      final json = openUIPlainJson(
        OpenUIObject({
          'list': OpenUIArray(const [OpenUINumber(3)]),
        }),
      );

      expect((json! as Map)['list'], [isA<int>()]);
    });

    test('gives a component as its JSON shape', () {
      final card = ElementNode(
        typeName: 'CardHeader',
        props: const {'title': OpenUIString('A')},
        partial: false,
        hasDynamicProps: false,
      );

      final json = openUIPlainJson(OpenUIArray([OpenUIElement(card)]));

      expect((json! as List).single, containsPair('typeName', 'CardHeader'));
    });
  });
}
