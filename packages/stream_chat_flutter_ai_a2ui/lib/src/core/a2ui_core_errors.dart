part of 'a2ui_adapter.dart';

// The codes that carry a path to the part of the message at fault.
const _pathErrorCodes = {
  A2UIErrorCode.validationFailed,
  A2UIErrorCode.unallowedParent,
  A2UIErrorCode.unallowedChild,
};

// A problem the core threw, under the A2UI 1.0 code for it, on the surface the
// error names, else [surfaceId], else the one [message] names.
//
// A problem with a `callRendererFunction` belongs to the function call, so it
// names no surface.
A2UIError _errorFromCore(core.A2uiError error, {Map<String, Object?> message = const {}, String? surfaceId}) {
  if (message.containsKey('callRendererFunction')) {
    return A2UIError(
      code: error is core.A2uiRpcError ? A2UIErrorCode(error.code) : A2UIErrorCode.invalidFunctionCall,
      message: error.message,
    );
  }
  final code = _codeOf(error);
  return A2UIError(
    code: code,
    message: error.message,
    surfaceId: _surfaceIdOf(error) ?? surfaceId ?? _surfaceIdIn(message),
    path: _pathErrorCodes.contains(code) ? _pathOf(error) ?? '' : null,
  );
}

// A problem a surface found while its components were resolved.
A2UIError _errorFromSurface(core.A2uiRendererError error) {
  return A2UIError(
    code: A2UIErrorCode(error.code),
    message: error.message,
    surfaceId: _nonEmpty(error.surfaceId),
    path: error.path,
  );
}

A2UIErrorCode _codeOf(core.A2uiError error) {
  if (error is core.A2uiCatalogError) return A2UIErrorCode.catalogNotFound;
  if (error is core.A2uiRecursionError) return A2UIErrorCode.recursionLimitExceeded;
  if (error is core.A2uiIntegrityError) {
    if (_isCircular(error)) return A2UIErrorCode.recursionLimitExceeded;
    return A2UIErrorCode.integrityError;
  }
  if (error is core.A2uiStateError) return A2UIErrorCode.stateError;
  if (error is core.A2uiExpressionError) return _expressionCodeOf(error);
  if (error is core.A2uiValidationError) return _validationCodeOf(error);
  return A2UIErrorCode(error.code);
}

// A binding that names a catalog the surface doesn't have is a missing
// catalog; anything else that keeps an expression from being evaluated is an
// expression error.
A2UIErrorCode _expressionCodeOf(core.A2uiExpressionError error) {
  if (error.code == 'CATALOG_ERROR') return A2UIErrorCode.catalogNotFound;
  return A2UIErrorCode.expressionError;
}

bool _isCircular(core.A2uiIntegrityError error) {
  if (error.message.contains('Circular reference')) return true;
  return error.message.contains('Self-reference');
}

A2UIErrorCode _validationCodeOf(core.A2uiValidationError error) {
  if (error.code == A2UIErrorCode.unallowedParent) return A2UIErrorCode.unallowedParent;
  if (error.code == A2UIErrorCode.unallowedChild) return A2UIErrorCode.unallowedChild;
  return A2UIErrorCode.validationFailed;
}

String? _pathOf(core.A2uiError error) {
  return switch (error) {
    final core.A2uiValidationError error => _nonEmpty(error.path),
    final core.A2uiDataError error => _nonEmpty(error.path),
    _ => null,
  };
}

String? _surfaceIdOf(core.A2uiError error) {
  if (error is! core.A2uiValidationError) return null;
  return _nonEmpty(error.surfaceId);
}

const _messageKeys = [
  'createSurface',
  'updateComponents',
  'updateDataModel',
  'deleteSurface',
  'callRendererFunction',
  'agentFunctionResponse',
];

String? _surfaceIdIn(Map<String, Object?> message) {
  for (final key in _messageKeys) {
    if (message[key] case {'surfaceId': final String surfaceId}) return _nonEmpty(surfaceId);
  }
  return null;
}

String? _nonEmpty(String? value) {
  if (value == null || value.isEmpty) return null;
  return value;
}
