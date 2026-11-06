import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';

// A value for each field of A2UIThemeData, and one that differs from it.
final _fields =
    <
      ({
        String name,
        A2UIThemeData Function() one,
        A2UIThemeData Function() other,
        Object? Function(A2UIThemeData) read,
      })
    >[
      (
        name: 'accent',
        one: () => A2UIThemeData(accent: _a),
        other: () => A2UIThemeData(accent: _b),
        read: (t) => t.accent,
      ),
      (
        name: 'onAccent',
        one: () => A2UIThemeData(onAccent: _a),
        other: () => A2UIThemeData(onAccent: _b),
        read: (t) => t.onAccent,
      ),
      (name: 'text', one: () => A2UIThemeData(text: _a), other: () => A2UIThemeData(text: _b), read: (t) => t.text),
      (
        name: 'secondaryText',
        one: () => A2UIThemeData(secondaryText: _a),
        other: () => A2UIThemeData(secondaryText: _b),
        read: (t) => t.secondaryText,
      ),
      (
        name: 'surface',
        one: () => A2UIThemeData(surface: _a),
        other: () => A2UIThemeData(surface: _b),
        read: (t) => t.surface,
      ),
      (
        name: 'subtleSurface',
        one: () => A2UIThemeData(subtleSurface: _a),
        other: () => A2UIThemeData(subtleSurface: _b),
        read: (t) => t.subtleSurface,
      ),
      (
        name: 'border',
        one: () => A2UIThemeData(border: _a),
        other: () => A2UIThemeData(border: _b),
        read: (t) => t.border,
      ),
      (name: 'error', one: () => A2UIThemeData(error: _a), other: () => A2UIThemeData(error: _b), read: (t) => t.error),
      (
        name: 'warning',
        one: () => A2UIThemeData(warning: _a),
        other: () => A2UIThemeData(warning: _b),
        read: (t) => t.warning,
      ),
      (
        name: 'body',
        one: () => A2UIThemeData(body: _small),
        other: () => A2UIThemeData(body: _large),
        read: (t) => t.body,
      ),
      (
        name: 'caption',
        one: () => A2UIThemeData(caption: _small),
        other: () => A2UIThemeData(caption: _large),
        read: (t) => t.caption,
      ),
      (
        name: 'label',
        one: () => A2UIThemeData(label: _small),
        other: () => A2UIThemeData(label: _large),
        read: (t) => t.label,
      ),
      (
        name: 'headings',
        one: () => A2UIThemeData(headings: const [_small]),
        other: () => A2UIThemeData(headings: const [_large]),
        read: (t) => t.headings,
      ),
      (
        name: 'cornerRadius',
        one: () => A2UIThemeData(cornerRadius: 2),
        other: () => A2UIThemeData(cornerRadius: 4),
        read: (t) => t.cornerRadius,
      ),
      (
        name: 'buttonCornerRadius',
        one: () => A2UIThemeData(buttonCornerRadius: 2),
        other: () => A2UIThemeData(buttonCornerRadius: 4),
        read: (t) => t.buttonCornerRadius,
      ),
      (
        name: 'controlCornerRadius',
        one: () => A2UIThemeData(controlCornerRadius: 2),
        other: () => A2UIThemeData(controlCornerRadius: 4),
        read: (t) => t.controlCornerRadius,
      ),
    ];

const _a = Color(0xFF000000);
const _b = Color(0xFFFFFFFF);
const _small = TextStyle(fontSize: 10);
const _large = TextStyle(fontSize: 20);

