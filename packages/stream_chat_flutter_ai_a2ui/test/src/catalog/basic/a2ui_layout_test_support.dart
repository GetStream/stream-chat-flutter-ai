import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_image.dart';

// An image with [id], in a box of [variant]'s size: 24 by 24 for the default
// `icon`, 48 by 48 for `avatar`. It loads nothing when the test's `mediaUrl`
// gives no URL.
Map<String, Object?> iconImage(String id, {String variant = 'icon'}) => {
  'id': id,
  'component': 'Image',
  'url': 'https://example.com/$id.png',
  'variant': variant,
};

// The box of the image with [id].
Finder imageBox(String id) =>
    find.byWidgetPredicate((widget) => widget is A2UIImageView && widget.url == 'https://example.com/$id.png');

// Where the box of the image with [id] is, from the top left of [of].
Offset imageOffset(WidgetTester tester, String id, Finder of) =>
    tester.getTopLeft(imageBox(id)) - tester.getTopLeft(of);
