import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_test_interface.dart';

import '../library/spec_library.dart';

// The runtime side of the OpenUI Lang specification's test library: its
// schema, the props that take a `$variable` both ways, and its `Upper`
// function, for the tests that run programs written against it.

final _library = specLibrary();

/// The specification's test library, compiled.
final OpenUILibrarySchema specSchema = _library.schema;

/// The props of the specification's test library that take a `$variable`
/// both ways.
final BindablePropTest specBindable = _library.isBindable;

/// The specification's test library's functions: `@Upper(text)` gives `text`
/// in upper case.
final specFunctions = <String, OpenUIFunction>{
  'Upper': OpenUIFunction(
    (args) => OpenUIString(switch (args['text']) {
      OpenUIString(:final value) => value.toUpperCase(),
      null || OpenUINull() => '',
      final other => '$other'.toUpperCase(),
    }),
    returns: OpenUIValue.fromJson(const {'type': 'string'}),
  ),
};
