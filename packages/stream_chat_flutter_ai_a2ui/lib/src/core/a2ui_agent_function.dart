part of 'a2ui_adapter.dart';

/// Signature for the function that runs a function a surface calls that no
/// catalog has, and completes with the function's value, or fails.
///
/// Internal to the package.
typedef A2UIAgentFunctionCallback = Future<Object?> Function(A2UIAgentFunctionCall call);

/// Why a function no catalog has failed, in words a developer reads, for a
/// [A2UIAgentFunctionCallback] to fail with.
///
/// Internal to the package.
@internal
final class A2UIAgentFunctionException implements Exception {
  /// Creates an [A2UIAgentFunctionException] that says why.
  const A2UIAgentFunctionException(this.message);

  /// Why the function failed.
  final String message;

  @override
  String toString() => message;
}

/// A function a surface calls that no catalog has, such as one of the app's
/// tools, with its arguments read from the surface's data model.
///
/// Two calls are `==` when their fields are, with [arguments] compared
/// deeply.
///
/// Reaches the `onAgentFunction` callback of [A2UIProcessor.new].
///
/// Internal to the package.
@internal
@immutable
final class A2UIAgentFunctionCall {
  /// Creates an [A2UIAgentFunctionCall].
  const A2UIAgentFunctionCall({
    required this.name,
    required this.surfaceId,
    this.arguments = const {},
    this.isUserInitiated = false,
  });

  /// The function's name, as the agent wrote it in `@call`.
  final String name;

  /// The id of the surface that calls it.
  final String surfaceId;

  /// The values of its arguments.
  final Map<String, Object?> arguments;

  /// Whether the person's own act calls it, such as tapping a button whose
  /// action calls it, rather than the surface as it shows.
  final bool isUserInitiated;

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is A2UIAgentFunctionCall &&
        other.name == name &&
        other.surfaceId == surfaceId &&
        const DeepCollectionEquality().equals(other.arguments, arguments) &&
        other.isUserInitiated == isUserInitiated;
  }

  @override
  int get hashCode {
    return Object.hash(name, surfaceId, const DeepCollectionEquality().hash(arguments), isUserInitiated);
  }

  // The arguments' keys only: their values can be what the person entered.
  @override
  String toString() {
    return '${objectRuntimeType(this, 'A2UIAgentFunctionCall')}(name: $name, surfaceId: $surfaceId, '
        'arguments: ${arguments.keys.toList()}, isUserInitiated: $isUserInitiated)';
  }
}
