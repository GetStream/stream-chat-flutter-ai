import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_icon_map.dart';
import 'package:stream_core_flutter/core.dart';

const _generic = Icons.circle_outlined;

void main() {
  final icons = StreamTheme.light().icons;

  group('openUIIconOf', () {
    test('finds a name in any case with spaces around it', () {
      expect(openUIIconOf(icons, '  Arrow-Right '), icons.arrowRight);
    });

    test('drops the numeric parts of a name, and then its last parts one at a time', () {
      expect(openUIIconOf(icons, 'trash-2-big'), icons.delete);
      expect(openUIIconOf(icons, 'arrow-up-right-big-thing'), icons.arrowUpRight);
    });

    test('finds the icons of names that mean the opposite of a shorter one', () {
      expect(openUIIconOf(icons, 'lock-open'), icons.unlock);
      expect(openUIIconOf(icons, 'mic-off'), icons.voiceOffFill);
      expect(openUIIconOf(icons, 'video-off'), icons.videoOffFill);
      expect(openUIIconOf(icons, 'phone-off'), icons.phoneDownFill);
      expect(openUIIconOf(icons, 'bell-off'), icons.bellOff);
      expect(openUIIconOf(icons, 'folder-open'), icons.folder);
    });

    test('draws no shorter icon for a name with an off, open, x or minus part', () {
      expect(openUIIconOf(icons, 'eye-off'), _generic);
      expect(openUIIconOf(icons, 'lock-keyhole-off'), _generic);
      expect(openUIIconOf(icons, 'user-open'), _generic);
      expect(openUIIconOf(icons, 'trash-x'), _generic);
      expect(openUIIconOf(icons, 'user-circle-minus'), _generic);
      expect(openUIIconOf(icons, 'eye-off', 'security'), icons.shield);
    });

    test('finds the icon of a category when the name finds none, and a generic one for an unknown category', () {
      expect(openUIIconOf(icons, 'zzz', 'Mail'), icons.send);
      expect(openUIIconOf(icons, 'zzz', 'nope'), _generic);
      expect(openUIIconOf(icons, 'zzz'), _generic);
    });

    test('finds an icon for the category of every one of the categories', () {
      const categories = [
        'accessibility',
        'account',
        'arrows',
        'buildings',
        'charts',
        'communication',
        'development',
        'files',
        'finance',
        'layout',
        'mail',
        'notifications',
        'people',
        'photography',
        'security',
        'social',
        'sports',
        'text',
        'time',
        'navigation',
        'multimedia',
        'devices',
        'tools',
        'weather',
      ];
      for (final category in categories) {
        expect(openUIIconOf(icons, 'zzz', category), isNot(_generic), reason: category);
      }
    });

    test('maps the names the design system has an icon for', () {
      expect(openUIIconOf(icons, 'paperclip'), icons.attachment);
      expect(openUIIconOf(icons, 'sun'), icons.lightMode);
      expect(openUIIconOf(icons, 'moon'), icons.darkMode);
      expect(openUIIconOf(icons, 'chart-line'), icons.statsFill);
      expect(openUIIconOf(icons, 'chart-pie'), icons.statsFill);
    });

    test('looks no further than a name of 64 characters', () {
      expect(openUIIconOf(icons, 'check-${'x' * 70}'), _generic);
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
