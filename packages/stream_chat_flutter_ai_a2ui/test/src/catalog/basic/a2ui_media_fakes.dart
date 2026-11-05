import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

// Stands in for the video plugin: records what the players are asked to do,
// and initializes a player only when the test says so.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  // The URLs of the players made, in order; a player's id is its index.
  final created = <String?>[];
  final played = <int>[];
  final paused = <int>[];

  // Where every video is, as the plugin reports it while the video plays.
  Duration position = Duration.zero;
  final disposed = <int>[];
  final _events = <int, StreamController<VideoEvent>>{};

  // The size and length every video reports when it initializes.
  static const videoSize = Size(1280, 720);
  static const videoDuration = Duration(seconds: 10);

  // Initializes the player [id], as if its video loaded.
  // A player already let go of hears nothing more.
  void initialize(int id) {
    if (_events[id]!.isClosed) return;
    _events[id]!.add(VideoEvent(eventType: VideoEventType.initialized, duration: videoDuration, size: videoSize));
  }

  // Fails the player [id], as if its video couldn't load.
  void fail(int id) {
    if (_events[id]!.isClosed) return;
    _events[id]!.addError(PlatformException(code: 'VideoError', message: 'The video could not be loaded.'));
  }

  // Tells the player [id] whether it plays, as the plugin does once it starts
  // or stops.
  void reportPlaying(int id, {required bool isPlaying}) {
    _events[id]!.add(VideoEvent(eventType: VideoEventType.isPlayingStateUpdate, isPlaying: isPlaying));
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    created.add(options.dataSource.uri);
    final id = created.length - 1;
    _events[id] = StreamController<VideoEvent>();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await _events[playerId]!.close();
  }

  // Whether asking a player to play fails, as when the plugin can't play it.
  bool failsToPlay = false;

  @override
  Future<void> play(int playerId) async {
    played.add(playerId);
    if (failsToPlay) throw PlatformException(code: 'VideoError', message: 'The video could not be played.');
  }

  @override
  Future<void> pause(int playerId) async => paused.add(playerId);

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setPreventsDisplaySleepDuringVideoPlayback(int playerId, bool preventsDisplaySleep) async {}

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.expand();
}

// Puts a [FakeVideoPlayerPlatform] in the video plugin's place until the test
// ends.
FakeVideoPlayerPlatform installFakeVideoPlatform() {
  final previous = VideoPlayerPlatform.instance;
  final fake = FakeVideoPlayerPlatform();
  VideoPlayerPlatform.instance = fake;
  addTearDown(() => VideoPlayerPlatform.instance = previous);
  return fake;
}

// Stands in for the audio plugin: records the players made and what they are
// asked to do, and loads a player's audio only when the test says so.
class FakeJustAudioPlatform extends JustAudioPlatform {
  final players = <FakeAudioPlayerPlatform>[];
  final disposed = <String>[];

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    final player = FakeAudioPlayerPlatform(request.id);
    players.add(player);
    return player;
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    disposed.add(request.id);
    for (final player in players) {
      if (player.id == request.id) player._interrupt();
    }
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async {
    return DisposeAllPlayersResponse();
  }
}

// One audio player of [FakeJustAudioPlatform].
class FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  FakeAudioPlayerPlatform(super.id);

  // The length the audio reports when it loads.
  static const audioDuration = Duration(seconds: 30);

  final loaded = <String>[];
  final seeks = <Duration?>[];
  int plays = 0;
  int pauses = 0;
  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final _load = Completer<LoadResponse>();

  // Loads the audio, as if it arrived.
  void finishLoading() {
    if (_load.isCompleted) return;
    _report(ProcessingStateMessage.ready);
    _load.complete(LoadResponse(duration: audioDuration));
  }

  // Interrupts a load that hasn't finished, as the plugin does when the
  // player is disposed.
  void _interrupt() {
    if (!_load.isCompleted) _load.completeError(PlatformException(code: 'abort', message: 'Loading interrupted'));
  }

  // Fails to load the audio, as if it couldn't be reached.
  void failLoading() {
    if (_load.isCompleted) return;
    _load.completeError(PlatformException(code: '404', message: 'The audio could not be loaded.'));
  }

  // Fails the audio while it plays, as if the connection dropped: the plugin
  // reports it in a playback event.
  void failPlaying() => _report(ProcessingStateMessage.idle, errorCode: 1, errorMessage: 'The connection was lost.');

  // Reports that the audio has played to [position], as the plugin does while
  // it plays.
  void reportPosition(Duration position) => _report(ProcessingStateMessage.ready, position: position);

  // Reports that the audio played to its end.
  void complete() => _report(ProcessingStateMessage.completed, position: audioDuration);

  void _report(
    ProcessingStateMessage state, {
    Duration position = Duration.zero,
    int? errorCode,
    String? errorMessage,
  }) {
    _events.add(
      PlaybackEventMessage(
        processingState: state,
        updateTime: DateTime.utc(2026),
        updatePosition: position,
        bufferedPosition: Duration.zero,
        duration: audioDuration,
        icyMetadata: null,
        currentIndex: 0,
        androidAudioSessionId: null,
        errorCode: errorCode,
        errorMessage: errorMessage,
      ),
    );
  }

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => const Stream.empty();

  @override
  Future<LoadResponse> load(LoadRequest request) {
    loaded.addAll(_urisOf(request.audioSourceMessage));
    return _load.future;
  }

  // The URLs of [source], which may be a playlist of them.
  static Iterable<String> _urisOf(AudioSourceMessage source) {
    return switch (source) {
      UriAudioSourceMessage(:final uri) => [uri],
      ConcatenatingAudioSourceMessage(:final children) => children.expand(_urisOf),
      _ => const [],
    };
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    plays += 1;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    pauses += 1;
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    seeks.add(request.position);
    // A seek out of the end makes the audio ready to play again, as the plugin
    // reports it.
    _report(ProcessingStateMessage.ready, position: request.position ?? Duration.zero);
    return SeekResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async => SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(SetSkipSilenceRequest request) async => SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(SetAndroidAudioAttributesRequest request) async {
    return SetAndroidAudioAttributesResponse();
  }

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse> setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async {
    return SetAutomaticallyWaitsToMinimizeStallingResponse();
  }

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
  setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async {
    return SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();
  }

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(SetPreferredPeakBitRateRequest request) async {
    return SetPreferredPeakBitRateResponse();
  }

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(SetAllowsExternalPlaybackRequest request) async {
    return SetAllowsExternalPlaybackResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    _interrupt();
    await _events.close();
    return DisposeResponse();
  }
}

// Puts a [FakeJustAudioPlatform] in the audio plugin's place, and answers the
// audio session plugin, until the test ends.
FakeJustAudioPlatform installFakeAudioPlatform(WidgetTester tester) {
  final previous = JustAudioPlatform.instance;
  final fake = FakeJustAudioPlatform();
  JustAudioPlatform.instance = fake;
  addTearDown(() => JustAudioPlatform.instance = previous);
  final messenger = tester.binding.defaultBinaryMessenger;
  const session = MethodChannel('com.ryanheise.audio_session');
  messenger.setMockMethodCallHandler(session, (call) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(session, null));
  return fake;
}
