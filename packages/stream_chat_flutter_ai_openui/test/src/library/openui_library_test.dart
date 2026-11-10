import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_card.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_card_header.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_text_content.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_name.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

import '../openui_test_app.dart';

Widget _brand(BuildContext context, OpenUIComponentScope scope) => const Text('brand');
Widget _other(BuildContext context, OpenUIComponentScope scope) => const Text('other');

const _drawn = [
  'CardHeader',
  'TextContent',
  'MarkDownRenderer',
  'Callout',
  'TextCallout',
  'Separator',
  'InlineHeader',
  'Label',
  'Image',
  'ImageBlock',
  'ImageGallery',
  'CodeBlock',
  'Tag',
  'TagBlock',
  'Icon',
  'EntityList',
  'Text',
  'BoldText',
  'IconText',
  'ImageText',
  'ImageTextLarge',
  'MetricIndicatorInline',
  'MetricIndicatorWithStrikethrough',
  'SnippetCardBlock',
  'OverviewCardBlock',
  'ContextCardBlock',
  'CompositeCardBlock',
  'VisualCardBlock',
];

void main() {
  group('built-in libraries', () {
    test('chat has the chat library components and draws Card and the content, data and card components', () {
      final chat = OpenUILibrary.chat;

      expect(chat.types, LibraryDefinition.chat.componentNames);
      expect(chat.definition, same(LibraryDefinition.chat));
      expect(chat['Card'], buildOpenUIChatCard);
      expect(chat['CardHeader'], buildOpenUICardHeader);
      expect(chat['TextContent'], buildOpenUITextContent);
      expect(chat.types.where((type) => chat[type] != null), unorderedEquals(['Card', ..._drawn]));
    });

    test('standard has the standard library components and draws the same components, other than Card', () {
      final standard = OpenUILibrary.standard;

      expect(standard.types, LibraryDefinition.standard.componentNames);
      expect(standard.types.where((type) => standard[type] != null), unorderedEquals(_drawn));
    });

    test('a type with no builder gives null', () {
      expect(OpenUILibrary.chat['Table'], isNull);
      expect(OpenUILibrary.chat['Nope'], isNull);
    });
  });

  group('replacing', () {
    test('puts the builder in place of the built-in one', () {
      final library = OpenUILibrary.chat.replacing('Card', _brand);

      expect(library['Card'], _brand);
      expect(library['CardHeader'], buildOpenUICardHeader);
      expect(library.replacedBuilderOf('Card'), buildOpenUIChatCard);
      expect(library.replacedBuilderOf('CardHeader'), isNull);
    });

    test('takes a type this package does not draw yet', () {
      final library = OpenUILibrary.chat.replacing('Table', _brand);

      expect(library['Table'], _brand);
      expect(library.replacedBuilderOf('Table'), isNull);
    });

    test('takes a component name constant', () {
      expect(OpenUILibrary.chat.replacing(OpenUIComponentName.card, _brand)['Card'], _brand);
    });

    test('asserts on a type the library does not have', () {
      expect(() => OpenUILibrary.chat.replacing('Nope', _brand), throwsAssertionError);
    });

    test('keeps the types the model is taught', () {
      expect(OpenUILibrary.chat.replacing('Card', _brand).types, OpenUILibrary.chat.types);
    });

    testWidgets('the replacement draws, and can draw the built-in component', (tester) async {
      final library = OpenUILibrary.chat.replacing('CardHeader', (context, scope) {
        return Column(children: [const Text('brand'), scope.buildDefault()]);
      });
      await pumpOpenUI(
        tester,
        testRuntime(library: library),
        library: library,
        program: 'root = Card([CardHeader("Title")])',
      );

      expect(find.text('brand'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
    });
  });

  group('removing', () {
    test('takes the components out of the library and their builders', () {
      final library = OpenUILibrary.chat.removing(['CardHeader', 'Table']);

      expect(library.types, isNot(contains('CardHeader')));
      expect(library.types, isNot(contains('Table')));
      expect(library['CardHeader'], isNull);
      expect(library['TextContent'], buildOpenUITextContent);
      expect(library.definition.componentNames, library.types);
    });

    test('keeps the root', () {
      final library = OpenUILibrary.chat.removing(['Card']);

      expect(library.types, contains('Card'));
      expect(library['Card'], buildOpenUIChatCard);
    });

    test("keeps a type that is the only one a remaining component's prop takes", () {
      final expected = LibraryDefinition.chat.removing(['ListItem']).componentNames;
      final library = OpenUILibrary.chat.removing(['ListItem']);

      expect(library.types, expected);
      expect(expected, contains('ListItem'));
    });

    test('adds up over calls', () {
      final library = OpenUILibrary.chat.removing(['CardHeader']).removing(['Table']);

      expect(library, OpenUILibrary.chat.removing(['CardHeader', 'Table']));
    });

    test('remembers a type kept for another component, and removes it with that one', () {
      final library = OpenUILibrary.standard.removing(['ListItem']).removing(['ListBlock']);

      expect(OpenUILibrary.standard.removing(['ListItem']).types, contains('ListItem'));
      expect(library.types, isNot(contains('ListItem')));
      expect(library, OpenUILibrary.standard.removing(['ListItem', 'ListBlock']));
    });

    test('asserts on a type the library does not have', () {
      expect(() => OpenUILibrary.chat.removing(['Nope']), throwsAssertionError);
    });
  });

  group('equality', () {
    test('libraries made the same way are equal and share a hash code', () {
      final a = OpenUILibrary.chat.replacing('Card', _brand).removing(['Table']);
      final b = OpenUILibrary.chat.replacing('Card', _brand).removing(['Table']);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different base, removal or builder makes libraries unequal', () {
      expect(OpenUILibrary.chat, isNot(OpenUILibrary.standard));
      expect(OpenUILibrary.chat.removing(['Table']), isNot(OpenUILibrary.chat));
      expect(OpenUILibrary.chat.replacing('Card', _brand), isNot(OpenUILibrary.chat.replacing('Card', _other)));
    });
  });

  group('component names', () {
    test('there is one for each component of the chat and standard libraries', () {
      final names = {...LibraryDefinition.chat.componentNames, ...LibraryDefinition.standard.componentNames};

      final source = File('lib/src/library/openui_component_name.dart').readAsStringSync();
      final constants = [
        for (final match in RegExp(r"static const (\w+) = OpenUIComponentName\('(\w+)'\);").allMatches(source))
          (match.group(1)!, match.group(2)!),
      ];

      expect(constants, hasLength(86));
      expect(constants.map((constant) => constant.$2).toSet(), names);
      for (final (constant, name) in constants) {
        expect(constant, name.replaceRange(0, 1, name[0].toLowerCase()));
      }
      expect(<String>[OpenUIComponentName.card, OpenUIComponentName.textContent], ['Card', 'TextContent']);
    });
  });
}
