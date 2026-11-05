import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_media.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_adapter.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

import '../../a2ui_test_app.dart';
import 'a2ui_media_fakes.dart';

const _song = 'https://example.com/song.mp3';

void main() {
  testWidgets('an AudioPlayer shows its description as a caption', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song, 'description': 'Episode 12'});

    expect(tester.widget<Text>(find.text('Episode 12')).style, lightTheme().caption.copyWith(color: lightTheme().text));
  });

  testWidgets('an AudioPlayer keeps its caption to one line', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song, 'description': 'Episode 12'});

    expect(tester.widget<Text>(find.text('Episode 12')).maxLines, 1);
  });

  testWidgets('an AudioPlayer without a description shows no caption', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song});

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('an AudioPlayer loads nothing until the person plays it', (tester) async {
    final platform = installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song});
    await tester.pumpAndSettle();

    expect(platform.players, isEmpty);
  });

  testWidgets('an AudioPlayer loads its audio once the person taps play', (tester) async {
    final platform = installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song});
    await _tapPlay(tester);

    expect(platform.players.single.loaded, [_song]);
  });

  testWidgets('an AudioPlayer plays once its audio loads after the tap', (tester) async {
    final platform = installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    expect(platform.players.single.plays, 1);
  });

  testWidgets('an AudioPlayer does not play again on its own after the person pauses it', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    await tester.tap(find.bySemanticsLabel('Pause'));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 5));

    expect(platform.players.single.plays, 1);
  });

  testWidgets('an AudioPlayer shows a spinner while its audio loads', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song});
    await _tapPlay(tester);

    expect(find.byType(A2UISpinner), findsOneWidget);
  });

  testWidgets('an AudioPlayer loads its audio from the URL the media function gives', (tester) async {
    final platform = installFakeAudioPlatform(tester);

    await _pumpAudio(
      tester,
      audio: {'url': _song},
      mediaUrl: (url) => url.replace(host: 'proxy.example.com'),
    );
    await _tapPlay(tester);

    expect(platform.players.single.loaded, ['https://proxy.example.com/song.mp3']);
  });

  testWidgets('an AudioPlayer whose URL the media function refuses has no play button', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': 'file:///song.mp3'});

    expect(find.byType(A2UIPlayButton), findsNothing);
  });

  testWidgets('an AudioPlayer whose URL the media function refuses shows a speaker', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': 'file:///song.mp3'});

    expect(tester.widget<A2UIMediaUnavailable>(find.byType(A2UIMediaUnavailable)).icon, Icons.volume_up_rounded);
  });

  testWidgets('an AudioPlayer whose URL has no scheme shows a speaker', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': 'song.mp3'});

    expect(find.byType(A2UIMediaUnavailable), findsOneWidget);
  });

  testWidgets('an AudioPlayer whose URL has no scheme does not call the media function', (tester) async {
    installFakeAudioPlatform(tester);
    final asked = <Uri>[];

    await _pumpAudio(
      tester,
      audio: {'url': 'song.mp3'},
      mediaUrl: (url) {
        asked.add(url);
        return url;
      },
    );

    expect(asked, isEmpty);
  });

  testWidgets('an AudioPlayer lets its player go when it leaves the widget tree', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);

    expect(platform.disposed, [platform.players.single.id]);
  });

  testWidgets('an AudioPlayer lets its player go when its URL changes', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    final processor = await _pumpAudio(
      tester,
      audio: {
        'url': {'@path': '/song'},
      },
      data: {'song': _song},
    );
    await _playAndLoad(tester, platform);

    processor.apply([updateData('/song', 'https://example.com/other.mp3')]);
    await tester.pump();
    await _settle(tester);

    expect(platform.disposed, [platform.players.single.id]);
  });

  testWidgets('an AudioPlayer lets go of a player that is still loading when it leaves the widget tree', (
    tester,
  ) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _tapPlay(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);

    expect(platform.disposed, [platform.players.single.id]);
  });

  testWidgets('an AudioPlayer does not play audio that loads after it left the widget tree', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _tapPlay(tester);
    final player = platform.players.single;
    await tester.pumpWidget(const SizedBox.shrink());

    player.finishLoading();
    await _settle(tester);

    expect(player.plays, 0);
  });

  testWidgets('an AudioPlayer shows its play button again when its audio fails to load', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _tapPlay(tester);

    platform.players.single.failLoading();
    await _settle(tester);
    await tester.pump();

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });

  testWidgets('an AudioPlayer reports audio that fails to load', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _tapPlay(tester);

    platform.players.single.failLoading();
    await _settle(tester);
    await tester.pump();

    expect(tester.takeException(), isA<PlayerException>());
  });

  testWidgets('an AudioPlayer loads its audio again when the person taps play after a failure', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _tapPlay(tester);
    platform.players.single.failLoading();
    await _settle(tester);
    await tester.pump();

    await _tapPlay(tester);

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(platform.players.length, 2);
  });

  testWidgets('an AudioPlayer shows its play button again when its audio fails while it plays', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    platform.players.single.failPlaying();
    await _settle(tester);
    await tester.pump();

    // The failure is reported, which a test of its own covers.
    tester.takeException();

    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });

  testWidgets('an AudioPlayer goes back to the start when its audio ends', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    platform.players.single.complete();
    await _settle(tester);

    expect(platform.players.single.seeks.last, Duration.zero);
  });

  testWidgets('an AudioPlayer offers to play again once its audio ends', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    platform.players.single.complete();
    await _settle(tester);
    await tester.pump();

    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });

  testWidgets('an AudioPlayer that plays offers to pause it', (tester) async {
    final platform = installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    expect(find.bySemanticsLabel('Pause'), findsOneWidget);
  });

  testWidgets('an AudioPlayer pauses when the person taps pause', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);
    final pausesBefore = platform.players.single.pauses;

    await tester.tap(find.bySemanticsLabel('Pause'));
    await _settle(tester);

    expect(platform.players.single.pauses, pausesBefore + 1);
  });

  testWidgets('an AudioPlayer labels its button "Play" before it plays', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song});

    expect(find.bySemanticsLabel('Play'), findsOneWidget);
  });

  testWidgets('an AudioPlayer button is big enough to tap', (tester) async {
    installFakeAudioPlatform(tester);
    final handle = tester.ensureSemantics();

    await _pumpAudio(tester, audio: {'url': _song});

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('an AudioPlayer is 80 tall', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song});

    expect(tester.getSize(find.byType(A2UIMediaBox)).height, 80.0);
  });

  testWidgets('an AudioPlayer is as wide as it is given', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song}, width: 300);

    expect(tester.getSize(find.byType(A2UIMediaBox)).width, 300.0);
  });

  testWidgets('an AudioPlayer in a row that does not limit its width is 240 wide', (tester) async {
    installFakeAudioPlatform(tester);

    await pumpSurface(
      tester,
      components: [
        {
          'id': 'root',
          'component': 'List',
          'direction': 'horizontal',
          'children': ['audio'],
        },
        {'id': 'audio', 'component': 'AudioPlayer', 'url': _song},
      ],
    );

    expect(tester.getSize(find.byType(A2UIMediaBox)).width, 240.0);
  });

  testWidgets('an AudioPlayer puts its caption in the bottom right corner in right-to-left text', (tester) async {
    installFakeAudioPlatform(tester);

    await _pumpAudio(tester, audio: {'url': _song, 'description': 'Episode 12'}, direction: TextDirection.rtl);

    final box = tester.getRect(find.byType(A2UIMediaBox));
    final caption = tester.getRect(find.text('Episode 12'));
    expect((right: box.right - caption.right, bottom: box.bottom - caption.bottom), (right: 6.0, bottom: 6.0));
  });

  testWidgets('an AudioPlayer pauses when its audio ends', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);
    final player = platform.players.single;
    final pausesBefore = player.pauses;

    player.complete();
    await _until(tester, () => player.seeks.isNotEmpty);

    expect(player.pauses, pausesBefore + 1);
  });

  testWidgets('an AudioPlayer shows how far it has played', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);
    // Paused, the player shows the position it was given, not one it moves on
    // from with time.
    await tester.tap(find.bySemanticsLabel('Pause'));
    await _settle(tester);

    platform.players.single.reportPosition(FakeAudioPlayerPlatform.audioDuration ~/ 2);
    await _until(tester, () => (_played(tester) - 0.5).abs() < 0.01);

    expect(_played(tester), closeTo(0.5, 0.01));
  });

  testWidgets('an AudioPlayer lets its player go when it is hidden', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    final processor = A2UIProcessor(catalogs: A2UICatalogs());
    addTearDown(processor.dispose);
    processor.apply([
      createSurface([
        {'id': 'root', 'component': 'AudioPlayer', 'url': _song},
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

    expect(platform.disposed, [platform.players.single.id]);
  });

  testWidgets('an AudioPlayer makes one player when the person taps play twice at once', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});

    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.tap(find.bySemanticsLabel('Play'));
    await _until(tester, () => platform.players.isNotEmpty && platform.players.last.loaded.isNotEmpty);

    expect(platform.players.length, 1);
  });

  testWidgets('an AudioPlayer lets its player go when a screen is pushed over it', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    unawaited(_navigator(tester).push(MaterialPageRoute<void>(builder: (context) => const SizedBox.shrink())));
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(platform.disposed, [platform.players.single.id]);
  });

  testWidgets('an AudioPlayer does not play on its own when the screen over it is popped', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);
    final navigator = _navigator(tester);
    unawaited(navigator.push(MaterialPageRoute<void>(builder: (context) => const SizedBox.shrink())));
    await tester.pumpAndSettle();
    await _settle(tester);

    navigator.pop();
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(
      (
        players: platform.players.length,
        plays: platform.players.single.plays,
        play: find.bySemanticsLabel('Play').evaluate().length,
      ),
      (players: 1, plays: 1, play: 1),
    );
  });

  testWidgets('an AudioPlayer plays on under a bottom sheet', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    await _pumpAudio(tester, audio: {'url': _song});
    await _playAndLoad(tester, platform);

    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(find.byType(A2UIMediaBox)),
        builder: (context) => const SizedBox(height: 100),
      ),
    );
    await tester.pumpAndSettle();
    await _settle(tester);

    expect(platform.disposed, isEmpty);
  });

  testWidgets('an AudioPlayer does not play audio that loads after its URL changed', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    final processor = await _pumpAudio(
      tester,
      audio: {
        'url': {'@path': '/song'},
      },
      data: {'song': _song},
    );
    await _tapPlay(tester);
    final player = platform.players.single;

    processor.apply([updateData('/song', 'https://example.com/other.mp3')]);
    await tester.pump();
    player.finishLoading();
    await _settle(tester);

    expect(
      (plays: player.plays, disposed: platform.disposed.length, play: find.bySemanticsLabel('Play').evaluate().length),
      (plays: 0, disposed: 1, play: 1),
    );
  });

  testWidgets('an AudioPlayer does not report a load it interrupted by letting its player go', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    final processor = await _pumpAudio(
      tester,
      audio: {
        'url': {'@path': '/song'},
      },
      data: {'song': _song},
    );
    await _tapPlay(tester);

    processor.apply([updateData('/song', 'https://example.com/other.mp3')]);
    await tester.pump();
    await _until(tester, () => platform.disposed.isNotEmpty);
    await _settle(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an AudioPlayer keeps playing when its surface rebuilds with the same URL', (tester) async {
    final platform = installFakeAudioPlatform(tester);
    final processor = await _pumpAudio(
      tester,
      audio: {
        'url': {'@path': '/song'},
      },
      data: {'song': _song},
    );
    await _playAndLoad(tester, platform);

    processor.apply([updateData('/song', _song)]);
    await tester.pump();
    await _settle(tester);

    expect(
      (players: platform.players.length, plays: platform.players.single.plays, disposed: platform.disposed.length),
      (players: 1, plays: 1, disposed: 0),
    );
  });
}

