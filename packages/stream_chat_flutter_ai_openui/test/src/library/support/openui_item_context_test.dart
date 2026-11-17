import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/components/openui_card_blocks.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_item_context.dart';

void main() {
  const item = {'itemIndex': 0.0, 'itemTitle': 'One'};

  group('mergeOpenUIItemContext', () {
    test('without an action makes a continue_conversation action with the item as params', () {
      expect(mergeOpenUIItemContext(null, item), {'type': 'continue_conversation', 'params': item});
    });

    test('a single action keeps its params, url and context, and the item wins on a clash', () {
      final merged = mergeOpenUIItemContext({
        'type': 'open_url',
        'url': 'https://a.dev',
        'context': 'ctx',
        'params': {'itemTitle': 'old', 'keep': 1.0},
      }, item);

      expect(merged, {
        'type': 'open_url',
        'params': {'itemTitle': 'One', 'keep': 1.0, 'url': 'https://a.dev', 'context': 'ctx', 'itemIndex': 0.0},
      });
    });

    test('a single action with no type is a continue_conversation, and an empty context is left out', () {
      expect(mergeOpenUIItemContext({'context': ''}, item), {'type': 'continue_conversation', 'params': item});
    });

    test('a plan adds the item to the context of each continue_conversation step, after what it has', () {
      final merged = mergeOpenUIItemContext({
        'steps': [
          {'type': 'continue_conversation', 'context': 'Pick'},
          {'type': 'continue_conversation'},
          {'type': 'open_url', 'url': 'https://a.dev'},
        ],
      }, item);

      const suffix = 'Selected item: {"itemIndex":0,"itemTitle":"One"}';
      expect(merged, {
        'steps': [
          {'type': 'continue_conversation', 'context': 'Pick\n$suffix'},
          {'type': 'continue_conversation', 'context': suffix},
          {'type': 'open_url', 'url': 'https://a.dev'},
        ],
      });
    });

    test('a plan is returned as it is when the item is empty', () {
      final plan = {
        'steps': [
          {'type': 'continue_conversation'},
        ],
      };

      expect(mergeOpenUIItemContext(plan, const {}), same(plan));
    });
  });

  group('normalizeOpenUICompositeProps', () {
    ElementNode node(String type, [Map<String, OpenUIValue> props = const {}]) =>
        ElementNode(typeName: type, props: props, partial: false, hasDynamicProps: false);

    test('draws a body Text small and leaves a footer Text as it is', () {
      expect(normalizeOpenUICompositeProps(node('Text'), footer: false).props['size'], const OpenUIString('xs'));
      expect(normalizeOpenUICompositeProps(node('BoldText'), footer: false).props['size'], const OpenUIString('xs'));
      expect(normalizeOpenUICompositeProps(node('Text'), footer: true).props, isEmpty);
    });

    test('gives a chart its height, and a list, tag block and button their small sizes', () {
      expect(normalizeOpenUICompositeProps(node('BarChart'), footer: false).props['height'], const OpenUINumber(180));
      expect(
        normalizeOpenUICompositeProps(node('ListBlock'), footer: false).props['size'],
        const OpenUIString('small'),
      );
      expect(normalizeOpenUICompositeProps(node('TagBlock'), footer: false).props['size'], const OpenUIString('sm'));
      expect(normalizeOpenUICompositeProps(node('Button'), footer: true).props['size'], const OpenUIString('small'));
    });

    test('makes an EntityList small and takes its header and footer away', () {
      final normalized = normalizeOpenUICompositeProps(
        node('EntityList', {
          'header': const OpenUIString('h'),
          'footer': const OpenUIString('f'),
          'rows': OpenUIArray(const []),
        }),
        footer: false,
      );

      expect(normalized.props.keys, unorderedEquals(['rows', 'size']));
      expect(normalized.props['size'], const OpenUIString('small'));
    });

    test('returns any other component as it is', () {
      final other = node('Image');

      expect(normalizeOpenUICompositeProps(other, footer: false), same(other));
    });
  });
}
