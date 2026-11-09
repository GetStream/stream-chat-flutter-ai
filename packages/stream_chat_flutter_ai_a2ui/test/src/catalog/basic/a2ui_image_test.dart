import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_image.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

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

      expect(tester.widget<Image>(find.byType(Image)).fit, boxFit);
    });
  }

  testWidgets('an image without a fit is stretched to its box', (tester) async {
    await _pumpImage(tester);

    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.fill);
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

    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a file URL is not loaded by default', (tester) async {
    await _pumpImage(tester, url: 'file:///etc/hosts');

    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a name without a scheme is not loaded', (tester) async {
    await _pumpImage(tester, url: 'lake.png');

    expect(find.byType(Image), findsNothing);
  });

  testWidgets('the media function is not asked for a name without a scheme', (tester) async {
    final asked = <Uri>[];

    await _pumpImage(tester, url: 'lake.png', mediaUrl: (url) => (asked..add(url)).last);

    expect(asked, isEmpty);
  });

  testWidgets('an image shows a spinner while it loads', (tester) async {
    await _pumpImage(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an image that cannot load leaves its box empty', (tester) async {
    await _pumpImageThatFails(tester);

    final content = find.descendant(of: find.byType(Image), matching: find.byType(SizedBox));

    expect(tester.widget<SizedBox>(content).child, isNull);
  });

  testWidgets('an image is decoded at most 1,200 pixels wide', (tester) async {
    await _pumpImage(tester);

    expect(_decoding(tester).width, _maxDecodedPixels);
  });

  testWidgets('an image is decoded at most 1,200 pixels high', (tester) async {
    await _pumpImage(tester);

    expect(_decoding(tester).height, _maxDecodedPixels);
  });

  testWidgets('an image is decoded with its aspect ratio kept', (tester) async {
    await _pumpImage(tester);

    expect(_decoding(tester).policy, ResizeImagePolicy.fit);
  });

  testWidgets('an image smaller than the decoding limit is not decoded larger', (tester) async {
    await _pumpImage(tester);

    expect(_decoding(tester).allowUpscaling, isFalse);
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

// The longest side an image is decoded at.
const _maxDecodedPixels = 1200;

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

// The URL the image is loaded from.
String _loadedUrl(WidgetTester tester) {
  return (_decoding(tester).imageProvider as CachedNetworkImageProvider).url;
}

// The decoding of the image: its size limit and how the image is fitted to it.
ResizeImage _decoding(WidgetTester tester) => tester.widget<Image>(find.byType(Image)).image as ResizeImage;

// Shows an image whose loading fails. A real load never ends in a widget
// test, because the image's file cache waits for plugins, so the image cache
// is given a failing load under the key of the image, which a first showing
// gives, before the image shows again.
Future<void> _pumpImageThatFails(WidgetTester tester) async {
  await _pumpImage(tester);
  final key = await _decoding(tester).obtainKey(ImageConfiguration.empty);
  await tester.pumpWidget(const SizedBox());
  final imageCache = PaintingBinding.instance.imageCache..clear();
  addTearDown(imageCache.clear);
  final load = Completer<ImageInfo>();
  imageCache.putIfAbsent(key, () => OneFrameImageStreamCompleter(load.future));

  await _pumpImage(tester);
  load.completeError(StateError('The image could not be loaded.'));
  await tester.pump();
}
