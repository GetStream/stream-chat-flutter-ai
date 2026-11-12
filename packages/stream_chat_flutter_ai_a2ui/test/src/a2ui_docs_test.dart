import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_catalog.dart';

import 'a2ui_test_app.dart';

// The documentation keeps up with the catalog: every component of
// `A2UICatalog.basic` has a section in `doc/components.md` and an example for
// the gallery, the JSON in the sections is A2UI the renderer shows, and the
// links in the documents lead somewhere.
void main() {
  final components = File('doc/components.md').readAsStringSync();
  final sections = _sections(components);

  for (final type in A2UICatalog.basic.types) {
    test('$type has a section in doc/components.md', () {
      expect(sections.keys, contains(type));
    });

    test('$type has an example for the gallery', () {
      expect(File('example/assets/components/${_snake(type)}.json').existsSync(), isTrue);
    });

    testWidgets('the JSON in the $type section shows without reporting anything', (tester) async {
      final json = sections[type]?.blocks ?? const [];
      final snippets = [
        for (final block in json)
          if (block.info == 'json') block,
      ];
      expect(snippets, isNotEmpty);

      for (final snippet in snippets) {
        final errors = <A2UIError>[];
        // The data model of a snippet follows it.
        final data = switch (json.indexOf(snippet) + 1) {
          final next when next < json.length && json[next].info == 'json data' => json[next].text,
          _ => '{}',
        };
        final components = (jsonDecode(snippet.text) as List<Object?>).cast<Map<String, Object?>>();

        final processor = await pumpSurface(
          tester,
          components: components,
          data: jsonDecode(data) as Map<String, Object?>,
          errors: errors,
        );
        await tester.pump();

        expect(errors, isEmpty, reason: snippet.text);
        // The snippet shows its own component, in a surface that has a root.
        expect([for (final component in components) component['component']], contains(type), reason: snippet.text);
        expect(processor.surface('s')!.root, isNotNull, reason: snippet.text);
      }
    });
  }

  test('the examples of the gallery are all linked from doc/components.md', () {
    final linked = RegExp(r'\(\.\./example/assets/components/(\w+)\.json\)').allMatches(components);
    expect({for (final match in linked) match[1]}, {for (final type in A2UICatalog.basic.types) _snake(type)});
  });

  test('the example app registers the gallery assets', () {
    expect(File('example/pubspec.yaml').readAsStringSync(), contains('    - assets/components/\n'));
  });

  test('the link reading finds titled, reference-style and href links', () {
    const markdown = '[a](x.md "title") [b](<y.md>)\n[c]: z.md "t"\n<a href="w.md">d</a>';

    expect(_links(markdown), ['x.md', 'y.md', 'z.md', 'w.md']);
  });

  test('the published documents never mention the internal docs', () {
    for (final path in ['README.md', 'doc/components.md', 'example/README.md']) {
      expect(File(path).readAsStringSync(), isNot(contains('docs/a2ui')), reason: path);
    }
  });

  for (final path in [
    'README.md',
    'doc/components.md',
    'example/README.md',
    for (final file in Directory('../../docs/a2ui').listSync().whereType<File>()) file.path,
  ]) {
    test('every link in $path to a file or folder leads to one', () {
      final base = File(path).parent.path;
      final missing = [
        for (final link in _links(File(path).readAsStringSync()))
          if (!_isExternal(link) && !_exists(path, base, link)) link,
      ];

      expect(missing, isEmpty);
    });
  }
}

// The targets of the links in [markdown]: inline links, with or without a
// title, reference definitions and `<a href>` links.
List<String> _links(String markdown) {
  return [
    for (final match in RegExp(r'\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)').allMatches(markdown)) match[1]!,
    for (final match in RegExp(r'^\s{0,3}\[[^\]]+\]:\s*<?(\S+?)>?(?:\s+.*)?$', multiLine: true).allMatches(markdown))
      match[1]!,
    for (final match in RegExp('href=["\']([^"\']+)["\']').allMatches(markdown)) match[1]!,
  ];
}

bool _isExternal(String link) => link.startsWith('http') || link.startsWith('mailto:');

bool _exists(String file, String base, String link) {
  final parts = link.split('#');
  // A fragment names a heading of the file it is in, or of the one it links.
  final path = parts.first.isEmpty ? file : '$base/${parts.first}';
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) return false;
  if (parts.length < 2 || !path.endsWith('.md')) return true;
  return _anchors(File(path).readAsStringSync()).contains(parts[1]);
}

// The anchors GitHub gives the headings of [markdown].
Set<String> _anchors(String markdown) {
  return {
    for (final line in const LineSplitter().convert(markdown))
      if (RegExp('^#{1,6} (.*)').firstMatch(line) case final match?)
        match[1]!.toLowerCase().replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '-'),
  };
}

// `AudioPlayer` as `audio_player`, the name of its example.
String _snake(String type) {
  return type.replaceAllMapped(RegExp('(?<!^)[A-Z]'), (match) => '_${match[0]}').toLowerCase();
}

typedef _Block = ({String info, String text});

// The `## ` sections of [markdown] by title, each with its fenced code blocks.
Map<String, ({List<_Block> blocks})> _sections(String markdown) {
  final sections = <String, List<_Block>>{};
  List<_Block>? current;
  String? info;
  final text = StringBuffer();
  for (final line in const LineSplitter().convert(markdown)) {
    if (info != null) {
      if (line.startsWith('```')) {
        current?.add((info: info, text: text.toString()));
        info = null;
        text.clear();
      } else {
        text.writeln(line);
      }
    } else if (line.startsWith('```')) {
      info = line.substring(3).trim();
    } else if (line.startsWith('## ')) {
      current = sections[line.substring(3).trim()] = [];
    }
  }
  return {for (final entry in sections.entries) entry.key: (blocks: entry.value)};
}
