import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

// The message that creates surface [surfaceId] with [components] and [data].
String surfaceMessage(
  List<Map<String, Object?>> components, {
  String surfaceId = 's',
  Map<String, Object?> data = const {},
  bool sendDataModel = false,
}) {
  return jsonEncode({
    'version': '1.0',
    'createSurface': {
      'surfaceId': surfaceId,
      'catalogId': A2UIRenderer.defaultCatalogId,
      'dataModel': data,
      if (sendDataModel) 'sendDataModel': true,
      if (components.isNotEmpty) 'components': components,
    },
  });
}

// The message that adds [components] to surface [surfaceId].
String componentsMessage(List<Map<String, Object?>> components, {String surfaceId = 's'}) {
  return jsonEncode({
    'version': '1.0',
    'updateComponents': {'surfaceId': surfaceId, 'components': components},
  });
}

// The message that deletes surface [surfaceId].
String deleteMessage({String surfaceId = 's'}) {
  return jsonEncode({
    'version': '1.0',
    'deleteSurface': {'surfaceId': surfaceId},
  });
}

// A reply's A2UI document of [messages], one per line.
AIUIDocument a2uiDocument(List<String> messages, {bool isStreaming = false}) {
  return AIUIDocument(format: AIUIFormat.a2ui, version: '1.0', isStreaming: isStreaming, content: messages.join('\n'));
}

// A button `go` saying [text], whose action names [event].
List<Map<String, Object?>> buttonSaying(
  String text, {
  String event = 'book',
  Map<String, Object?> context = const {},
  String? userMessage,
}) {
  return [
    {
      'id': 'root',
      'component': 'Button',
      'child': 'label',
      'action': {
        'event': {'name': event, 'context': context, 'userMessage': ?userMessage},
      },
    },
    {'id': 'label', 'component': 'Text', 'text': text},
  ];
}

// An agent's reply whose UI is [uiDocument].
final class TestReply with AIMessage {
  TestReply(this.id, this.uiDocument);

  @override
  final String id;

  @override
  final AIUIDocument? uiDocument;

  @override
  AIMessageRole get role => AIMessageRole.assistant;

  @override
  String get text => 'The reply in words.';
}

// One of the app's tools, which records the arguments of each run. One that
// [holds] answers only when the test completes [pending].
final class TestTool extends AIResultClientTool {
  TestTool(this.name, {this.isReadOnly = true, this.output, this.holds = false});

  final String name;
  final bool isReadOnly;
  final Object? output;
  final bool holds;
  final runs = <Map<String, Object?>>[];
  Completer<AIClientToolResult>? pending;

  @override
  AIToolDefinition get definition => AIToolDefinition(name: name, description: 'A test tool', isReadOnly: isReadOnly);

  @override
  Future<AIClientToolResult> run(AIToolCallPart call) {
    runs.add(call.arguments ?? const {});
    if (holds) return (pending = Completer()).future;
    return Future.value(AIClientToolCompleted(output));
  }
}

// What a conversation's host got from the replies' UI.
final class ReplyHarness {
  ReplyHarness(this.host);

  final AIUIHost host;
  final actions = <AIUIAction>[];
  final links = <Uri>[];
  final errors = <(A2UIError, String)>[];
}

// Shows [replies] through a host with [renderer]'s format, the way a
// conversation shows them: each with an [AIUIView] built while the screen
// builds. Without [renderer], errors go to the harness. The host is disposed
// when the test ends.
Future<ReplyHarness> pumpReplies(
  WidgetTester tester,
  List<TestReply> replies, {
  A2UIRenderer Function(A2UIErrorHandler onError)? renderer,
  List<AIResultClientTool> tools = const [],
  List<AIUIComponent<Object?>> components = const [],
}) async {
  late final ReplyHarness harness;
  void onError(A2UIError error, String messageId) => harness.errors.add((error, messageId));
  final host = AIUIHost(
    renderers: [renderer?.call(onError) ?? A2UIRenderer(onError: onError)],
    tools: tools,
    components: components,
    send: (action) async => harness.actions.add(action),
    open: (url) => harness.links.add(url),
  );
  harness = ReplyHarness(host);
  addTearDown(host.dispose);
  await showReplies(tester, harness, replies);
  return harness;
}

// Shows [replies] again in [harness], as a conversation does when they
// change.
Future<void> showReplies(WidgetTester tester, ReplyHarness harness, List<TestReply> replies) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [StreamTheme.light()]),
      home: Material(
        child: SingleChildScrollView(
          child: Builder(
            builder: (context) {
              harness.host.receive(replies);
              return Column(
                children: [
                  for (final reply in replies)
                    if (reply.uiDocument case final document?)
                      Builder(
                        builder: (context) {
                          final view = AIUIView(host: harness.host, document: document, messageId: reply.id);
                          if (!view.canShow) return Text('text of ${reply.id}');
                          return view;
                        },
                      ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
