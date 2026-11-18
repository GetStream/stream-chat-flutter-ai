import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

void main() {
  test('a function call naming a catalog the surface lacks is a missing catalog', () async {
    final result = await debugEvaluateFunction(
      'not',
      {'value': true},
      catalogs: [const A2UIDebugCatalog.basic(_catalogId)],
      surfaceCatalogId: _catalogId,
      catalogId: 'https://example.com/other.json',
    );

    expect(result, isA<A2UIError>().having((error) => error.code, 'code', A2UIErrorCode.catalogNotFound));
  });

  test('a function failing with the core execution code is an execution error', () async {
    final result = await debugEvaluateFunction(
      'fail',
      {},
      catalogs: [
        const A2UIDebugCatalog.basic(_catalogId, functions: [A2UIDebugFunction('fail', body: _failExecution)]),
      ],
      surfaceCatalogId: _catalogId,
    );

    expect(result, isA<A2UIError>().having((error) => error.code, 'code', A2UIErrorCode.executionError));
  });
}

const _catalogId = 'https://example.com/catalog.json';

Object? _failExecution(Map<String, Object?> args, A2UIDebugScope scope) {
  throw core.A2uiExpressionError('It failed.', code: 'EXECUTION_ERROR');
}
