/// Entry points into the OpenUI Lang core that only the conformance tests
/// use.
///
/// A conformance case reads a program and compares what the core gives with
/// what OpenUI's own implementation gave. Each entry point here is the
/// narrowest way in for one kind of case, and works in plain data or the
/// package's own types, so a replacement core has to provide the same ones to
/// pass the same suites.
///
/// One of the core's boundary files: code outside `lib/src/core/` may import
/// it.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_lang_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parser_errors.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/upstream_shape.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// What reading `text` against `schema` gives, as OpenUI's own parser writes
/// it: `root`, `meta`, `stateDeclarations`, `queryStatements` and
/// `mutationStatements` (and `rootExpression` when the entry picks a
/// component only when evaluated), in plain JSON values.
///
/// Only the conformance tests use it.
Map<String, Object?> debugParse(OpenUILibrarySchema schema, String text) {
  return parseResultJson(OpenUILangParser(schema).parse(text));
}

/// The errors reading `text` against `schema` reports, with their hints.
///
/// Only the conformance tests use it.
List<OpenUIError> debugParseErrors(OpenUILibrarySchema schema, String text) {
  return parserErrors(OpenUILangParser(schema).parse(text), schema);
}
