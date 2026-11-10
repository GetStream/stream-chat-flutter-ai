// A conversation whose replies are OpenUI, and a gallery of the example
// programs the library's prompts teach the model with, all shown by the
// package's `OpenUIRenderer`. Each action an agent would get, and each
// problem the renderer reports, is listed below them.
//
// Two ways replies reach the conversation are shown:
//
//  * from history, as `AIUIDocument`s the app builds itself, which work
//    offline;
//  * the Ohrid reply, as the custom data the Stream agent backend writes on a
//    message while it streams, read with `AIUIDocument.fromCustomData`, the
//    way an app reads its messages.
//
// The app has one component of its own, `place_card`, which the agent places
// as `PlaceCard` in the Ohrid reply. Its other components there, `TripMap`
// and `CalendarCheck`, aren't the app's, so they are reported as unknown.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/stream_chat_flutter_ai_openui.dart';
import 'package:stream_core_flutter/core.dart' show StreamButton;

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _mode = ThemeMode.system;

  void _toggleMode(Brightness current) {
    setState(() => _mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenUI',
      themeMode: _mode,
      theme: ThemeData(brightness: Brightness.light, extensions: [StreamTheme.light()]),
      darkTheme: ThemeData(brightness: Brightness.dark, extensions: [StreamTheme.dark()]),
      home: Builder(
        builder: (context) => FutureBuilder(
          future: _load(),
          builder: (context, loaded) {
            final data = loaded.data;
            if (data == null) return const Scaffold();
            return HomePage(
              ohrid: data.ohrid,
              gallery: data.gallery,
              onToggleMode: () => _toggleMode(Theme.of(context).brightness),
            );
          },
        ),
      ),
    );
  }
}

// What the app shows: the Ohrid reply's program and the gallery's programs by
// name, in the order of their files.
typedef _Data = ({String ohrid, List<(String, String)> gallery});

Future<_Data> _load() async {
  final ohrid = await rootBundle.loadString('assets/ohrid_prompt_example.oui');
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final files = manifest.listAssets().where((asset) => asset.startsWith('assets/gallery/')).toList()..sort();
  return (
    ohrid: ohrid,
    gallery: [
      for (final file in files) (_nameOf(file), await rootBundle.loadString(file)),
    ],
  );
}

// `assets/gallery/02_analytics.oui` as `Analytics`.
String _nameOf(String file) {
  final name = file.split('/').last.replaceFirst(RegExp(r'^\d+_'), '').replaceFirst('.oui', '');
  return name.isEmpty ? file : '${name[0].toUpperCase()}${name.substring(1)}';
}

/// The conversation and the gallery, one at a time.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.ohrid, required this.gallery, required this.onToggleMode});

  final String ohrid;
  final List<(String, String)> gallery;
  final VoidCallback onToggleMode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          ConversationPage(ohrid: widget.ohrid, onToggleMode: widget.onToggleMode),
          GalleryPage(programs: widget.gallery, onToggleMode: widget.onToggleMode),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Conversation'),
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Gallery'),
        ],
      ),
    );
  }
}

// A reply from history: a short card with a form, written as the agent
// writes it.
const _history = '''
root = Card([header, form])
header = CardHeader("Book a table", "Lakeside, tonight")
form = Form("table", buttons, [guests, time])
guests = FormControl("Guests", Input("guests", "2", "number", {required: true}))
time = FormControl("Time", Select("time", [SelectItem("19", "19:00"), SelectItem("20", "20:00")], "Pick a time"))
buttons = Buttons([Button("Book", @ToAssistant("Book the table"), "primary"), Button("Menu", @OpenUrl("https://getstream.io"), "secondary")])
''';

class _Message with AIMessage {
  _Message(
    this.id, {
    required this.role,
    this.text = '',
    this.isGenerating = false,
    this._uiDocument,
    this.customData = const {},
  });

  @override
  final String id;

  @override
  final AIMessageRole role;

  @override
  final String text;

  @override
  final bool isGenerating;

  // The message's custom data, as the backend wrote it.
  final Map<String, Object?> customData;

  final AIUIDocument? _uiDocument;

  @override
  AIUIDocument? get uiDocument => _uiDocument ?? AIUIDocument.fromCustomData(customData);
}

