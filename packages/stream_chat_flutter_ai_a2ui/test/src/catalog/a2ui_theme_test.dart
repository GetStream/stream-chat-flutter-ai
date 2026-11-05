import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

void main() {
  test('heading 1 is the first heading style', () {
    expect(_theme().heading(1), _h1());
  });

  test('heading 3 is the third heading style', () {
    expect(_theme().heading(3), _h3());
  });

  test('a level below 1 gives the first heading style', () {
    expect(_theme().heading(0), _h1());
  });

  test('a level past the last gives the last heading style', () {
    expect(_theme().heading(9), _h3());
  });

  test('a theme with no heading styles asserts', () {
    expect(() => _theme(headings: const []), throwsAssertionError);
  });

  test('changing the heading styles a theme was made with leaves the theme as it was', () {
    final headings = [_h1(), _h2(), _h3()];
    final theme = _theme(headings: headings);
    final hashCode = theme.hashCode;

    headings.clear();

    expect(theme.headings, [_h1(), _h2(), _h3()]);
    expect(theme.hashCode, hashCode);
  });

  test("a theme's heading styles can't be changed", () {
    expect(() => _theme().headings.add(_h1()), throwsUnsupportedError);
  });

  for (final field in _fields()) {
    test('copyWith replaces the ${field.name}', () {
      expect(field.read(field.replace(_theme())), field.other);
    });

    test('copyWith of the ${field.name} keeps the other values', () {
      final theme = _theme();
      final copy = field.replace(theme);

      for (final kept in _fields().where((it) => it.name != field.name)) {
        expect(kept.read(copy), kept.read(theme), reason: kept.name);
      }
    });

    test('themes with another ${field.name} are not equal', () {
      expect(field.replace(_theme()), isNot(_theme()));
    });

    test('themes with another ${field.name} have another hash code', () {
      expect(field.replace(_theme()).hashCode, isNot(_theme().hashCode));
    });
  }

  test('copyWith with nothing is equal to the theme', () {
    expect(_theme().copyWith(), _theme());
  });

  test('themes with the same values are equal', () {
    expect(_theme(), _theme());
  });

  test('themes with the same values have the same hash code', () {
    expect(_theme().hashCode, _theme().hashCode);
  });

  test('themes with equal heading lists in different list objects are equal', () {
    expect(_theme(headings: [_h1(), _h2(), _h3()]), _theme(headings: [_h1(), _h2(), _h3()]));
  });

  test('themes with equal heading lists in different list objects have the same hash code', () {
    expect(_theme(headings: [_h1(), _h2(), _h3()]).hashCode, _theme(headings: [_h1(), _h2(), _h3()]).hashCode);
  });
}

TextStyle _body() => const TextStyle(fontSize: 17);
TextStyle _h1() => const TextStyle(fontSize: 28);
TextStyle _h2() => const TextStyle(fontSize: 22);
TextStyle _h3() => const TextStyle(fontSize: 20);

// A theme whose values all differ from each other, so a value read from the
// wrong field shows.
A2UITheme _theme({List<TextStyle>? headings}) {
  return A2UITheme(
    accent: Colors.blue,
    onAccent: Colors.white,
    text: Colors.black,
    secondaryText: Colors.grey,
    surface: const Color(0xFFFAFAFA),
    subtleSurface: Colors.white70,
    border: Colors.black12,
    error: Colors.red,
    warning: Colors.orange,
    body: _body(),
    caption: const TextStyle(fontSize: 12),
    label: const TextStyle(fontSize: 15),
    headings: headings ?? [_h1(), _h2(), _h3()],
    cornerRadius: 16,
    buttonCornerRadius: 9999,
    controlCornerRadius: 12,
  );
}

// One value of a theme: its name, how to read it, a value none of [_theme]'s
// values has, and how to copy a theme with that value in its place.
typedef _Field = ({
  String name,
  Object? Function(A2UITheme theme) read,
  Object? other,
  A2UITheme Function(A2UITheme theme) replace,
});

// Every value of a theme.
List<_Field> _fields() {
  const color = Colors.purple;
  const style = TextStyle(fontSize: 99);
  const radius = 3.0;
  final headings = [_h1()];
  return [
    (name: 'accent', read: (it) => it.accent, other: color, replace: (it) => it.copyWith(accent: color)),
    (name: 'onAccent', read: (it) => it.onAccent, other: color, replace: (it) => it.copyWith(onAccent: color)),
    (name: 'text', read: (it) => it.text, other: color, replace: (it) => it.copyWith(text: color)),
    (
      name: 'secondaryText',
      read: (it) => it.secondaryText,
      other: color,
      replace: (it) => it.copyWith(secondaryText: color),
    ),
    (name: 'surface', read: (it) => it.surface, other: color, replace: (it) => it.copyWith(surface: color)),
    (
      name: 'subtleSurface',
      read: (it) => it.subtleSurface,
      other: color,
      replace: (it) => it.copyWith(subtleSurface: color),
    ),
    (name: 'border', read: (it) => it.border, other: color, replace: (it) => it.copyWith(border: color)),
    (name: 'error', read: (it) => it.error, other: color, replace: (it) => it.copyWith(error: color)),
    (name: 'warning', read: (it) => it.warning, other: color, replace: (it) => it.copyWith(warning: color)),
    (name: 'body', read: (it) => it.body, other: style, replace: (it) => it.copyWith(body: style)),
    (name: 'caption', read: (it) => it.caption, other: style, replace: (it) => it.copyWith(caption: style)),
    (name: 'label', read: (it) => it.label, other: style, replace: (it) => it.copyWith(label: style)),
    (name: 'headings', read: (it) => it.headings, other: headings, replace: (it) => it.copyWith(headings: headings)),
    (
      name: 'cornerRadius',
      read: (it) => it.cornerRadius,
      other: radius,
      replace: (it) => it.copyWith(cornerRadius: radius),
    ),
    (
      name: 'buttonCornerRadius',
      read: (it) => it.buttonCornerRadius,
      other: radius,
      replace: (it) => it.copyWith(buttonCornerRadius: radius),
    ),
    (
      name: 'controlCornerRadius',
      read: (it) => it.controlCornerRadius,
      other: radius,
      replace: (it) => it.copyWith(controlCornerRadius: radius),
    ),
  ];
}
