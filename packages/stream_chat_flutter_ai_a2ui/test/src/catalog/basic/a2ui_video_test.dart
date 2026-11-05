import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_image.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_media.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

import '../../a2ui_test_app.dart';
import 'a2ui_media_fakes.dart';

const _clip = 'https://example.com/clip.mp4';
const _poster = 'https://example.com/poster.jpg';

void main() {
  testWidgets('a Video shows the poster at its posterUrl before it plays', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster});

    expect(_posterImage(tester), _imageAt(_poster));
  });

  testWidgets('a Video loads nothing but the poster until the person plays it', (tester) async {
    final platform = installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster});
    await tester.pumpAndSettle();

    expect(platform.created, isEmpty);
  });

  testWidgets('a Video loads its video once the person taps play', (tester) async {
    final platform = installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip});
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    expect(platform.created, [_clip]);
  });

  testWidgets('a Video plays once its video loads after the tap', (tester) async {
    final platform = installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    expect(platform.played, [0]);
  });

  testWidgets('a Video does not play again on its own after the person pauses it', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);
    platform.reportPlaying(0, isPlaying: true);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(platform.played, [0]);
  });

  testWidgets('a Video keeps its poster, with a spinner, while its video loads', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster});
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    expect(
      (poster: _posterImage(tester), spinners: find.byType(A2UISpinner).evaluate().length),
      (
        poster: _imageAt(_poster),
        spinners: 1,
      ),
    );
  });

  testWidgets('a Video shows the player in place of its poster once the video loads', (tester) async {
    final platform = installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster});
    await _playAndLoad(tester, platform);

    expect(
      (players: find.byType(Chewie).evaluate().length, posters: find.byType(Image).evaluate().length),
      (
        players: 1,
        posters: 0,
      ),
    );
  });

  testWidgets('a Video loads its video from the URL the media function gives', (tester) async {
    final platform = installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip}, mediaUrl: _throughProxy);
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    expect(platform.created, ['https://proxy.example.com/clip.mp4']);
  });

  testWidgets('a Video loads its poster from the URL the media function gives', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster}, mediaUrl: _throughProxy);

    expect(_posterImage(tester), _imageAt('https://proxy.example.com/poster.jpg'));
  });

  testWidgets('a Video whose URL the media function refuses has no play button', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': 'file:///clip.mp4'});

    expect(find.byType(A2UIPlayButton), findsNothing);
  });

  testWidgets('a Video whose URL the media function refuses shows that it cannot play', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': 'file:///clip.mp4'});

    expect(find.byType(A2UIMediaUnavailable), findsOneWidget);
  });

  testWidgets('a Video whose URL has no scheme shows that it cannot play', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': 'clip.mp4'});

    expect(find.byType(A2UIMediaUnavailable), findsOneWidget);
  });

  testWidgets('a Video whose URL has no scheme does not call the media function', (tester) async {
    installFakeVideoPlatform();
    final asked = <Uri>[];

    await _pumpVideo(
      tester,
      video: {'url': 'clip.mp4'},
      mediaUrl: (url) {
        asked.add(url);
        return url;
      },
    );

    expect(asked, isEmpty);
  });

  testWidgets('a Video whose URL is not in the data model yet shows that it cannot play', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(
      tester,
      video: {
        'url': {'@path': '/trailer'},
      },
    );

    expect(find.byType(A2UIMediaUnavailable), findsOneWidget);
  });

  testWidgets('a Video shows no poster when the media function refuses the poster URL', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': 'file:///poster.jpg'});

    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a Video lets its player go when it leaves the widget tree', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);

    expect(platform.disposed, [0]);
  });

  testWidgets('a Video lets its player go when its URL changes', (tester) async {
    final platform = installFakeVideoPlatform();
    final processor = await _pumpVideo(
      tester,
      video: {
        'url': {'@path': '/trailer'},
      },
      data: {'trailer': _clip},
    );
    await _playAndLoad(tester, platform);

    processor.apply([updateData('/trailer', 'https://example.com/other.mp4')]);
    await tester.pump();
    await _settle(tester);

    expect(platform.disposed, [0]);
  });

  testWidgets('a Video shows its play button again when its URL changes', (tester) async {
    final platform = installFakeVideoPlatform();
    final processor = await _pumpVideo(
      tester,
      video: {
        'url': {'@path': '/trailer'},
      },
      data: {'trailer': _clip},
    );
    await _playAndLoad(tester, platform);

    processor.apply([updateData('/trailer', 'https://example.com/other.mp4')]);
    await tester.pump();

    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });

  testWidgets('a Video keeps its player when only its poster changes', (tester) async {
    final platform = installFakeVideoPlatform();
    final processor = await _pumpVideo(
      tester,
      video: {
        'url': _clip,
        'posterUrl': {'@path': '/poster'},
      },
      data: {'poster': _poster},
    );
    await _playAndLoad(tester, platform);

    processor.apply([updateData('/poster', 'https://example.com/other.jpg')]);
    await tester.pump();
    await tester.pump();

    expect(
      (disposed: platform.disposed.length, players: find.byType(Chewie).evaluate().length),
      (
        disposed: 0,
        players: 1,
      ),
    );
  });

  testWidgets('a Video lets go of a player that is still loading when it leaves the widget tree', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);

    expect(platform.disposed, [0]);
  });

  testWidgets('a Video shows its play button again when its video fails to load', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    platform.fail(0);
    await tester.pump();

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });

  testWidgets('a Video lets go of its player when its video fails to load', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    platform.fail(0);
    await _settle(tester);

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(platform.disposed, [0]);
  });

  testWidgets('a Video shows its play button again when its video fails while it plays', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    platform.fail(0);
    await tester.pump();
    await tester.pump();

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(
      (players: find.byType(Chewie).evaluate().length, play: find.bySemanticsLabel('Play').evaluate().length),
      (
        players: 0,
        play: 1,
      ),
    );
  });

  testWidgets('a Video loads its video again when the person taps play after a failure', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();
    platform.fail(0);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(platform.created, [_clip, _clip]);
  });

  testWidgets('a Video that plays offers to pause it', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    platform.reportPlaying(0, isPlaying: true);
    await tester.pump();

    expect(find.bySemanticsLabel('Pause'), findsOneWidget);
  });

  testWidgets('a Video pauses when the person taps it while it plays', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);
    platform.reportPlaying(0, isPlaying: true);
    await tester.pump();
    final pausesBefore = platform.paused.length;

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();

    expect(platform.paused.length, pausesBefore + 1);
  });

  testWidgets('a Video labels its play button with the translations around it', (tester) async {
    installFakeVideoPlatform();

    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([
      createSurface([
        {'id': 'root', 'component': 'Video', 'url': _clip},
      ]),
    ]);

    await tester.pumpWidget(
      AITranslationsScope(translations: const _DutchTranslations(), child: surfaceApp(processor.surface('s')!)),
    );

    expect(find.bySemanticsLabel('Afspelen'), findsOneWidget);
  });

  testWidgets('a Video play button is big enough to tap', (tester) async {
    installFakeVideoPlatform();
    final handle = tester.ensureSemantics();

    await _pumpVideo(tester, video: {'url': _clip});

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a Video is 200 tall', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip});

    expect(tester.getSize(find.byType(A2UIMediaBox)).height, 200.0);
  });

  testWidgets('a Video is as wide as it is given', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip}, width: 300);

    expect(tester.getSize(find.byType(A2UIMediaBox)).width, 300.0);
  });

  testWidgets('a Video in a row that does not limit its width is 16 by 9', (tester) async {
    installFakeVideoPlatform();

    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'List',
          'direction': 'horizontal',
          'children': ['video'],
        },
        {'id': 'video', 'component': 'Video', 'url': _clip},
      ],
    );

    expect(tester.getSize(find.byType(A2UIMediaBox)), const Size(200 * 16 / 9, 200));
  });

  testWidgets('a Video hides its poster from assistive technologies', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster});

    expect(tester.widget<Image>(find.byType(Image)).excludeFromSemantics, isTrue);
  });

  testWidgets('a Video draws its play button in white over its poster', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster});

    expect(tester.widget<A2UIPlayButton>(find.byType(A2UIPlayButton)).color, const Color(0xFFFFFFFF));
  });

  testWidgets('a Video that is paused offers to play it again', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();

    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });

  testWidgets('a Video plays again when the person taps play after pausing it', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);
    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    expect(platform.played.length, 2);
  });

  testWidgets('a Video shows how far it has played', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    platform.position = FakeVideoPlayerPlatform.videoDuration ~/ 2;
    await tester.pump(const Duration(seconds: 1));

    expect(tester.widget<A2UIMediaProgress>(find.byType(A2UIMediaProgress)).played, 0.5);
  });

  testWidgets('a Video lets its player go when it is hidden', (tester) async {
    final platform = installFakeVideoPlatform();
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([
      createSurface([
        {'id': 'root', 'component': 'Video', 'url': _clip},
      ]),
    ]);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: shown,
        builder: (context, isShown, child) => TickerMode(enabled: isShown, child: child!),
        child: surfaceApp(processor.surface('s')!),
      ),
    );
    await _playAndLoad(tester, platform);

    shown.value = false;
    await tester.pump();
    await _settle(tester);

    expect(platform.disposed, [0]);
  });

  testWidgets('a Video makes one player when the person taps play twice at once', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    expect(platform.created, [_clip]);
  });

  testWidgets('a Video in a row beside text shrinks to fit the row', (tester) async {
    installFakeVideoPlatform();

    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'Row',
          'children': ['label', 'video'],
        },
        {'id': 'label', 'component': 'Text', 'text': 'Trailer'},
        {'id': 'video', 'component': 'Video', 'url': _clip},
      ],
    );

    expect(tester.getRect(find.byType(A2UIMediaBox)).right, lessThanOrEqualTo(400.0));
  });

  testWidgets('a Video that plays can be measured without being laid out', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    final box = tester.renderObject<RenderBox>(find.byType(A2UIMediaBox));

    expect(box.getDryLayout(const BoxConstraints(maxWidth: 300)), const Size(300, 200));
  });

  testWidgets('a Video shows its poster on black', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster});

    expect(tester.widget<A2UIMediaBox>(find.byType(A2UIMediaBox)).color, const Color(0xFF000000));
  });

  testWidgets('a Video draws a shadow under its play button over a poster', (tester) async {
    installFakeVideoPlatform();

    await _pumpVideo(tester, video: {'url': _clip, 'posterUrl': _poster});

    expect(tester.widget<A2UIPlayButton>(find.byType(A2UIPlayButton)).hasShadow, isTrue);
  });

  testWidgets('a Video shows its play button again when it cannot start playing', (tester) async {
    final platform = installFakeVideoPlatform()..failsToPlay = true;
    await _pumpVideo(tester, video: {'url': _clip});

    await _playAndLoad(tester, platform);

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(
      (players: find.byType(Chewie).evaluate().length, play: find.bySemanticsLabel('Play').evaluate().length),
      (
        players: 0,
        play: 1,
      ),
    );
  });

  testWidgets('a Video shows its play button again when it cannot play again after a pause', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);
    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.pump();
    platform.failsToPlay = true;

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();
    await tester.pump();

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(find.byType(Chewie), findsNothing);
  });

  testWidgets('a Video lets its player go when a screen is pushed over it', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    unawaited(_navigator(tester).push(MaterialPageRoute<void>(builder: (context) => const SizedBox.shrink())));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(platform.disposed, [0]);
  });

  testWidgets('a Video does not play on its own when the screen over it is popped', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);
    final navigator = _navigator(tester);
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (context) => const SizedBox.shrink())));
    await tester.pumpAndSettle();

    navigator.pop();
    await tester.pumpAndSettle();

    expect(
      (
        created: platform.created.length,
        played: platform.played.length,
        play: find.bySemanticsLabel('Play').evaluate().length,
      ),
      (created: 1, played: 1, play: 1),
    );
  });

  testWidgets('a Video plays on under a bottom sheet', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await _playAndLoad(tester, platform);

    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(find.byType(Chewie)),
        builder: (context) => const SizedBox(height: 100),
      ),
    );
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(
      (disposed: platform.disposed.length, players: find.byType(Chewie).evaluate().length),
      (disposed: 0, players: 1),
    );
  });

  testWidgets('a Video does not play a video that loads after its URL changed', (tester) async {
    final platform = installFakeVideoPlatform();
    final processor = await _pumpVideo(
      tester,
      video: {
        'url': {'@path': '/trailer'},
      },
      data: {'trailer': _clip},
    );
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    processor.apply([updateData('/trailer', 'https://example.com/other.mp4')]);
    await tester.pump();
    platform.initialize(0);
    await tester.pump();
    await tester.pump();
    await _settle(tester);

    expect(
      (
        played: platform.played.length,
        disposed: platform.disposed.length,
        players: find.byType(Chewie).evaluate().length,
        play: find.bySemanticsLabel('Play').evaluate().length,
      ),
      (played: 0, disposed: 1, players: 0, play: 1),
    );
  });

  testWidgets('a Video keeps playing when its surface rebuilds with the same URL', (tester) async {
    final platform = installFakeVideoPlatform();
    final processor = await _pumpVideo(
      tester,
      video: {
        'url': {'@path': '/trailer'},
      },
      data: {'trailer': _clip},
    );
    await _playAndLoad(tester, platform);

    processor.apply([updateData('/trailer', _clip)]);
    await tester.pump();
    await tester.pump();
    await _settle(tester);

    expect(
      (
        created: platform.created.length,
        played: platform.played.length,
        disposed: platform.disposed.length,
        players: find.byType(Chewie).evaluate().length,
      ),
      (created: 1, played: 1, disposed: 0, players: 1),
    );
  });

  testWidgets('a Video reports a video that fails to load', (tester) async {
    final platform = installFakeVideoPlatform();
    await _pumpVideo(tester, video: {'url': _clip});
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();

    platform.fail(0);
    await tester.pump();

    expect(tester.takeException(), isA<PlatformException>());
  });

  testWidgets('a Video reports a video that cannot start playing', (tester) async {
    final platform = installFakeVideoPlatform()..failsToPlay = true;
    await _pumpVideo(tester, video: {'url': _clip});

    await _playAndLoad(tester, platform);

    expect(tester.takeException(), isA<PlatformException>());
  });

  testWidgets('a Video does not report the failure of a player it let go of', (tester) async {
    final platform = installFakeVideoPlatform();
    final processor = await _pumpVideo(
      tester,
      video: {
        'url': {'@path': '/trailer'},
      },
      data: {'trailer': _clip},
    );
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();
    processor.apply([updateData('/trailer', 'https://example.com/other.mp4')]);
    await tester.pump();

    platform.fail(0);
    await tester.pump();
    await _settle(tester);

    expect(tester.takeException(), isNull);
  });
}

