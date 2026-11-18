import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_test_interface.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_stream_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';

// A long reply of many statements, read in many small pieces.
void main() {
  test('a long reply read in many pieces ends as it reads in one piece', () {
    final program = _longProgram();
    final parser = OpenUIStreamParser(_chat());
    final size = program.length ~/ _pieceCount + 1;
    var end = 0;
    ParseResult? last;
    while (end < program.length) {
      end = min(program.length, end + size);
      last = parser.set(program.substring(0, end), complete: end == program.length);
    }
    final whole = OpenUILangParser(_chat()).parse(program);

    expect(jsonEncode(parseResultJson(last!)), jsonEncode(parseResultJson(whole)));
  });

  test('the long reply has its statements', () {
    final whole = OpenUILangParser(_chat()).parse(_longProgram());

    expect(whole.meta.statementCount, _statements + 2);
  });
}

const _statements = 300;
const _pieceCount = 3000;

// A Card of [_statements] texts, each its own statement, with the root first.
String _longProgram() {
  final names = [for (var index = 0; index < _statements; index += 1) 't$index'];
  return [
    'root = Card([header, ${names.join(', ')}])',
    'header = CardHeader("Report", "All the rows")',
    for (final (index, name) in names.indexed) '$name = TextContent("Row $index of the long report")',
  ].join('\n');
}

OpenUILibrarySchema _chat() => LibraryDefinition.chat.schema;