// The navigator the surface shows in.
NavigatorState _navigator(WidgetTester tester) => Navigator.of(tester.element(find.byType(A2UIMediaBox)));

// Shows a surface whose root is an AudioPlayer with the properties [audio].
Future<A2UIProcessor> _pumpAudio(
  WidgetTester tester, {
  required Map<String, Object?> audio,
  Map<String, Object?> data = const {},
  A2UIMediaUrl mediaUrl = a2uiWebMediaUrl,
  TextDirection direction = TextDirection.ltr,
  double width = 400,
}) {
  return pumpSurface(
    tester,
    components: [
      {'id': 'root', 'component': 'AudioPlayer', ...audio},
    ],
    data: data,
    mediaUrl: mediaUrl,
    direction: direction,
    width: width,
  );
}

// Taps play and waits until the player asks for the audio.
Future<void> _tapPlay(WidgetTester tester) async {
  final platform = JustAudioPlatform.instance as FakeJustAudioPlatform;
  final players = platform.players.length;
  await tester.tap(find.bySemanticsLabel('Play'));
  await _until(tester, () => platform.players.length > players && platform.players.last.loaded.isNotEmpty);
}

// Taps play and lets the audio load, then waits until it plays.
Future<void> _playAndLoad(WidgetTester tester, FakeJustAudioPlatform platform) async {
  await _tapPlay(tester);
  platform.players.last.finishLoading();
  await _until(tester, () => platform.players.last.plays > 0);
}

// The share of the audio the progress line shows as played.
double _played(WidgetTester tester) => tester.widget<A2UIMediaProgress>(find.byType(A2UIMediaProgress)).played;

// Lets the audio plugin finish what it was asked: part of it runs on the
// test's clock and part outside it, so both are run in turn.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(pumpEventQueue);
  await tester.pump();
}

// Settles until [condition] holds, and fails if it never does.
Future<void> _until(WidgetTester tester, bool Function() condition) async {
  for (var turn = 0; turn < _maxTurns && !condition(); turn += 1) {
    await _settle(tester);
  }
  expect(condition(), isTrue, reason: 'The audio player did not get there.');
}

// More turns than the plugin ever takes to answer.
const _maxTurns = 50;
