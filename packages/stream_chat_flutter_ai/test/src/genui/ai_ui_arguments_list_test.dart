import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'genui_fixtures.dart';

void main() {
  test('AIUIArguments.strings reads an array of strings', () {
    expect(_everyType().strings('tags'), ['sight', 'food']);
  });

  test('AIUIArguments.strings throws when an item is not a string', () {
    expect(() => _everyType().strings('tags_mixed'), throwsFormatException);
  });

  test('AIUIArguments.numbers reads whole numbers among them as numbers too', () {
    expect(_everyType().numbers('coordinates'), [41.0, 20.8016]);
  });

  test('AIUIArguments.integers reads numbers written with a zero fraction', () {
    expect(_everyType().integers('nights_per_stay'), [2, 3]);
  });

  test('AIUIArguments.integers throws when an item has a fraction', () {
    expect(() => _everyType().integers('nights_per_stay_mixed'), throwsFormatException);
  });

  test('AIUIArguments.booleans reads an array of true or false', () {
    expect(_everyType().booleans('flags'), [true, false]);
  });

  test('AIUIArguments.dates reads each item as a day or a moment', () {
    expect(_everyType().dates('days'), [DateTime(2026, 11, 14), DateTime.utc(2026, 11, 15, 9, 30)]);
  });

  test('AIUIArguments.urls reads an array of links', () {
    expect(_everyType().urls('photos'), [Uri.parse('https://upload.wikimedia.org/ohrid.jpg')]);
  });

  test('AIUIArguments.objects reads an array of objects', () {
    expect([for (final place in _everyType().objects('places')) place.string('name')], ['Ohrid', 'St. Naum']);
  });

  test('AIUIArguments.objects throws when an item is not an object', () {
    expect(() => _everyType().objects('places_mixed'), throwsFormatException);
  });

  test('AIUIArguments throws when an array argument is not an array', () {
    expect(() => _everyType().strings('title'), throwsFormatException);
  });
}

AIUIArguments _everyType() => AIUIArguments(genuiFixture('arguments_every_type.json'));