void main() {
  for (final field in _fields) {
    test('merge takes the ${field.name} the other theme sets', () {
      expect(field.read(field.one().merge(field.other())), field.read(field.other()));
    });

    test("merge keeps the ${field.name} when the other theme doesn't set it", () {
      expect(field.read(field.one().merge(const A2UIThemeData.empty())), field.read(field.one()));
    });

    test('copyWith of nothing keeps the ${field.name}', () {
      expect(field.read(field.one().copyWith()), field.read(field.one()));
    });

    test('themes with another ${field.name} are not equal', () {
      expect(field.one(), isNot(field.other()));
    });

    test('themes with another ${field.name} have another hash code', () {
      expect(field.one().hashCode, isNot(field.other().hashCode));
    });

    test('lerp switches the ${field.name} only one theme sets at the midpoint', () {
      const empty = A2UIThemeData.empty();
      expect(field.read(A2UIThemeData.lerp(field.one(), empty, 0.4)), field.read(field.one()));
      expect(field.read(A2UIThemeData.lerp(field.one(), empty, 0.6)), isNull);
    });
  }

  test('merge with null is the theme itself', () {
    final theme = A2UIThemeData(accent: _a);

    expect(theme.merge(null), same(theme));
  });

  test('an empty theme sets nothing', () {
    expect(const A2UIThemeData.empty(), A2UIThemeData());
  });

  test('lerp blends colors both themes set', () {
    final blended = A2UIThemeData.lerp(A2UIThemeData(accent: _a), A2UIThemeData(accent: _b), 0.5);

    expect(blended.accent, Color.lerp(_a, _b, 0.5));
  });

  test('lerp blends radii both themes set', () {
    final blended = A2UIThemeData.lerp(A2UIThemeData(cornerRadius: 2), A2UIThemeData(cornerRadius: 4), 0.5);

    expect(blended.cornerRadius, 3);
  });

  test('lerp blends heading lists of the same length style by style', () {
    final blended = A2UIThemeData.lerp(
      A2UIThemeData(headings: const [_small]),
      A2UIThemeData(headings: const [_large]),
      0.5,
    );

    expect(blended.headings!.single.fontSize, 15);
  });

  test('a theme with no heading styles asserts', () {
    expect(() => A2UIThemeData(headings: const []), throwsAssertionError);
  });

  test('changing the heading styles a theme was made with leaves the theme as it was', () {
    final headings = [_small];
    final theme = A2UIThemeData(headings: headings);
    headings[0] = _large;

    expect(theme.headings, [_small]);
  });

  test("a theme's heading styles can't be changed", () {
    expect(() => A2UIThemeData(headings: const [_small]).headings![0] = _large, throwsUnsupportedError);
  });

  test('themes with equal heading lists in different list objects are equal and hash alike', () {
    final one = A2UIThemeData(headings: List.of(const [_small]));
    final other = A2UIThemeData(headings: List.of(const [_small]));

    expect(one, other);
    expect(one.hashCode, other.hashCode);
  });

  testWidgets('of gives an empty theme with no A2UITheme above', (tester) async {
    late A2UIThemeData read;
    await tester.pumpWidget(Builder(builder: (context) => _read(context, (theme) => read = theme)));

    expect(read, const A2UIThemeData.empty());
  });

  testWidgets('of gives the nearest A2UITheme', (tester) async {
    late A2UIThemeData read;
    await tester.pumpWidget(
      A2UITheme(
        data: A2UIThemeData(accent: _a),
        child: A2UITheme(
          data: A2UIThemeData(cornerRadius: 4),
          child: Builder(builder: (context) => _read(context, (theme) => read = theme)),
        ),
      ),
    );

    expect(read, A2UIThemeData(cornerRadius: 4));
  });

  testWidgets('merge layers over the enclosing A2UITheme', (tester) async {
    late A2UIThemeData read;
    await tester.pumpWidget(
      A2UITheme(
        data: A2UIThemeData(accent: _a),
        child: A2UITheme.merge(
          data: A2UIThemeData(cornerRadius: 4),
          child: Builder(builder: (context) => _read(context, (theme) => read = theme)),
        ),
      ),
    );

    expect(read, A2UIThemeData(accent: _a, cornerRadius: 4));
  });
}

Widget _read(BuildContext context, void Function(A2UIThemeData theme) onRead) {
  onRead(A2UITheme.of(context));
  return const SizedBox();
}
