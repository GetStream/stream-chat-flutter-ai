import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_image.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_media.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';
import 'package:video_player/video_player.dart';

/// Builds a `Video`: its poster with a play button until the person plays it,
/// then the video.
///
/// The box is 200 logical pixels tall and as wide as it is given. Before the
/// video plays, it shows the image at `posterUrl`, the only thing that loads
/// until the person taps play; the video at `url` never plays on its own.
/// While it plays, a tap on it pauses it.
///
/// A video whose URL is missing, has no scheme, or is refused by the
/// surface's media function shows the box with a sign that it can't play, and
/// no play button. A video that fails to load or to play shows the box with
/// its play button again, so a tap tries again, and the failure is reported
/// with [FlutterError.reportError].
///
/// The player is let go, and where it had played to is lost, when the
/// component leaves the widget tree, when its URL changes, and when a screen
/// pushed over the conversation covers it once the push has finished. A
/// bottom sheet or a dialog over it, such as a `Modal`, lets it play on.
///
/// Internal to the package.
@internal
Widget buildA2UIVideo(BuildContext context, A2UIComponentScope scope) {
  final mediaUrl = A2UISurfaceScope.of(context).mediaUrl;
  return _A2UIVideo(
    source: a2uiMediaSourceOf(scope.string('url'), mediaUrl),
    poster: a2uiMediaSourceOf(scope.string('posterUrl'), mediaUrl),
  );
}

class _A2UIVideo extends StatefulWidget {
  const _A2UIVideo({required this.source, required this.poster});

  final Uri? source;
  final Uri? poster;

  @override
  State<_A2UIVideo> createState() => _A2UIVideoState();
}

class _A2UIVideoState extends State<_A2UIVideo> {
  // The height of the box, and its width where nothing limits it: 16 by 9.
  static const _height = 200.0;
  static const _fallbackWidth = _height * 16.0 / 9.0;

  // The color around a poster or a video that doesn't fill the box.
  static const _videoBackground = Color(0xFF000000);

