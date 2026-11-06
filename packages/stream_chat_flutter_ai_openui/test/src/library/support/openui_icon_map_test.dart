import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_icon_map.dart';
import 'package:stream_core_flutter/core.dart';

void main() {
  final icons = StreamTheme.light().icons;

  group('openUIIconOf', () {
    test('finds a name in any case with spaces around it', () {
      expect(openUIIconOf(icons, '  Arrow-Right '), icons.arrowRight);
    });

    test('drops the numeric parts of a name, and then its last parts one at a time', () {
      expect(openUIIconOf(icons, 'trash-2-x'), icons.delete);
      expect(openUIIconOf(icons, 'arrow-up-right-big-thing'), icons.arrowUpRight);
    });

    test('finds the icon of a category when the name finds none, and none for an unknown category', () {
      expect(openUIIconOf(icons, 'zzz', 'Mail'), icons.send);
      expect(openUIIconOf(icons, 'zzz', 'nope'), isNull);
      expect(openUIIconOf(icons, 'zzz'), isNull);
    });

    test('looks no further than a name of 64 characters', () {
      expect(openUIIconOf(icons, 'check-${'x' * 70}'), isNull);
    });
  });

  group('openUIIconLabel', () {
    test('reads the name without its numeric parts', () {
      expect(openUIIconLabel('Trash-2'), 'trash');
      expect(openUIIconLabel('arrow_up.right'), 'arrow up right');
    });

    test('has no label when nothing is left', () {
      expect(openUIIconLabel('2'), isNull);
      expect(openUIIconLabel(''), isNull);
    });
  });
}
