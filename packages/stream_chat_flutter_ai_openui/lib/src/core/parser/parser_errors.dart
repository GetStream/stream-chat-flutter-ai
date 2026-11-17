/// The errors reading a program reports, with hints for fixing them.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// The errors `result` reports, each with a hint when one helps, as
/// [OpenUIError]s from [OpenUIErrorSource.parser].
///
/// The `schema` is the library `result` was read against. A call of a
/// component the library doesn't have is hinted with the components it has; a
/// missing or `null` required argument with the signature of the `$defs`
/// entry its call names, such as
/// `Signature: Card(title*, body) — * marks required`, when there is one with
/// `properties`; and a `Query` or
/// `Mutation` written inline with how to write it as a statement. An error
/// with an empty path has a `null` one.
List<OpenUIError> parserErrors(ParseResult result, OpenUILibrarySchema schema) {
  return [
    for (final error in result.meta.errors)
      OpenUIError(
        source: .parser,
        code: error.code,
        message: error.message,
        statementId: error.statementId,
        component: error.component,
        path: error.path.isEmpty ? null : error.path,
        hint: _hint(error, schema),
        isWarning: error.isWarning,
      ),
  ];
}

String? _hint(ValidationError error, OpenUILibrarySchema schema) {
  switch (error.code) {
    case OpenUIErrorCode.unknownComponent:
      final names = schema.componentNames;
      return names.isEmpty ? null : 'Available components: ${names.join(', ')}';
    case OpenUIErrorCode.missingRequired || OpenUIErrorCode.nullRequired:
      final params = schema.definitionParamsOf(error.component);
      if (params == null) return null;
      final rendered = [
        for (final param in params)
          if (param.required) '${param.name}*' else param.name,
      ].join(', ');
      return 'Signature: ${error.component}($rendered) — * marks required';
    case OpenUIErrorCode.inlineReserved:
      return 'Declare as a top-level statement: myVar = ${error.component}(...)';
    default:
      return null;
  }
}