class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.ohrid, required this.onToggleMode});

  // The Ohrid reply's program.
  final String ohrid;
  final VoidCallback onToggleMode;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _log = _Log();
  late final AIUIHost _host = AIUIHost(
    renderers: [OpenUIRenderer(onError: (error, _) => _log.add('${error.code}: ${error.message}'))],
    components: const [PlaceCardComponent()],
    send: _send,
  );
  final _sent = <_Message>[];
  late final List<String> _ohridLines = const LineSplitter().convert(widget.ohrid);

  // How many of the Ohrid reply's lines the agent has written so far.
  int _written = 0;
  Timer? _writing;

  // The pause between two lines the agent writes.
  static const _linePause = Duration(milliseconds: 500);

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

  void _writeOhrid() {
    _writing?.cancel();
    setState(() => _written = 0);
    _writing = Timer.periodic(_linePause, (timer) {
      setState(() => _written += 1);
      if (_written >= _ohridLines.length) timer.cancel();
    });
  }

  Future<void> _send(AIUIAction action) async {
    _log.add('Sent “${action.label}”\n${const JsonEncoder.withIndent('  ').convert(action.toJson())}');
    setState(() => _sent.add(_Message('sent-${_sent.length}', role: AIMessageRole.user, text: action.label)));
  }

  // The custom data the backend writes on the Ohrid reply while it streams.
  Map<String, Object?> _ohridCustomData() {
    final isStreaming = _written < _ohridLines.length;
    return {
      AIUIDocument.customDataKey: {
        'v': 1,
        'format': AIUIFormat.openUI,
        'status': isStreaming ? 'streaming' : 'complete',
        'content': _ohridLines.take(_written).join('\n'),
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    final isWriting = _written < _ohridLines.length;
    final messages = [
      _Message('ask-table', role: AIMessageRole.user, text: 'Book us a table by the lake tonight.'),
      _Message(
        'reply-table',
        role: AIMessageRole.assistant,
        text: 'Here is a table by the lake.',
        uiDocument: const AIUIDocument(format: AIUIFormat.openUI, content: _history),
      ),
      _Message('ask-ohrid', role: AIMessageRole.user, text: 'Plan a weekend in Ohrid'),
      if (_written > 0)
        _Message(
          'reply-ohrid',
          role: AIMessageRole.assistant,
          text: 'Here is a plan for a weekend in Ohrid.',
          isGenerating: isWriting,
          customData: _ohridCustomData(),
        ),
      ..._sent,
    ];
    return Scaffold(
      backgroundColor: colors.backgroundApp,
      appBar: AppBar(
        title: const Text('OpenUI'),
        actions: [
          IconButton(onPressed: _writeOhrid, icon: const Icon(Icons.replay), tooltip: 'Write the Ohrid reply again'),
          IconButton(onPressed: widget.onToggleMode, icon: const Icon(Icons.brightness_6), tooltip: 'Light or dark'),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AIConversationView(messages: messages, isThinking: _written == 0, ui: _host),
          ),
          _LogView(_log),
        ],
      ),
    );
  }
}

/// The gallery: one example program at a time, drawn as a reply of its own.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.programs, required this.onToggleMode});

  /// The programs by name.
  final List<(String, String)> programs;
  final VoidCallback onToggleMode;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final _log = _Log();
  late final AIUIHost _host = AIUIHost(
    renderers: [OpenUIRenderer(onError: (error, _) => _log.add('${error.code}: ${error.message}'))],
    components: const [PlaceCardComponent()],
    send: _send,
  );
  final _sent = <_Message>[];
  int _selected = 0;

  // How many of the program's lines the agent has written so far.
  late int _written = _lines.length;
  Timer? _writing;

  // The pause between two lines the agent writes.
  static const _linePause = Duration(milliseconds: 300);

  List<String> get _lines => const LineSplitter().convert(widget.programs[_selected].$2);

  @override
  void dispose() {
    _writing?.cancel();
    _host.dispose();
    _log.dispose();
    super.dispose();
  }

  void _select(int index) {
    _writing?.cancel();
    setState(() {
      _selected = index;
      _written = _lines.length;
      _sent.clear();
    });
  }

  void _replay() {
    _writing?.cancel();
    setState(() => _written = 0);
    _writing = Timer.periodic(_linePause, (timer) {
      setState(() => _written += 1);
      if (_written >= _lines.length) timer.cancel();
    });
  }

  Future<void> _send(AIUIAction action) async {
    _log.add('Sent “${action.label}”\n${const JsonEncoder.withIndent('  ').convert(action.toJson())}');
    setState(() => _sent.add(_Message('sent-${_sent.length}', role: AIMessageRole.user, text: action.label)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    final (name, _) = widget.programs[_selected];
    final lines = _lines;
    final isWriting = _written < lines.length;
    final messages = [
      _Message('ask-$name', role: AIMessageRole.user, text: 'Show me the $name example.'),
      if (_written > 0)
        _Message(
          'reply-$name',
          role: AIMessageRole.assistant,
          text: name,
          uiDocument: AIUIDocument(
            format: AIUIFormat.openUI,
            isStreaming: isWriting,
            content: lines.take(_written).join('\n'),
          ),
        ),
      ..._sent,
    ];
    return Scaffold(
      backgroundColor: colors.backgroundApp,
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          IconButton(onPressed: _replay, icon: const Icon(Icons.replay), tooltip: 'Write the example again'),
          IconButton(onPressed: widget.onToggleMode, icon: const Icon(Icons.brightness_6), tooltip: 'Light or dark'),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final (index, (label, _)) in widget.programs.indexed)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: index == _selected,
                      onSelected: (_) => _select(index),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            // A new conversation for each example, so none keeps another's replies.
            child: AIConversationView(key: ValueKey(name), messages: messages, isThinking: _written == 0, ui: _host),
          ),
          _LogView(_log),
        ],
      ),
    );
  }
}

// What a person's actions did and what the renderer reported, newest last.
class _Log extends ChangeNotifier {
  final lines = <String>[];

  void add(String line) {
    lines.add(line);
    notifyListeners();
  }
}

// The lines of [log], newest at the bottom, in a strip below the conversation.
class _LogView extends StatelessWidget {
  const _LogView(this.log);

  final _Log log;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        if (log.lines.isEmpty) return const SizedBox.shrink();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            reverse: true,
            children: [for (final line in log.lines.reversed) _Note(line)],
          ),
        );
      },
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
