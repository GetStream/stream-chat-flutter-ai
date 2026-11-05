// The conformance cases this package doesn't run, each with the reason.

const _otherVersions = {'v0.8', 'v0.9', 'v0.9.1'};

const _v09Syntax = 'Written in v0.9 syntax (`path`, a bare `name`), which a 1.0 renderer reads as literals.';
const _agentCallIds = "Calls to the agent come from bindings and actions, with call ids of the renderer's own.";
const _callConfig = 'Per-call validation config of the optional agent_renderer_app feature.';
const _functionCallErrors =
    'Expects the error to name the function call, and the errors of this package name no function call; '
    'a2ui_core 0.4.0 also rejects the message rather than answering it.';

const _byName = <String, String>{
  'test_action_event_with_data_binding': _v09Syntax,
  'test_action_event_with_relative_scope': _v09Syntax,
  'test_action_direct_name_shorthand': _v09Syntax,
  'test_rpc_call_agent_function_dispatch': _agentCallIds,
  'test_rpc_call_agent_function_timeout_handling': _agentCallIds,
  'test_rpc_call_agent_function_duplicate_call_id_error': _agentCallIds,
  'test_rpc_call_renderer_function_requires_user_activation':
      "A call from the agent carries no gesture of the person's, so the renderer never runs a "
      'requiresUserActivation function for it.',
  'test_rpc_call_renderer_function_protocol_version_mismatch': 'A v0.9 catalog: this package reads A2UI 1.0.',
  'test_v10_get_renderer_data_model_filters_by_surface_protocol_version':
      'A v0.9 surface: this package reads A2UI 1.0.',
  'test_v10_get_renderer_capabilities':
      'Renderer capabilities belong to the A2A transport, which this package leaves out.',
  'test_v10_get_renderer_capabilities_inline_catalogs':
      'Renderer capabilities belong to the A2A transport, which this package leaves out.',
  'test_v10_call_validation_config_relaxes_strict_processor': _callConfig,
  'test_v10_call_validation_config_tightens_permissive_processor': _callConfig,
  'test_v10_call_validation_config_leaves_out_rules_as_strict': _callConfig,
  'test_rpc_call_renderer_function_invalid_payload_non_object_args': _functionCallErrors,
  'test_rpc_call_renderer_function_invalid_payload_missing_call_function': _functionCallErrors,
  'test_error_response_call_renderer_function_missing_catalog_id': _functionCallErrors,
  'test_error_response_call_renderer_function_non_object_args': _functionCallErrors,
  'test_error_response_call_renderer_function_missing_call_function': _functionCallErrors,
  'test_error_response_delete_surface_missing_surface_id':
      'Expects `surfaceId: ""` for a message that names no surface; the errors of this package give `null` for '
      'no surface. (a2ui_core 0.4.0 also gives the error no `/surfaceId` path.)',
};

// What a2ui_core 0.4.0, the core this package is built on, doesn't do yet:
// these cases were added to the suite or changed after its release
// (a2ui-project/a2ui 36db592), and pass once the core does.

const _errorPaths =
    "a2ui_core 0.4.0 points the error at the component's own field (such as `/id`), not at its place in the "
    'message (`/components/0/id`); the message paths came after 0.4.0, with `MessageErrorMapper`.';
const _notRejected = 'a2ui_core 0.4.0 accepts this message; rejecting it came after 0.4.0.';
const _actionMetadata = 'Action metadata (`dispatchAction(metadata:)`) came after a2ui_core 0.4.0 (a2ui#3757).';
const _validationResult = 'a2ui_core 0.4.0 gives a check no single `validationResult`.';
const _checkCode =
    "a2ui_core 0.4.0 drops the code a check's function returns when the check gives its own message; kept since "
    'a2ui#3583.';

const _coreGaps = <String, String>{
  'test_error_response_update_components_unknown_type_strict': _errorPaths,
  'test_error_response_update_components_invalid_property_type': _errorPaths,
  'test_error_response_update_components_invalid_uax31_id': _errorPaths,
  'test_error_response_update_components_unallowed_parent': _errorPaths,
  'test_custom_catalog_1_0': _errorPaths,
  'test_v10_function_argument_schema_mismatch_error': _errorPaths,
  'test_v10_uax31_invalid_identifier_error': _errorPaths,
  'test_v10_unknown_component_property': _errorPaths,
  'test_v10_unknown_component_type': _errorPaths,
  'test_v10_unknown_nested_function': _errorPaths,
  'test_v10_function_call_naming_catalog_with_invalid_args_errors': _errorPaths,
  'test_v10_function_call_naming_catalog_without_that_function_errors': _errorPaths,
  'test_composition_unallowed_parent_error': _errorPaths,
  'test_error_response_update_components_extra_forbidden_property': _notRejected,
  'test_error_response_update_data_model_invalid_json_pointer': _notRejected,
  'test_action_event_with_dispatch_metadata': _actionMetadata,
  'test_action_event_dispatch_metadata_invalid_uax31_key_error': _actionMetadata,
  'test_action_event_non_string_user_message_error':
      'a2ui_core 0.4.0 drops a `userMessage` that is not a string rather than reporting `INVALID_ACTION`.',
  'test_action_function_call_execution_error':
      'a2ui_core 0.4.0 reports a function that throws while an action runs as `EXPRESSION_ERROR`; '
      '`EXECUTION_ERROR` since a2ui#3739.',
  'test_validation_result_dynamic_object_return': _validationResult,
  'test_validation_result_boolean_fallback': _validationResult,
  'test_validation_result_multiple_rules_preserve_order': _checkCode,
  'test_validation_result_reactive_recovery_on_data_update': _checkCode,
};

/// The case names the skip list names, so a test can check each is still a
/// case of the vendored suites.
Set<String> get conformanceSkippedNames => {..._byName.keys, ..._coreGaps.keys};

/// Whether the case [name] is skipped for a gap of a2ui_core, which it passes
/// once the core closes the gap.
bool isConformanceCoreGap(String name) => _coreGaps.containsKey(name);

/// Why the case [name] of [suite] isn't run, or `null` when it is.
String? conformanceSkipReason(String suite, String name, Map<String, Object?> testCase) {
  if (_byName[name] case final String reason) return reason;
  if (_coreGaps[name] case final String reason) return reason;
  final version = testCase['protocolVersion'];
  if (_otherVersions.contains(version)) return 'A2UI $version: this package reads A2UI 1.0.';
  if (version != null || !_usesOtherVersion(testCase)) return null;
  return 'Messages of another A2UI version: this package reads A2UI 1.0.';
}

bool _usesOtherVersion(Object? value) => switch (value) {
  final Map<String, Object?> map => _otherVersions.contains(map['version']) || map.values.any(_usesOtherVersion),
  final List<Object?> list => list.any(_usesOtherVersion),
  _ => false,
};
