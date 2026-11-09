import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';

// A small trip-planning surface the node and surface tests share: a column
// with a title, a bound text, an email field and a button whose action names
// an event.

const planComponents = [
  {
    'id': 'root',
    'component': 'Column',
    'children': ['title', 'pace', 'email', 'update'],
  },
  {'id': 'title', 'component': 'Text', 'text': 'A weekend in Ohrid'},
  {
    'id': 'pace',
    'component': 'Text',
    'text': {'@path': '/pace/0'},
  },
  {
    'id': 'email',
    'component': 'TextField',
    'label': 'Email',
    'value': {'@path': '/email'},
  },
  {
    'id': 'update',
    'component': 'Button',
    'child': 'update_label',
    'action': {
      'event': {
        'name': 'update_plan',
        'userMessage': 'Update the plan',
        'context': {
          'pace': {'@path': '/pace'},
        },
      },
    },
  },
  {'id': 'update_label', 'component': 'Text', 'text': 'Update the plan'},
];

const planData = {
  'pace': ['relaxed'],
  'email': 'person@example.com',
};

String createPlanSurface({Map<String, Object?> data = planData}) {
  return jsonEncode({
    'version': '1.0',
    'createSurface': {'surfaceId': 'plan', 'catalogId': A2UICatalogs.defaultCatalogId, 'dataModel': data},
  });
}

String updatePlanComponents({List<Map<String, Object?>> components = planComponents}) {
  return jsonEncode({
    'version': '1.0',
    'updateComponents': {'surfaceId': 'plan', 'components': components},
  });
}

String deletePlanSurface() {
  return jsonEncode({
    'version': '1.0',
    'deleteSurface': {'surfaceId': 'plan'},
  });
}

// A processor disposed when the test ends.
A2UIProcessor testProcessor({List<A2UIActionEvent>? events, List<A2UIError>? errors}) {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onAction: events?.add, onError: errors?.add);
  addTearDown(processor.dispose);
  return processor;
}

// The plan surface with [components] and [data], from a processor disposed
// when the test ends.
A2UISurface planSurface({
  List<Map<String, Object?>> components = planComponents,
  Map<String, Object?> data = planData,
  List<A2UIActionEvent>? events,
  List<A2UIError>? errors,
  A2UIProcessor? processor,
}) {
  final target = (processor ?? testProcessor(events: events, errors: errors))
    ..apply([createPlanSurface(data: data), updatePlanComponents(components: components)]);
  return target.surface('plan')!;
}

// The child with [id] of the root of [surface].
A2UINode rootChild(A2UISurface surface, String id) {
  return surface.root!.children('children').singleWhere((node) => node.id == id);
}

// A core whose first message fails as a fault of its own would, rather than as
// an A2UI error, and which keeps sending actions after it is disposed.
final class FaultyCore extends core.MessageProcessor<core.ComponentApi> {
  FaultyCore(
    List<core.Catalog<core.ComponentApi, core.FunctionImplementation>> catalogs,
    void Function(core.A2uiRendererAction action) onAction,
  ) : super(catalogs: catalogs, onAction: onAction);

  bool _failed = false;

  @override
  void processMessages(Object? payload, {bool isUserActivated = false, core.ValidationConfig? validationConfig}) {
    if (!_failed) {
      _failed = true;
      throw StateError('core fault');
    }
    super.processMessages(payload, isUserActivated: isUserActivated, validationConfig: validationConfig);
  }

  @override
  void dispose() {}
}
