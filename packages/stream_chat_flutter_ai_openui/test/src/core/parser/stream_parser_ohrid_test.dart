import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_test_interface.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_stream_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';

// The Ohrid weekend example of the Stream agent backend's prompt, read with the
// chat library plus the app's three components (test/fixtures/README.md), as
// it streams in.
void main() {
  for (final (label, pieces) in [
    ('one code unit at a time', _byCodeUnit),
    ('a line at a time', _byLine),
    ('in random pieces', _byRandomPieces),
  ]) {
    test('the Ohrid example read $label never throws', () {
      expect(() => _stream(pieces(_text())), returnsNormally);
    });

    test('the Ohrid example read $label ends as it reads in one piece', () {
      final whole = OpenUILangParser(_library()).parse(_text());

      expect(jsonEncode(parseResultJson(_stream(pieces(_text())))), jsonEncode(parseResultJson(whole)));
    });
  }

  test('the Ohrid example read a line at a time ends with no errors', () {
    expect(_stream(_byLine(_text())).meta.errors, isEmpty);
  });

  test('the Ohrid example read a line at a time ends with nothing unresolved or orphaned', () {
    final meta = _stream(_byLine(_text())).meta;

    expect([...meta.unresolved, ...meta.orphaned], isEmpty);
  });

  test('the Ohrid example renders its root while it streams', () {
    final parser = OpenUIStreamParser(_library());
    final lines = _byLine(_text());
    parser.set(lines.take(lines.length ~/ 2).join());

    expect(parser.result().root?.typeName, 'Card');
  });
}

const _seed = 1173;
const _maxPiece = 12;

String _text() => File('test/fixtures/ohrid_prompt_example.oui').readAsStringSync();

List<String> _byCodeUnit(String text) => [for (final unit in text.codeUnits) String.fromCharCode(unit)];

List<String> _byLine(String text) => [for (final line in text.split('\n')) '$line\n'];

List<String> _byRandomPieces(String text) {
  final random = Random(_seed);
  final pieces = <String>[];
  var start = 0;
  while (start < text.length) {
    final end = min(text.length, start + 1 + random.nextInt(_maxPiece));
    pieces.add(text.substring(start, end));
    start = end;
  }
  return pieces;
}

ParseResult _stream(List<String> pieces) {
  final parser = OpenUIStreamParser(_library());
  for (final piece in pieces) {
    parser.push(piece);
  }
  return parser.result(complete: true);
}

// The chat library with the Ohrid app's components added, as an app adds
// them.
OpenUILibrarySchema _library() {
  final decoded = jsonDecode(File('test/fixtures/ohrid_app_components.json').readAsStringSync()) as List<Object?>;
  final definitions = [for (final definition in decoded) definition! as Map<String, Object?>];
  final components = [for (final (_, schema) in placeableComponents(LibraryDefinition.chat, definitions)) schema];
  return LibraryDefinition.chat.addingContent(components).schema;
}
