import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

import 'core/runtime/fake_timers.dart';
import 'core/runtime/fake_tools.dart';

/// The runtime of a reply read with [library], its tools answered by [tools].
OpenUIRuntime testRuntime({OpenUILibrary? library, FakeTools? tools}) {
  final definition = (library ?? OpenUILibrary.chat).definition;
  return OpenUIRuntime(
    schema: definition.schema,
    isBindable: definition.isBindable,
    tools: tools ?? FakeTools(),
    timer: FakeTimers().call,
  );
}

/// [child] in an app themed with [stream] (light by default) and, when given,
/// the app's [builders] for the design system's components.
Widget testApp(Widget child, {StreamTheme? stream, StreamComponentBuilders? builders}) {
  Widget body = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 360, child: child),
  );
  if (builders != null) body = StreamComponentFactory(builders: builders, child: body);
  return MaterialApp(
    theme: ThemeData(extensions: [stream ?? StreamTheme.light()]),
    home: Material(child: body),
  );
}

/// Pumps the view of [runtime]'s program, once it has read [program] to its
/// end.
Future<void> pumpOpenUI(
  WidgetTester tester,
  OpenUIRuntime runtime, {
  String? program,
  bool isStreaming = false,
  OpenUILibrary? library,
  OpenUIThemeData? theme,
  OpenUIOpenLink? onOpenLink,
  StreamTheme? stream,
  StreamComponentBuilders? builders,
}) async {
  if (program != null) runtime.update(program, isStreaming: isStreaming);
  await tester.pumpWidget(
    testApp(
      OpenUIView(runtime: runtime, library: library ?? OpenUILibrary.chat, theme: theme, onOpenLink: onOpenLink),
      stream: stream,
      builders: builders,
    ),
  );
}
