import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

void main() {
  test('an error prints as source/code: message', () {
    expect(_error().toString(), 'parser/unknown-component: A problem.');
  });

  test('two errors with the same fields are equal', () {
    expect(_error(), _error());
  });

  test('two errors with the same fields have the same hash code', () {
    expect(_error().hashCode, _error().hashCode);
  });

  final variants = <String, OpenUIError>{
    'sources': _error(source: OpenUIErrorSource.runtime),
    'codes': _error(code: OpenUIErrorCode.noRoot),
    'messages': _error(message: 'Another problem.'),
    'statements': _error(statementId: 'other'),
    'components': _error(component: 'Other'),
    'paths': _error(path: '/other'),
    'tools': _error(toolName: 'other'),
    'hints': _error(hint: 'Other.'),
    'warnings': _error(isWarning: true),
  };
  for (final MapEntry(key: field, value: variant) in variants.entries) {
    test('errors with different $field differ', () {
      expect(variant, isNot(_error()));
    });
  }

  test('an error code equals the string it is made of', () {
    expect(OpenUIErrorCode.missingRequired, 'missing-required');
  });

  test('an error source equals the string it is made of', () {
    expect(OpenUIErrorSource.mutation, 'mutation');
  });

  test("the error codes are OpenUI Lang's own", () {
    expect(
      [
        OpenUIErrorCode.unknownComponent,
        OpenUIErrorCode.missingRequired,
        OpenUIErrorCode.nullRequired,
        OpenUIErrorCode.typeMismatch,
        OpenUIErrorCode.excessArgs,
        OpenUIErrorCode.inlineReserved,
        OpenUIErrorCode.unknownFunction,
        OpenUIErrorCode.noRoot,
        OpenUIErrorCode.parseFailed,
        OpenUIErrorCode.parseException,
        OpenUIErrorCode.runtimeError,
        OpenUIErrorCode.renderError,
        OpenUIErrorCode.toolNotFound,
        OpenUIErrorCode.toolError,
        OpenUIErrorCode.mcpError,
      ],
      [
        'unknown-component',
        'missing-required',
        'null-required',
        'type-mismatch',
        'excess-args',
        'inline-reserved',
        'unknown-function',
        'no-root',
        'parse-failed',
        'parse-exception',
        'runtime-error',
        'render-error',
        'tool-not-found',
        'tool-error',
        'mcp-error',
      ],
    );
  });

  test('the error sources are parser, runtime, query and mutation', () {
    expect(
      [OpenUIErrorSource.parser, OpenUIErrorSource.runtime, OpenUIErrorSource.query, OpenUIErrorSource.mutation],
      ['parser', 'runtime', 'query', 'mutation'],
    );
  });
}

OpenUIError _error({
  OpenUIErrorSource source = OpenUIErrorSource.parser,
  OpenUIErrorCode code = OpenUIErrorCode.unknownComponent,
  String message = 'A problem.',
  String? statementId = 'root',
  String? component = 'Card',
  String? path = '/title',
  String? toolName,
  String? hint = 'A hint.',
  bool isWarning = false,
}) {
  return OpenUIError(
    source: source,
    code: code,
    message: message,
    statementId: statementId,
    component: component,
    path: path,
    toolName: toolName,
    hint: hint,
    isWarning: isWarning,
  );
}
