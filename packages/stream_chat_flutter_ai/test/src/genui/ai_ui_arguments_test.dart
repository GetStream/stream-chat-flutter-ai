import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'genui_fixtures.dart';

void main() {
  test("AIUIArguments reads a place card's arguments by the names of its parameters", () {
    final arguments = AIUIArguments(genuiFixture('arguments_place_card.json'));

    final read = [arguments.string('title'), arguments.date('visit_on'), arguments.strings('tags')];

    expect(read, [
      'St. Naum',
      DateTime(2026, 11, 14),
      ['sight', 'nature'],
    ]);
  });

  test('AIUIArguments.objects reads an array of objects, each by its own keys', () {
    final arguments = AIUIArguments(genuiFixture('arguments_trip_map.json'));

    final places = [
      for (final place in arguments.objects('places'))
        (place.string('name'), place.number('latitude'), place.number('longitude')),
    ];

    expect(places, [('Ohrid', 41.1172, 20.8016), ('St. Naum', 40.9139, 20.7414)]);
  });

  test('AIUIArguments.object reads a nested object, dates included', () {
    final arguments = _everyType();

    final stay = arguments.object('stay');

    expect([stay.string('name'), stay.date('check_in')], ['Villa Mal Sveti Kliment', DateTime(2026, 11, 14)]);
  });

  test('AIUIArguments.number reads a whole number as a double', () {
    expect(_everyType().number('budget_whole'), 420.0);
  });

  test('AIUIArguments.integer reads a number written with a zero fraction', () {
    expect(_everyType().integer('nights_written_whole'), 3);
  });

  test('AIUIArguments.integer throws for a number with a fraction', () {
    expect(() => _everyType().integer('nights_with_fraction'), throwsFormatException);
  });

  test('AIUIArguments.integer throws for a whole number too large for an int', () {
    expect(() => _everyType().integer('nights_far_too_many'), throwsFormatException);
  });

  test('AIUIArguments.boolean reads true or false', () {
    expect(_everyType().boolean('is_flexible'), isTrue);
  });

  test('AIUIArguments.url reads a link', () {
    expect(_everyType().url('photo'), Uri.parse('https://upload.wikimedia.org/ohrid.jpg'));
  });

  test('AIUIArguments.url throws for an empty string', () {
    expect(() => _everyType().url('no_photo'), throwsFormatException);
  });

  test('AIUIArguments throws for an argument the agent left out', () {
    expect(() => _everyType().string('subtitle'), throwsFormatException);
  });

  test('AIUIArguments throws for an argument the agent wrote as null', () {
    expect(() => _everyType().string('note'), throwsFormatException);
  });

  final otherTypes = <(String, Object? Function(AIUIArguments arguments))>[
    ('a number read as a string', (arguments) => arguments.string('nights')),
    ('a string read as a number', (arguments) => arguments.number('title')),
    ('a string read as a whole number', (arguments) => arguments.integer('title')),
    ('a string read as true or false', (arguments) => arguments.boolean('title')),
    ('a number read as a date', (arguments) => arguments.date('nights')),
    ('a number read as a link', (arguments) => arguments.url('nights')),
    ('an array read as an object', (arguments) => arguments.object('tags')),
  ];
  for (final (argument, read) in otherTypes) {
    test('AIUIArguments throws for $argument', () {
      expect(() => read(_everyType()), throwsFormatException);
    });
  }

  test('AIUIArguments.optional reads null for an argument left out', () {
    final arguments = _everyType();

    expect(arguments.optional('subtitle', arguments.string), isNull);
  });

  test('AIUIArguments.optional reads null for an argument written as null', () {
    final arguments = _everyType();

    expect(arguments.optional('note', arguments.string), isNull);
  });

  test('AIUIArguments.optional reads an argument that is there', () {
    final arguments = _everyType();

    expect(arguments.optional('nights', arguments.integer), 3);
  });

  test('AIUIArguments.optional still throws for an argument of another type', () {
    final arguments = _everyType();

    expect(() => arguments.optional('title', arguments.integer), throwsFormatException);
  });

  test('AIUIArguments keeps a copy, so changing the JSON afterwards changes nothing', () {
    final json = <String, Object?>{
      'tags': ['sight'],
    };
    final arguments = AIUIArguments(json);

    (json['tags']! as List<Object?>).add('food');

    expect(arguments.strings('tags'), ['sight']);
  });

  test('AIUIArguments with the same JSON are equal', () {
    expect(_everyType(), _everyType());
  });

  test("AIUIArguments.toString leaves out the agent's values", () {
    final arguments = AIUIArguments(genuiFixture('arguments_place_card.json'));

    expect(arguments.toString(), isNot(contains('St. Naum')));
  });
}

AIUIArguments _everyType() => AIUIArguments(genuiFixture('arguments_every_type.json'));
