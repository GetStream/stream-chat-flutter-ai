// The package can't show a reply's A2UI in a conversation yet, so the gallery
// reaches inside it for the pieces it is built from: the message processor,
// the splitter and the surface view. The package's renderer replaces them.
// What a person's actions do, the events an agent would get and the links
// that would open, is listed under each example.
// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/engine/a2ui_stream.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_view.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

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

  /// The component types the example uses that the catalog has no builder
  /// for.
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
        if (A2UICatalog.basic[type] == null) type,
    ]..sort();
  }
}

Future<List<Example>> _loadExamples() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final files = manifest.listAssets().where((path) => path.startsWith('assets/examples/')).toList()..sort();
  final examples = <Example>[
    Example(
      name: 'A weekend in Ohrid',
      file: 'ohrid_prompt_example.jsonl',
      messages: A2UIStream.messages(await rootBundle.loadString('assets/ohrid_prompt_example.jsonl')),
    ),
  ];
  for (final path in files) {
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
            itemCount: examples.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final example = examples[index];
              final missing = example.missing;
              return ListTile(
                title: Text(example.name),
                subtitle: Text(missing.isEmpty ? example.file : '${example.file} · later: ${missing.join(', ')}'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => ExamplePage(example: example, onToggleMode: widget.onToggleMode),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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
  final _errors = <A2UIError>[];
  // What the person's actions did: each event an agent would get, with its
  // values, and each link that would open, newest last.
  final _log = <String>[];
  late final A2UIProcessor _processor = A2UIProcessor(
    catalogs: A2UICatalogs(),
    onAction: _handleAction,
    onError: _handleError,
  );
  late final AIUIHost _host = AIUIHost(
    renderers: [_GalleryRenderer(_processor, onOpenLink: _handleOpenLink)],
    send: (action) async {},
  );

  // How many of the example's messages are applied, and whether they are
  // being written one by one, as an agent streams them.
  int _applied = 0;
  bool _isStreaming = false;
  int _replay = 0;

  // The pause between two messages of a replay.
  static const _messagePause = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _processor.apply(widget.example.messages);
    _applied = widget.example.messages.length;
  }

  // A problem can be reported while messages apply, during a build or before
  // the page is on screen, so the page shows it after the frame.
  void _handleError(A2UIError error) {
    _errors.add(error);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        // The problem was added to _errors.
      });
    });
  }

  void _handleAction(A2UIActionEvent event) {
    final userMessage = event.userMessage == null ? '' : ' “${event.userMessage}”';
    setState(() => _log.add('Sent ${event.name}$userMessage ${jsonEncode(event.context)}'));
  }

  // The gallery has nowhere to open a link, so it only shows it.
  void _handleOpenLink(Uri link) {
    setState(() => _log.add('Opened $link'));
  }

  @override
  void dispose() {
    _host.dispose();
    _processor.dispose();
    super.dispose();
  }

  Future<void> _replayMessages() async {
    _replay += 1;
    final replay = _replay;
    setState(() {
      _processor.reset();
      _errors.clear();
      _log.clear();
      _applied = 0;
      _isStreaming = true;
    });
    for (final message in widget.example.messages) {
      await Future<void>.delayed(_messagePause);
      if (!mounted || replay != _replay) return;
      setState(() {
        _processor.apply([message]);
        _applied += 1;
      });
    }
    setState(() => _isStreaming = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    final missing = widget.example.missing;
    final document = AIUIDocument(format: AIUIFormat.a2ui, isStreaming: _isStreaming, content: '$_applied');
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
            if (missing.isNotEmpty) _Note('Not drawn yet: ${missing.join(', ')}'),
            AIUIView(
              key: ValueKey(_replay),
              host: _host,
              document: document,
              messageId: widget.example.file,
            ),
            for (final entry in _log) _Note(entry),
            for (final error in _errors) _Note('${error.code}: ${error.message}'),
          ],
        ),
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

// Shows the surfaces of one processor as a reply's UI, 12 apart.
class _GalleryRenderer extends AIUIRenderer {
  _GalleryRenderer(this.processor, {required this.onOpenLink});

  final A2UIProcessor processor;
  final A2UIOpenLink onOpenLink;

  @override
  AIUIFormat get format => AIUIFormat.a2ui;

  @override
  AIUIEngine createEngine(AIUIHosting host) => _GalleryEngine(processor, onOpenLink: onOpenLink);
}

class _GalleryEngine extends AIUIEngine {
  _GalleryEngine(this.processor, {required this.onOpenLink});

  final A2UIProcessor processor;
  final A2UIOpenLink onOpenLink;

  @override
  Widget? view(AIUIDocument document, String messageId) {
    return ListenableBuilder(
      listenable: processor,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          for (final surfaceId in processor.surfaceIds)
            A2UISurfaceView(
              key: ValueKey(processor.surface(surfaceId)),
              surface: processor.surface(surfaceId)!,
              onOpenLink: onOpenLink,
            ),
        ],
      ),
    );
  }
}