// The navigator the surface shows in.
NavigatorState _navigator(WidgetTester tester) => Navigator.of(tester.element(find.byType(A2UIMediaBox)));

// Shows a surface whose root is a Video with the properties [video].
Future<A2UIProcessor> _pumpVideo(
  WidgetTester tester, {
  required Map<String, Object?> video,
  Map<String, Object?> data = const {},
  A2UIMediaUrl mediaUrl = a2uiWebMediaUrl,
  double width = 400,
}) {
  return pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'Video', ...video},
    ],
    data: data,
    mediaUrl: mediaUrl,
    width: width,
  );
}

// Taps play and lets the video load.
Future<void> _playAndLoad(WidgetTester tester, FakeVideoPlayerPlatform platform) async {
  await tester.tap(find.bySemanticsLabel('Play'));
  await tester.pump();
  platform.initialize(0);
  await tester.pump();
  await tester.pump();
}

// Lets the video plugin finish what it was asked, such as letting a player
// go, which it does outside the test's clock.
Future<void> _settle(WidgetTester tester) => tester.runAsync(pumpEventQueue);

// The URL [url] has on a proxy host.
Uri _throughProxy(Uri url) => url.replace(host: 'proxy.example.com');

// The image the poster shows.
ImageProvider _posterImage(WidgetTester tester) => tester.widget<Image>(find.byType(Image)).image;

// The image a poster at [url] shows.
ImageProvider _imageAt(String url) => a2uiImageProvider(Uri.parse(url));

class _DutchTranslations extends DefaultAITranslations {
  const _DutchTranslations();

  @override
  String get playMedia => 'Afspelen';
}
