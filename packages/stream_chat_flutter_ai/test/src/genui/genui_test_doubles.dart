import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

/// An engine that records what it is given, and shows a document's text.
class TestEngine extends AIUIEngine {
  TestEngine(this.host);

  final AIUIHosting host;
  final received = <(String, AIUIDocument)>[];
  final shown = <(String, AIUIDocument)>[];
  final removed = <String>[];
  // What it was asked, in order: `receive <id>` or `view <id>`.
  final asked = <String>[];
  bool isDisposed = false;

  @override
  void receive(AIUIDocument document, String messageId) {
    received.add((messageId, document));
    asked.add('receive $messageId');
  }

  @override
  void remove(String messageId) => removed.add(messageId);

  @override
  Widget? view(AIUIDocument document, String messageId) {
    shown.add((messageId, document));
    asked.add('view $messageId');
    final text = document.text;
    return text == null ? null : Text(text, textDirection: TextDirection.ltr);
  }

  @override
  void dispose() {
    isDisposed = true;
    super.dispose();
  }
}

/// A renderer of [format] that reads the versions starting with [versions],
/// and keeps the engines it makes.
class TestRenderer extends AIUIRenderer {
  TestRenderer({this.format = AIUIFormat.openUI, this.versions = '1.'});

  @override
  final AIUIFormat format;

  final String versions;
  final engines = <TestEngine>[];

  @override
  bool supports(String? version) => version == null || version.startsWith(versions);

  @override
  Map<String, Object?> capabilities(List<AIUIComponent<Object?>> components, List<AIToolDefinition> tools) => {
    'components': components.length,
  };

  @override
  AIUIEngine makeEngine(AIUIHosting host) {
    final engine = TestEngine(host);
    engines.add(engine);
    return engine;
  }
}

/// The `place_card` component, which shows its title.
class PlaceCardComponent extends AIUIComponent<String> {
  const PlaceCardComponent();

  @override
  AIUIComponentDefinition get definition => const AIUIComponentDefinition(
    name: 'place_card',
    description: 'A place.',
    parameters: [AIUIParameter.required('title', AIUIParameterType.string)],
  );

  @override
  String readArguments(AIUIArguments arguments) => arguments.string('title');

  @override
  Widget build(BuildContext context, String title, AIUIComponentContext ui) =>
      Text(title, textDirection: TextDirection.ltr);
}

/// A message with what the generated UI tests need.
class Reply with AIMessage {
  Reply(
    this.id, {
    this.role = AIMessageRole.assistant,
    this.text = '',
    this.isGenerating = false,
    this.parts = const [],
    this.uiDocument,
  });

  @override
  final String id;

  @override
  final AIMessageRole role;

  @override
  final String text;

  @override
  final bool isGenerating;

  @override
  final List<AIMessagePart> parts;

  @override
  final AIUIDocument? uiDocument;
}

/// An OpenUI document of [program], finished unless [isStreaming].
AIUIDocument openUI(String program, {String? version, bool isStreaming = false}) =>
    AIUIDocument(format: AIUIFormat.openUI, version: version, isStreaming: isStreaming, content: program);

/// A host of [renderers], or of one [TestRenderer], that sends nothing, and is
/// disposed once the test ends.
AIUIHost testHost({
  List<AIUIRenderer>? renderers,
  List<AIUIComponent<Object?>> components = const [],
  List<AIResultClientTool> tools = const [],
  AIUIActionSender? send,
  AIUILinkOpener? open,
}) {
  final host = AIUIHost(
    renderers: renderers ?? [TestRenderer()],
    components: components,
    tools: tools,
    send: send ?? (_) async {},
    open: open,
  );
  addTearDown(host.dispose);
  return host;
}
