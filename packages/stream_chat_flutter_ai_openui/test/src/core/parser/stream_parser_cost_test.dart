import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_stream_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/upstream_shape.dart';

// What reading a long reply in many small pieces costs. Each test streams the
// same reply of many statements and checks that a count of the work done
// grows with the reply, not with the reply times the number of pieces.
void main() {
  test('preparing a long reply read in many pieces reads each code unit a bounded number of times', () {
    final run = _streamLongReply();

    expect(run.parser.debugPreparedCodeUnits, lessThan(_preparedFactor * run.program.length));
  });

  test('finding the finished statements of a long reply reads each code unit once', () {
    final run = _streamLongReply();

    expect(run.parser.debugScannedCodeUnits, run.program.length);
  });

  test('each piece before the end of a long reply resolves only the root and the statement still arriving', () {
    final run = _streamLongReply();

    expect(run.maxResolvedPerPiece, lessThan(_nodesPerPiece));
  });

  test('a long reply read in many pieces ends as it reads in one piece', () {
    final run = _streamLongReply();
    final whole = OpenUILangParser(_chat()).parse(run.program);

    expect(jsonEncode(parseResultJson(run.last)), jsonEncode(parseResultJson(whole)));
  });

  test('one 48 KB statement read in pieces of five code units is read again a bounded number of times', () {
    final rows = [for (var row = 0; row < _tableRows; row += 1) '["Row $row", ${row * 3}, "note $row"]'];
    final program = 'root = Card([Table([Col("A"), Col("B"), Col("C")], [${rows.join(', ')}])])';
    final parser = OpenUIStreamParser(_chat());

    // Every piece is read until the statement is long, then once per eighth
    // it grows: about 400 + 30 reads, where every piece would be over 9,000.
    expect(_builds(parser, program), lessThan(OpenUIStreamParser.longStatement ~/ _smallPiece + _rereadsAfterLong));
  });

  test('a reply of 1,000 statements read in pieces of five code units is built a bounded number of times', () {
    final names = [for (var index = 0; index < _manyStatementCount; index += 1) 't$index'];
    final program = [
      'root = Card([${names.join(', ')}])',
      for (final (index, name) in names.indexed) '$name = TextContent("Row $index of the report")',
    ].join('\n');
    final parser = OpenUIStreamParser(_chat());

    // Every piece builds until 256 statements have finished, then once per
    // sixty-fourth of growth: about 2,700 builds, where every piece would be
    // about 9,900.
    expect(_builds(parser, program), lessThan(_manyStatementBuilds));
  });

  test('the 48 KB statement of the cost test is that long', () {
    final rows = [for (var row = 0; row < _tableRows; row += 1) '["Row $row", ${row * 3}, "note $row"]'];

    expect(rows.join(', ').length, greaterThan(48000));
  });

  test('the long reply has its statements, so the cost tests read a long reply', () {
    final whole = OpenUILangParser(_chat()).parse(_longProgram());

    expect(whole.meta.statementCount, _statements + 2);
  });
}

const _statements = 300;
const _pieceCount = 3000;
const _preparedFactor = 20;
const _nodesPerPiece = 500;
const _tableRows = 1900;
const _smallPiece = 5;
const _rereadsAfterLong = 40;
const _manyStatementCount = 1000;
const _manyStatementBuilds = 3000;

// A Card of [_statements] texts, each its own statement, with the root first.
String _longProgram() {
  final names = [for (var index = 0; index < _statements; index += 1) 't$index'];
  return [
    'root = Card([header, ${names.join(', ')}])',
    'header = CardHeader("Report", "All the rows")',
    for (final (index, name) in names.indexed) '$name = TextContent("Row $index of the long report")',
  ].join('\n');
}

({OpenUIStreamParser parser, String program, int pieces, int maxResolvedPerPiece, ParseResult last})
_streamLongReply() {
  final program = _longProgram();
  final parser = OpenUIStreamParser(_chat());
  final size = program.length ~/ _pieceCount + 1;
  var pieces = 0;
  var maxResolved = 0;
  var end = 0;
  ParseResult? last;
  while (end < program.length) {
    final before = parser.debugResolvedNodes;
    end = min(program.length, end + size);
    final complete = end == program.length;
    last = parser.set(program.substring(0, end), complete: complete);
    // The end of the stream reads the whole text once more.
    if (!complete) maxResolved = max(maxResolved, parser.debugResolvedNodes - before);
    pieces += 1;
  }
  return (parser: parser, program: program, pieces: pieces, maxResolvedPerPiece: maxResolved, last: last!);
}

OpenUILibrarySchema _chat() {
  final spec = jsonDecode(File('test/conformance/generated/upstream-chat-library.spec.json').readAsStringSync());
  return OpenUILibrarySchema.fromSpec(spec as Map<String, Object?>);
}

// How many times reading `program` in pieces of [_smallPiece] code units
// builds a new result, rather than returning the previous one.
int _builds(OpenUIStreamParser parser, String program) {
  var builds = 0;
  ParseResult? previous;
  for (var end = _smallPiece; end < program.length; end += _smallPiece) {
    final result = parser.set(program.substring(0, end));
    if (!identical(result, previous)) builds += 1;
    previous = result;
  }
  return builds;
}
