import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_image.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_media.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:stream_core_flutter/core.dart';

import '../../a2ui_test_app.dart';

void main() {
  for (final (variant, size) in [
    ('icon', const Size(24, 24)),
    ('avatar', const Size(48, 48)),
    ('smallFeature', const Size(72, 72)),
    ('mediumFeature', const Size(160, 160)),
    ('largeFeature', const Size(240, 240)),
  ]) {
    testWidgets('a $variant image is ${size.width} by ${size.height}', (tester) async {
      await _pumpImage(tester, variant: variant);

      expect(tester.getSize(_box()), size);
    });
  }

  testWidgets('a header image is as wide as the surface and 200 high', (tester) async {
    await _pumpImage(tester, variant: 'header', width: 300);

    expect(tester.getSize(_box()), const Size(300, 200));
  });

  testWidgets('an image without a variant is a medium feature', (tester) async {
    await _pumpImage(tester);

    expect(tester.getSize(_box()), const Size(160, 160));
  });

  testWidgets('an image of a variant the catalog does not have is a medium feature', (tester) async {
    await _pumpImage(tester, variant: 'poster');

    expect(tester.getSize(_box()), const Size(160, 160));
  });

  testWidgets('an avatar is a circle', (tester) async {
    await _pumpImage(tester, variant: 'avatar');

    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets("an image's corners have the control corner radius", (tester) async {
    await _pumpImage(tester);

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));

    expect(clip.borderRadius, BorderRadius.circular(lightTheme().controlCornerRadius));
  });

  testWidgets('an image box shows the subtle surface color', (tester) async {
    await _pumpImage(tester);

    expect(tester.widget<ColoredBox>(_box()).color, lightTheme().subtleSurface);
  });

  for (final (fit, boxFit) in [
    ('contain', BoxFit.contain),
    ('cover', BoxFit.cover),
    ('fill', BoxFit.fill),
    ('none', BoxFit.none),
    ('scaleDown', BoxFit.scaleDown),
  ]) {
    testWidgets('an image that fits by $fit is scaled by $boxFit', (tester) async {
      await _pumpImage(tester, fit: fit);

      expect(_props(tester).fit, boxFit);
    });
  }

  testWidgets('an image without a fit is stretched to its box', (tester) async {
    await _pumpImage(tester);

    expect(_props(tester).fit, BoxFit.fill);
  });

  testWidgets('an image loads from the URL the media function gives', (tester) async {
    await _pumpImage(tester, mediaUrl: (url) => Uri.parse('https://cdn.example.com${url.path}'));

    expect(_loadedUrl(tester), 'https://cdn.example.com/lake.png');
  });

  testWidgets('the media function gets the URL the agent wrote', (tester) async {
    final asked = <Uri>[];

    await _pumpImage(tester, mediaUrl: (url) => (asked..add(url)).last);

    expect(asked, [Uri.parse('https://example.com/lake.png')]);
  });

  testWidgets('an image whose URL the media function refuses is not loaded', (tester) async {
    await _pumpImage(tester, mediaUrl: (url) => null);

    expect(find.byType(StreamNetworkImage), findsNothing);
  });

  testWidgets('a file URL is not loaded by default', (tester) async {
    await _pumpImage(tester, url: 'file:///etc/hosts');

    expect(find.byType(StreamNetworkImage), findsNothing);
  });

  testWidgets('a name without a scheme is not loaded', (tester) async {
    await _pumpImage(tester, url: 'lake.png');

    expect(find.byType(StreamNetworkImage), findsNothing);
  });

  testWidgets('the media function is not asked for a name without a scheme', (tester) async {
    final asked = <Uri>[];

    await _pumpImage(tester, url: 'lake.png', mediaUrl: (url) => (asked..add(url)).last);

    expect(asked, isEmpty);
  });

  testWidgets('an image shows a spinner while it loads', (tester) async {
    await _pumpImage(tester);

    expect(_props(tester).placeholderBuilder!(tester.element(_image)), isA<A2UISpinner>());
  });

  testWidgets('an image that cannot load leaves its box empty', (tester) async {
    await _pumpImage(tester);

    final empty = _props(tester).errorBuilder!(tester.element(_image), StateError('No image.'), () {});

    expect(empty, isA<SizedBox>().having((box) => box.child, 'child', isNull));
  });

  testWidgets("the app's network image builder loads the image", (tester) async {
    String? loaded;
    await pumpSurface(
      tester,
      components: [
        {'id': 'root', 'component': 'Image', 'url': 'https://example.com/lake.png'},
      ],
      builders: StreamComponentBuilders(
        networkImage: (context, props) {
          loaded = props.url;
          return const SizedBox();
        },
      ),
    );

    expect(loaded, 'https://example.com/lake.png');
  });

  for (final fit in ['contain', 'scaleDown']) {
    testWidgets('an image that fits by $fit is decoded as wide as its box', (tester) async {
      await _pumpImage(tester, variant: 'smallFeature', fit: fit);

      expect(_props(tester).cacheWidth, (72 * tester.view.devicePixelRatio).ceil());
    });
  }

  for (final fit in ['cover', 'fill']) {
    testWidgets('an image that fits by $fit is decoded twice as wide as its box', (tester) async {
      await _pumpImage(tester, variant: 'smallFeature', fit: fit);

      expect(_props(tester).cacheWidth, (2 * 72 * tester.view.devicePixelRatio).ceil());
    });
  }

  testWidgets('an image without a fit is decoded twice as wide as its box', (tester) async {
    await _pumpImage(tester, variant: 'smallFeature');

    expect(_props(tester).cacheWidth, (2 * 72 * tester.view.devicePixelRatio).ceil());
  });

  testWidgets('an image that fits by none is decoded at its own size', (tester) async {
    await _pumpImage(tester, fit: 'none');

    expect(_props(tester).cacheWidth, isNull);
  });

  testWidgets('a header image is decoded as wide as the screen', (tester) async {
    await _pumpImage(tester, variant: 'header', fit: 'contain');

    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    expect(_props(tester).cacheWidth, (screenWidth * tester.view.devicePixelRatio).ceil());
  });

  testWidgets('an image is decoded with its aspect ratio kept', (tester) async {
    await _pumpImage(tester);

    expect(_props(tester).cacheHeight, isNull);
  });

  testWidgets("an image's description is its label", (tester) async {
    await _pumpImage(tester, description: 'The lake at dusk');

    expect(find.semantics.byLabel('The lake at dusk'), findsOne);
  });

  testWidgets('an image with a description is read as an image', (tester) async {
    await _pumpImage(tester, description: 'The lake at dusk');

    expect(
      tester.getSemantics(find.bySemanticsLabel('The lake at dusk')),
      matchesSemantics(label: 'The lake at dusk', isImage: true),
    );
  });

  testWidgets('an image without a description or a label is skipped by assistive technologies', (tester) async {
    await _pumpImage(tester);

    expect(find.semantics.byPredicate((node) => node.flagsCollection.isImage), findsNothing);
  });

  testWidgets('an image the agent labels is not skipped', (tester) async {
    await _pumpImage(tester, accessibilityLabel: 'Logo');

    expect(find.semantics.byPredicate((node) => node.flagsCollection.isImage), findsOne);
  });

  testWidgets('an image with an empty description and no label is skipped by assistive technologies', (tester) async {
    await _pumpImage(tester, description: '');

    expect(find.semantics.byPredicate((node) => node.flagsCollection.isImage), findsNothing);
  });

  testWidgets('an image with an empty label and no description is skipped by assistive technologies', (tester) async {
    await _pumpImage(tester, accessibilityLabel: '');

    expect(find.semantics.byPredicate((node) => node.flagsCollection.isImage), findsNothing);
  });

  testWidgets('an image whose description is bound to data not there yet is not skipped', (tester) async {
    await _pumpImage(tester, description: {'@path': '/description'});

    expect(find.semantics.byPredicate((node) => node.flagsCollection.isImage), findsOne);
  });

  testWidgets('an image whose label is bound to data not there yet is not skipped', (tester) async {
    await _pumpImage(tester, accessibilityLabel: {'@path': '/label'});

    expect(find.semantics.byPredicate((node) => node.flagsCollection.isImage), findsOne);
  });
}

// The box of the image, which shows the subtle surface color.
Finder _box() => find.descendant(of: find.byType(A2UIImageView), matching: find.byType(ColoredBox));

Future<void> _pumpImage(
  WidgetTester tester, {
  String url = 'https://example.com/lake.png',
  String? variant,
  String? fit,
  Object? description,
  Object? accessibilityLabel,
  Uri? Function(Uri url)? mediaUrl,
  double width = 400,
}) async {
  await pumpSurface(
    tester,
    components: [
      {
        'id': 'root',
        'component': 'Image',
        'url': url,
        'variant': ?variant,
        'fit': ?fit,
        'description': ?description,
        if (accessibilityLabel != null) 'accessibility': {'label': accessibilityLabel},
      },
    ],
    mediaUrl: mediaUrl ?? a2uiWebMediaUrl,
    width: width,
  );
}

// The image in its box.
final _image = find.byType(StreamNetworkImage);

// What the image is loaded and drawn with.
StreamNetworkImageProps _props(WidgetTester tester) => tester.widget<StreamNetworkImage>(_image).props;

// The URL the image is loaded from.
String _loadedUrl(WidgetTester tester) => _props(tester).url;
