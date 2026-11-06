// A conversation whose replies are A2UI, and a gallery of the examples
// published with A2UI's basic catalog, both shown by the package's
// `A2UIRenderer`. Each action an agent would get is listed below them, and
// the gallery also lists each link that would open.
//
// The app has one component of its own, `place_card`, which the agent places
// as `PlaceCard` in the Ohrid reply. Its other components there, `TripMap` and
// `CalendarCheck`, aren't the app's, so they are listed as unknown.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';
import 'package:stream_core_flutter/core.dart' show StreamButton;

void main() => runApp(const GalleryApp());

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  ThemeMode _mode = ThemeMode.system;

  void _toggleMode(Brightness current) {
    setState(() => _mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A2UI gallery',
      themeMode: _mode,
      theme: ThemeData(brightness: Brightness.light, extensions: [StreamTheme.light()]),
      darkTheme: ThemeData(brightness: Brightness.dark, extensions: [StreamTheme.dark()]),
      home: Builder(
        builder: (context) => ExamplesPage(onToggleMode: () => _toggleMode(Theme.of(context).brightness)),
      ),
    );
  }
}

/// One example: its name, and the A2UI messages an agent would write.
class Example {
  Example({required this.name, required this.file, required this.messages}) : missing = _missingOf(messages);

  final String name;
  final String file;
  final List<String> messages;

  /// The component types the example uses that neither the catalog nor the
  /// app's own components draw.
  final List<String> missing;

  static List<String> _missingOf(List<String> messages) {
    final types = <String>{};
    void walk(Object? value) {
      if (value case {'id': String _, 'component': final String type}) types.add(type);
      if (value is Map) value.values.forEach(walk);
      if (value is List) value.forEach(walk);
    }

    messages.map(jsonDecode).forEach(walk);
    return [
      for (final type in types)
        if (A2UICatalog.basic[type] == null && type != PlaceCardComponent.type) type,
    ]..sort();
  }
}

Future<List<Example>> _loadExamples() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final files = manifest.listAssets().where((path) => path.startsWith('assets/examples/')).toList()..sort();
  final ohrid = await rootBundle.loadString('assets/ohrid_prompt_example.jsonl');
  final examples = <Example>[
    Example(
      name: 'A weekend in Ohrid',
      file: 'ohrid_prompt_example.jsonl',
      messages: [
        for (final line in const LineSplitter().convert(ohrid))
          if (line.trim().isNotEmpty) line,
      ],
    ),
  ];
  for (final path in [...files, 'assets/media_example.json', 'assets/link_example.json']) {
    final json = jsonDecode(await rootBundle.loadString(path)) as Map<String, Object?>;
    examples.add(
      Example(
        name: json['name']! as String,
        file: path.split('/').last,
        messages: [for (final message in json['messages']! as List<Object?>) jsonEncode(message)],
      ),
    );
  }
  return examples;
}

class ExamplesPage extends StatefulWidget {
  const ExamplesPage({super.key, required this.onToggleMode});

  final VoidCallback onToggleMode;

  @override
  State<ExamplesPage> createState() => _ExamplesPageState();
}

class _ExamplesPageState extends State<ExamplesPage> {
  late final Future<List<Example>> _examples = _loadExamples();

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => page));

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    return Scaffold(
      backgroundColor: colors.backgroundApp,
      appBar: AppBar(
        title: const Text('A2UI gallery'),
        actions: [
          IconButton(onPressed: widget.onToggleMode, icon: const Icon(Icons.brightness_6), tooltip: 'Light or dark'),
        ],
      ),
      body: FutureBuilder(
        future: _examples,
        builder: (context, snapshot) {
          final examples = snapshot.data;
          if (examples == null) return const Center(child: CircularProgressIndicator());
          return ListView.separated(
            itemCount: examples.length + 1,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.forum_outlined),
                  title: const Text('Conversation'),
                  subtitle: const Text('The Ohrid reply as it streams, and replies from history'),
                  onTap: () => _open(ConversationPage(examples: examples, onToggleMode: widget.onToggleMode)),
                );
              }
              final example = examples[index - 1];
              final missing = example.missing;
              return ListTile(
                title: Text(example.name),
                subtitle: Text(missing.isEmpty ? example.file : '${example.file} · unknown: ${missing.join(', ')}'),
                onTap: () => _open(ExamplePage(example: example, onToggleMode: widget.onToggleMode)),
              );
            },
          );
        },
      ),
    );
  }
}

