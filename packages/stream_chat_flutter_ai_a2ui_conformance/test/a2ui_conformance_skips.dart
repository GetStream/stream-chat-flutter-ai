// The conformance cases this package doesn't run, each with the reason.

const _otherVersions = {'v0.8', 'v0.9', 'v0.9.1'};

const _v09Syntax = 'Written in v0.9 syntax (`path`, a bare `name`), which a 1.0 renderer reads as literals.';
const _agentCallIds = "Calls to the agent come from bindings and actions, with call ids of the renderer's own.";
const _rpcHandler =
    "Drives the core's handler of calls to the agent directly, with call ids of its own, which this package "
    "doesn't expose; its calls to the agent come from bindings and actions.";
const _callConfig = 'Per-call validation config of the optional agent_renderer_app feature.';
const _functionCallErrors =
    'Expects the error to name the function call, and the errors of this package name no function call.';

const _reportedOnce =
    'Expects the same problem reported again by a later step; this package reports each distinct problem once, '
    'until the processor is reset.';
const _liveCancel =
    "Cancels a live surface's calls to the agent, which this package never does: its calls are cancelled only with "
    'their surface.';
const _schemaOnly =
    'Declares a function without an implementation (schema-only), which a catalog of a2ui_core, holding '
    'implementations, cannot declare.';

const _byName = <String, String>{
  'test_agent_routing_no_default_catalog_is_catalog_error': _reportedOnce,
  'test_agent_routing_non_json_argument_fails_locally': _reportedOnce,
  'test_agent_routing_template_part_never_routes': _reportedOnce,
  'test_agent_routing_refused_call_in_action_is_expression_error': _reportedOnce,
  'test_agent_routing_malformed_event_context_value': _reportedOnce,
  'test_agent_routing_cancelled_call_is_sent_again_when_its_value_is_rewritten': _liveCancel,
  'test_agent_routing_cancelled_call_is_sent_again_on_unrelated_change': _liveCancel,
  'test_action_event_with_data_binding': _v09Syntax,
  'test_action_event_with_relative_scope': _v09Syntax,
  'test_action_direct_name_shorthand': _v09Syntax,
  'test_rpc_call_agent_function_dispatch': _agentCallIds,
  'test_rpc_call_agent_function_timeout_handling': _agentCallIds,
  'test_rpc_call_agent_function_duplicate_call_id_error': _agentCallIds,
  'test_rpc_agent_function_response_correlates_pending_call': _rpcHandler,
  'test_rpc_call_agent_function_cancelled': _rpcHandler,
  'test_rpc_call_agent_function_disposed': _rpcHandler,
  'test_rpc_call_agent_function_no_listener': _rpcHandler,
  'test_rpc_call_agent_function_late_response_after_timeout_ignored': _rpcHandler,
  'test_rpc_call_agent_function_late_response_after_dispose_ignored': _rpcHandler,
  'test_error_response_delete_surface_missing_surface_id':
      'Expects `surfaceId: ""` for a message that names no surface; the errors of this package give `null` for '
      'no surface.',
  'test_action_event_with_dispatch_metadata': _actionMetadata,
  'test_action_event_dispatch_metadata_invalid_uax31_key_error': _actionMetadata,
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
};

const _actionMetadata =
    'Action metadata (`dispatchAction(metadata:)` in the core) is not passed through by this package, whose '
    'action events carry no metadata.';

// What a2ui_core, the core this package is built on, doesn't do yet;
// these pass once the core does.

const _validationResult =
    'a2ui_core gives a check no single `validationResult`, only `validationResults`, and its basic '
    'validators return no `code`.';
const _checkCode = "a2ui_core's basic validators return no `code`, such as `INVALID_EMAIL`.";

const _coreGaps = <String, String>{
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
  if ((testCase['catalogs'] as List<Object?>?)?.any(
        (catalog) => catalog is Map && catalog.containsKey('agentFunctions'),
      ) ??
      false) {
    return _schemaOnly;
  }
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