  // The player of the video at the source, made when the person first taps
  // play, and `null` until then and once it is let go.
  VideoPlayerController? _video;
  ChewieController? _chewie;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A video under a screen pushed over it is let go. Only an opaque route
    // turns tickers off, so one under a bottom sheet or a dialog plays on.
    if (!TickerMode.valuesOf(context).enabled) _release();
  }

  @override
  void didUpdateWidget(_A2UIVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) _release();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  // Lets go of the player, if there is one, so the box shows its poster and
  // play button again.
  void _release() {
    final video = _video;
    final chewie = _chewie;
    _video = null;
    _chewie = null;
    video?.removeListener(_handleVideoChange);
    chewie?.dispose();
    if (video != null) unawaited(video.dispose());
  }

  Future<void> _handlePlay() async {
    final source = widget.source;
    // A second tap before the spinner shows makes no second player.
    if (source == null || _video != null) return;
    final video = VideoPlayerController.networkUrl(source);
    setState(() => _video = video);
    try {
      await video.initialize();
    } on Object catch (error, stack) {
      // A player let go of while it loads is already disposed, and its
      // failure is expected.
      _handleFailure(video, error, stack);
      return;
    }
    // The component left or its URL changed while the video loaded, and that
    // player was let go; one that still finishes loading is not shown.
    if (!identical(_video, video) || !mounted) return;
    video.addListener(_handleVideoChange);
    setState(() {
      _chewie = ChewieController(
        videoPlayerController: video,
        aspectRatio: video.value.aspectRatio,
        allowFullScreen: false,
        allowMuting: false,
        allowPlaybackSpeedChanging: false,
        showOptions: false,
        customControls: _A2UIVideoControls(onFailed: (error, stack) => _handleFailure(video, error, stack)),
      );
    });
    _play(video);
  }

  // Plays [video]; a video that can't is let go, as one that fails while it
  // plays.
  void _play(VideoPlayerController video) {
    unawaited(video.play().catchError((Object error, StackTrace stack) => _handleFailure(video, error, stack)));
  }

  // Reports [error] and lets go of [video] when it is still this component's
  // player, so the box shows its play button again. A player already let go
  // of fails as it is disposed, which is not reported.
  void _handleFailure(VideoPlayerController video, Object error, StackTrace? stack) {
    if (!identical(_video, video) || !mounted) return;
    reportA2UIMediaError(error, stack, 'while playing the video at ${widget.source}');
    setState(_release);
  }

  // A video that fails while it plays is let go, so the box shows its play
  // button again.
  void _handleVideoChange() {
    final video = _video;
    if (video == null || !video.value.hasError) return;
    _handleFailure(video, video.value.errorDescription ?? 'The video failed to play.', null);
  }

  @override
  Widget build(BuildContext context) {
    final chewie = _chewie;
    if (chewie != null) {
      return A2UIMediaBox(
        height: _height,
        fallbackWidth: _fallbackWidth,
        color: _videoBackground,
        children: [Chewie(controller: chewie)],
      );
    }
    return _buildCover(context);
  }

  Widget _buildCover(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    final poster = widget.poster;
    final isLoading = _video != null;
    return A2UIMediaBox(
      height: _height,
      fallbackWidth: _fallbackWidth,
      color: poster == null ? theme.subtleSurface : _videoBackground,
      children: [
        if (poster != null)
          Image(
            image: a2uiImageProvider(poster),
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        if (widget.source == null)
          const A2UIMediaUnavailable(icon: Icons.smart_display_outlined)
        else if (isLoading)
          const A2UISpinner()
        else
          Center(
            child: A2UIPlayButton(
              isPlaying: false,
              size: _buttonSize,
              color: poster == null ? theme.accent : _overPicture,
              hasShadow: poster != null,
              onPressed: _handlePlay,
            ),
          ),
      ],
    );
  }
}

// The controls over a video that plays: a play button while it is paused, a
// tap anywhere to pause it while it plays, and how far it has played.
class _A2UIVideoControls extends StatelessWidget {
  const _A2UIVideoControls({required this.onFailed});

  // Called with the error when the video can't play again after a pause.
  final void Function(Object error, StackTrace stack) onFailed;

  @override
  Widget build(BuildContext context) {
    final video = ChewieController.of(context).videoPlayerController;
    return ValueListenableBuilder(
      valueListenable: video,
      builder: (context, value, _) {
        final duration = value.duration.inMilliseconds;
        final loaded = value.buffered.isEmpty ? Duration.zero : value.buffered.last.end;
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: value.isPlaying
                  ? _PauseArea(onPressed: () => unawaited(video.pause().catchError(_ignore)))
                  : A2UIPlayButton(
                      isPlaying: false,
                      size: _buttonSize,
                      color: _overPicture,
                      hasShadow: true,
                      onPressed: () => unawaited(video.play().catchError(onFailed)),
                    ),
            ),
            A2UIMediaProgress(
              played: duration == 0 ? 0.0 : value.position.inMilliseconds / duration,
              loaded: duration == 0 ? 0.0 : loaded.inMilliseconds / duration,
            ),
          ],
        );
      },
    );
  }
}

// A pause that fails leaves the video playing, which the controls show.
void _ignore(Object error) {}

// The diameter of the play button.
const _buttonSize = 44.0;

// The color of the play button over a picture.
const _overPicture = Color(0xFFFFFFFF);

// The whole video, which pauses it when tapped.
class _PauseArea extends StatelessWidget {
  const _PauseArea({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Semantics(
        button: true,
        label: AITranslations.of(context).pauseMedia,
        onTap: onPressed,
        excludeSemantics: true,
        child: GestureDetector(onTap: onPressed, behavior: HitTestBehavior.opaque),
      ),
    );
  }
}