// What a person's actions did, newest last, as lines to show.
class _ActionLog extends ChangeNotifier {
  final lines = <String>[];

  void add(String line) {
    lines.add(line);
    notifyListeners();
  }

  void addAction(AIUIAction action) {
    final json = const JsonEncoder.withIndent('  ').convert(action.toJson());
    add('Sent “${action.label}”\n$json');
  }

  void addError(A2UIError error) => add('${error.code}: ${error.message}');

  void clear() {
    lines.clear();
    notifyListeners();
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key, required this.example, required this.onToggleMode});

  final Example example;
  final VoidCallback onToggleMode;

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _log = _ActionLog();
  late final AIUIHost _host = AIUIHost(
    renderers: [A2UIRenderer(onError: (error, _) => _log.addError(error))],
    components: const [PlaceCardComponent()],
    send: (action) async => _log.addAction(action),
    // The gallery has nowhere to open a link, so it only shows it.
    open: (link) => _log.add('Opened $link'),
  );

  // How many of the example's messages show, and whether they are being
  // written one by one, as an agent streams them.
  late int _shown = widget.example.messages.length;
  bool _isStreaming = false;
  Timer? _replay;

  // The pause between two messages of a replay.
  static const _messagePause = Duration(milliseconds: 600);

  @override
  void dispose() {
    _replay?.cancel();
    _host.dispose();
    _log.dispose();
    super.dispose();
  }

  void _replayMessages() {
    _replay?.cancel();
    _log.clear();
    setState(() {
      _shown = 0;
      _isStreaming = true;
    });
    _replay = Timer.periodic(_messagePause, (timer) {
      setState(() {
        _shown += 1;
        _isStreaming = _shown < widget.example.messages.length;
      });
      if (!_isStreaming) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    final missing = widget.example.missing;
    final document = AIUIDocument(
      format: AIUIFormat.a2ui,
      version: A2UIRenderer.version,
      isStreaming: _isStreaming,
      content: widget.example.messages.take(_shown).join('\n'),
    );
    final view = AIUIView(host: _host, document: document, messageId: widget.example.file);
    return Scaffold(
      backgroundColor: colors.backgroundApp,
      appBar: AppBar(
        title: Text(widget.example.name),
        actions: [
          IconButton(onPressed: _replayMessages, icon: const Icon(Icons.replay), tooltip: 'Replay'),
          IconButton(onPressed: widget.onToggleMode, icon: const Icon(Icons.brightness_6), tooltip: 'Light or dark'),
        ],
      ),
      // Not a lazy list: a form scrolled out of view keeps what the person
      // typed in it.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (missing.isNotEmpty) _Note('Unknown components: ${missing.join(', ')}'),
            if (view.canShow) view else const _Note('No surface yet.'),
            ListenableBuilder(
              listenable: _log,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final line in _log.lines) _Note(line)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A message of the example conversation.
class _Message with AIMessage {
  _Message(this.id, {required this.role, this.text = '', this.uiDocument});

  @override
  final String id;

  @override
  final AIMessageRole role;

  @override
  final String text;

  @override
  final AIUIDocument? uiDocument;
}

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.examples, required this.onToggleMode});

  final List<Example> examples;
  final VoidCallback onToggleMode;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _log = _ActionLog();
  late final AIUIHost _host = AIUIHost(
    renderers: [A2UIRenderer(onError: (error, _) => _log.addError(error))],
    components: const [PlaceCardComponent()],
    send: _send,
  );
  late final List<_Message> _history = [
    for (final file in const [
      '20_restaurant-card.json',
      '01_flight-status.json',
      '09_login-form.json',
      'link_example.json',
    ])
      if (_example(file) case final example?) ...[
        _Message('ask-$file', role: AIMessageRole.user, text: 'Show me ${example.name}.'),
        _Message('reply-$file', role: AIMessageRole.assistant, text: example.name, uiDocument: _document(example)),
      ],
  ];
  final _sent = <_Message>[];
  late final Example _ohrid = widget.examples.first;

  // How many of the Ohrid reply's lines the agent has written so far.
  int _written = 0;
  Timer? _writing;

  // The pause between two lines the agent writes.
  static const _linePause = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _writeOhrid();
  }

  @override
  void dispose() {
    _writing?.cancel();
    _host.dispose();
    _log.dispose();
    super.dispose();
  }

  Example? _example(String file) {
    for (final example in widget.examples) {
      if (example.file == file) return example;
    }
    return null;
  }

  static AIUIDocument _document(Example example, {int? lines, bool isStreaming = false}) {
    return AIUIDocument(
      format: AIUIFormat.a2ui,
      version: A2UIRenderer.version,
      isStreaming: isStreaming,
      content: example.messages.take(lines ?? example.messages.length).join('\n'),
    );
  }

  void _writeOhrid() {
    _writing?.cancel();
    setState(() => _written = 0);
    _writing = Timer.periodic(_linePause, (timer) {
      setState(() => _written += 1);
      if (_written >= _ohrid.messages.length) timer.cancel();
    });
  }

  Future<void> _send(AIUIAction action) async {
    _log.addAction(action);
    setState(() => _sent.add(_Message('sent-${_sent.length}', role: AIMessageRole.user, text: action.label)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    final messages = [
      ..._history,
      _Message('ask-ohrid', role: AIMessageRole.user, text: 'Plan a weekend in Ohrid'),
      if (_written > 0)
        _Message(
          'reply-ohrid',
          role: AIMessageRole.assistant,
          text: 'Here is a plan for a weekend in Ohrid.',
          uiDocument: _document(_ohrid, lines: _written, isStreaming: _written < _ohrid.messages.length),
        ),
      ..._sent,
    ];
    return Scaffold(
      backgroundColor: colors.backgroundApp,
      appBar: AppBar(
        title: const Text('Conversation'),
        actions: [
          IconButton(onPressed: _writeOhrid, icon: const Icon(Icons.replay), tooltip: 'Write the Ohrid reply again'),
          IconButton(onPressed: widget.onToggleMode, icon: const Icon(Icons.brightness_6), tooltip: 'Light or dark'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AIConversationView(
              messages: messages,
              isThinking: _written == 0,
              ui: _host,
            ),
          ),
          ListenableBuilder(
            listenable: _log,
            builder: (context, _) {
              if (_log.lines.isEmpty) return const SizedBox.shrink();
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  reverse: true,
                  children: [for (final line in _log.lines.reversed) _Note(line)],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: context.streamTextTheme.captionDefault.copyWith(color: context.streamColorScheme.textSecondary),
      ),
    );
  }
}

// What the agent writes for a place: its title and an optional note.
typedef _Place = ({String title, String? note});

// A place on a trip, which the agent places as `PlaceCard`, with a button
// that asks the agent about it.
class PlaceCardComponent extends AIUIComponent<_Place> {
  const PlaceCardComponent();

  /// The A2UI type the agent places it by.
  static const type = 'PlaceCard';

  @override
  AIUIComponentDefinition get definition => const AIUIComponentDefinition(
    name: 'place_card',
    description: 'A place to visit, with a short note such as when to go.',
    parameters: [
      AIUIParameter.required('title', AIUIParameterType.string, description: "The place's name."),
      AIUIParameter.optional('note', AIUIParameterType.string, description: 'A short tip, such as how long to stay.'),
    ],
    events: [AIUIComponentEvent(name: 'ask_about', description: 'The person asks about the place.')],
  );

  @override
  _Place readArguments(AIUIArguments arguments) =>
      (title: arguments.string('title'), note: arguments.optional('note', arguments.string));

  @override
  Widget build(BuildContext context, _Place place, AIUIComponentContext ui) {
    final colors = context.streamColorScheme;
    final text = context.streamTextTheme;
    final spacing = context.streamSpacing;
    final icons = context.streamIcons;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundSurface,
        borderRadius: BorderRadius.all(context.streamRadius.lg),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(spacing.sm, spacing.xs, spacing.xxs, spacing.xs),
        child: Row(
          spacing: spacing.xs,
          children: [
            Icon(icons.location, color: colors.accentPrimary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.title, style: text.bodyEmphasis.copyWith(color: colors.textPrimary)),
                  if (place.note case final note?)
                    Text(note, style: text.captionDefault.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
            StreamButton.icon(
              onPressed: () => ui.emit(
                'ask_about',
                label: 'Tell me more about ${place.title}',
                payload: {'title': place.title},
              ),
              style: .secondary,
              type: .ghost,
              icon: Icon(icons.messageBubble),
              tooltip: 'Ask about ${place.title}',
            ),
          ],
        ),
      ),
    );
  }
}
