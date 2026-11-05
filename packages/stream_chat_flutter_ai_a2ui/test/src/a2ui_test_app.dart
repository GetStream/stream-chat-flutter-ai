import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_theme.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';

// Shows a surface of [components] and [data], the way a reply shows it, in a
// box at most [width] wide, and returns the processor, disposed when the test
// ends. The events of the surface's actions go to [events], and the links
// they open to [onOpenLink].
Future<A2UIProcessor> pumpSurface(
  WidgetTester tester, {
  required List<Map<String, Object?>> components,
  Map<String, Object?> data = const {},
  A2UICatalog catalog = A2UICatalog.basic,
  A2UITheme? theme,
  A2UIMediaUrl mediaUrl = a2uiWebMediaUrl,
  List<A2UIError>? errors,
  List<A2UIActionEvent>? events,
  A2UIOpenLink? onOpenLink,
  TextDirection direction = TextDirection.ltr,
  double width = 400,
  Brightness brightness = Brightness.light,
  StreamComponentBuilders? builders,
}) async {
  final processor = A2UIProcessor(catalogs: A2UICatalogs(), onError: errors?.add, onAction: events?.add);
  addTearDown(processor.dispose);
  processor.apply([createSurface(components, data: data)]);
  await tester.pumpWidget(
    surfaceApp(
      processor.surface('s')!,
      catalog: catalog,
      theme: theme,
      mediaUrl: mediaUrl,
      onOpenLink: onOpenLink,
      direction: direction,
      width: width,
      brightness: brightness,
      builders: builders,
    ),
  );
  return processor;
}

// An app that shows [surface] at the top of a box at most [width] wide, under
// a Stream theme of [brightness], with the component [builders] of the app, if
// any.
Widget surfaceApp(
  A2UISurface surface, {
  A2UICatalog catalog = A2UICatalog.basic,
  A2UITheme? theme,
  A2UIMediaUrl mediaUrl = a2uiWebMediaUrl,
  A2UIOpenLink? onOpenLink,
  TextDirection direction = TextDirection.ltr,
  double width = 400,
  Brightness brightness = Brightness.light,
  StreamComponentBuilders? builders,
}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      extensions: [StreamTheme(brightness: brightness)],
    ),
    builder: (context, child) => StreamComponentFactory(builders: builders ?? StreamComponentBuilders(), child: child!),
    home: Directionality(
      textDirection: direction,
      child: Material(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: SingleChildScrollView(
              child: A2UISurfaceView(
                surface: surface,
                catalog: catalog,
                theme: theme,
                mediaUrl: mediaUrl,
                onOpenLink: onOpenLink,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// The message that creates surface `s` with [components], if any, and [data].
String createSurface(List<Map<String, Object?>> components, {Map<String, Object?> data = const {}}) {
  return jsonEncode({
    'version': '1.0',
    'createSurface': {
      'surfaceId': 's',
      'catalogId': A2UICatalogs.defaultCatalogId,
      'dataModel': data,
      if (components.isNotEmpty) 'components': components,
    },
  });
}

// The message that adds [components] to surface `s`.
String updateComponents(List<Map<String, Object?>> components) {
  return jsonEncode({
    'version': '1.0',
    'updateComponents': {'surfaceId': 's', 'components': components},
  });
}

// The message that sets [path] of surface `s`'s data model to [value].
String updateData(String path, Object? value) {
  return jsonEncode({
    'version': '1.0',
    'updateDataModel': {'surfaceId': 's', 'path': path, 'value': value},
  });
}

// The theme a surface under a light Stream theme is drawn with.
A2UITheme lightTheme() => A2UITheme.fromStream(StreamTheme.light());

// A root column of [children], each given as a component.
List<Map<String, Object?>> inColumn(List<Map<String, Object?>> children) => [
  {
    'id': 'root',
    'component': 'Column',
    'children': [for (final child in children) child['id']],
  },
  ...children,
];
