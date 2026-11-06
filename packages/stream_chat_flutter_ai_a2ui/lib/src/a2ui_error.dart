import 'package:flutter/foundation.dart';

/// A problem with a reply's A2UI that keeps part of it from showing: a message
/// A2UI doesn't allow, a component or function its catalog doesn't have, or a
/// value its data model can't take.
///
/// Problems are reported as values, never thrown. Two errors are `==` when all
/// their fields are.
///
/// Internal to the package.
@internal
@immutable
final class A2UIError {
  /// Creates an [A2UIError].
  const A2UIError({required this.code, required this.message, this.surfaceId, this.path});

  /// The kind of problem, such as [A2UIErrorCode.validationFailed].
  final A2UIErrorCode code;

  /// What went wrong, written for the developer of the agent.
  final String message;

  /// The id of the surface the problem is on, or `null` when it doesn't belong
  /// to one.
  final String? surfaceId;

  /// A JSON pointer to where the problem is: in the agent's message, such as
  /// `/version`, or in the component at fault, such as `/text`. An empty
  /// string is the whole message, and `null` means no place is known.
  final String? path;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is A2UIError &&
        other.code == code &&
        other.message == message &&
        other.surfaceId == surfaceId &&
        other.path == path;
  }

  @override
  int get hashCode => Object.hash(code, message, surfaceId, path);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'A2UIError')}(code: $code, surfaceId: $surfaceId, path: $path, '
        'message: $message)';
  }
}

/// The code of an [A2UIError].
///
/// The constants are the codes this package reports. Any other string is a
/// valid code too, such as one A2UI adds later.
///
/// Internal to the package.
@internal
extension type const A2UIErrorCode(String _) implements String {
  /// A message, component or value that doesn't match what A2UI or the catalog
  /// allows.
  static const validationFailed = A2UIErrorCode('VALIDATION_FAILED');

  /// A component placed under a parent its catalog doesn't allow it in.
  static const unallowedParent = A2UIErrorCode('UNALLOWED_PARENT');

  /// A component holding a child its catalog doesn't allow in it.
  static const unallowedChild = A2UIErrorCode('UNALLOWED_CHILD');

  /// Messages that contradict each other or the surfaces they name, such as an
  /// update for a surface that doesn't exist.
  static const integrityError = A2UIErrorCode('INTEGRITY_ERROR');

  /// A function call the agent asked for that can't run.
  static const invalidFunctionCall = A2UIErrorCode('INVALID_FUNCTION_CALL');

  /// A binding or function call in a component that can't be evaluated.
  static const expressionError = A2UIErrorCode('EXPRESSION_ERROR');

  /// A function that failed while it ran.
  static const executionError = A2UIErrorCode('EXECUTION_ERROR');

  /// A surface, component or function call that names a catalog this package
  /// doesn't have.
  static const catalogNotFound = A2UIErrorCode('CATALOG_NOT_FOUND');

  /// Components that hold each other, so their tree never ends.
  static const recursionLimitExceeded = A2UIErrorCode('RECURSION_LIMIT_EXCEEDED');

  /// A component whose type its catalog doesn't have.
  static const unknownComponentType = A2UIErrorCode('UNKNOWN_COMPONENT_TYPE');

  /// A component's action that names no event or function.
  static const invalidAction = A2UIErrorCode('INVALID_ACTION');

  /// A data model path that can't be read or written, such as one below a
  /// string.
  static const dataError = A2UIErrorCode('DATA_ERROR');

  /// Messages that contradict a surface's own state.
  static const stateError = A2UIErrorCode('STATE_ERROR');
}
