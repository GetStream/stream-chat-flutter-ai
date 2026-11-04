import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_media.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

/// Builds an `AudioPlayer`: a button that plays and pauses the audio at
/// `url`, with its `description` as a caption.
///
/// The box is 80 logical pixels tall and as wide as it is given, and the
/// caption is one line in its bottom corner. Nothing loads until the person
/// taps play, and the audio never plays on its own; when it ends, it goes back
/// to the start.
///
/// Audio whose URL is missing, has no scheme, or is refused by the surface's
/// media function shows the box with a speaker, and no button. Audio that
/// fails to load shows the box with its play button again, so a tap tries
/// again.
///
/// The player is let go when the component leaves the widget tree, when a
/// screen pushed over the conversation covers it, and when its URL changes.
///
/// Internal to the package.
@internal
Widget buildA2UIAudioPlayer(BuildContext context, A2UIComponentScope scope) {
  final description = scope.string('description');
  return _A2UIAudioPlayer(
    source: a2uiMediaSourceOf(scope.string('url'), A2UISurfaceScope.of(context).mediaUrl),
    title: description == null || description.isEmpty ? null : description,
  );
}

class _A2UIAudioPlayer extends StatefulWidget {
  const _A2UIAudioPlayer({required this.source, required this.title});

  final Uri? source;
  final String? title;

  @override
  State<_A2UIAudioPlayer> createState() => _A2UIAudioPlayerState();
}

class _A2UIAudioPlayerState extends State<_A2UIAudioPlayer> {
  // The height of the box, and its width where nothing limits it, the width of
  // the largest image.
  static const _height = 80.0;
  static const _fallbackWidth = 240.0;

  // The play button's size.
  static const _buttonSize = 32.0;

  // The space between the caption and the box's edges.
  static const _captionInset = 6.0;

  // The player of the audio at the source, made when the person first taps
  // play, and `null` until then and once it is let go.
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;

  // Whether the player has loaded the audio.
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Audio under a screen pushed over it stops.
    if (!TickerMode.valuesOf(context).enabled) _release();
  }

  @override
  void didUpdateWidget(_A2UIAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != oldWidget.source) _release();
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  // Lets go of the player, if there is one, so the box shows its play button
  // again.
  void _release() {
    final player = _player;
    _player = null;
    _isLoaded = false;
    unawaited(_stateSubscription?.cancel());
    unawaited(_errorSubscription?.cancel());
    _stateSubscription = null;
    _errorSubscription = null;
    if (player != null) unawaited(player.dispose());
  }

  Future<void> _handlePlay() async {
    final source = widget.source;
    // A second tap before the spinner shows makes no second player.
    if (source == null || _player != null) return;
    final player = AudioPlayer();
    setState(() => _player = player);
    _stateSubscription = player.playerStateStream.listen(_handleState);
    _errorSubscription = player.errorStream.listen((error) => _handleError(player));
    try {
      await player.setUrl(source.toString());
    } on Object {
      _handleError(player);
      return;
    }
    // The component left or its URL changed while the audio loaded, and that
    // player was let go; one that still finishes loading doesn't play.
    if (!identical(_player, player) || !mounted) return;
    setState(() => _isLoaded = true);
    unawaited(player.play().catchError((Object error) => _handleError(player)));
  }

  // Audio that ends goes back to the start, ready to play again. The player
  // still counts as playing when the audio ends, so it is paused first, or it
  // would play again from the start.
  void _handleState(PlayerState state) {
    final player = _player;
    if (player == null) return;
    if (state.processingState == ProcessingState.completed && state.playing) {
      unawaited(player.pause().then((_) => player.seek(Duration.zero)).catchError(_ignore));
    }
    setState(() {
      // The player's state changed, which the button shows.
    });
  }

  // A player that fails is let go, so the box shows its play button again.
  void _handleError(AudioPlayer player) {
    if (!identical(_player, player) || !mounted) return;
    setState(_release);
  }

  void _handleToggle() {
    final player = _player;
    if (player == null) return;
    if (player.playing) {
      unawaited(player.pause().catchError(_ignore));
      return;
    }
    unawaited(player.play().catchError((Object error) => _handleError(player)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    final title = widget.title;
    return A2UIMediaBox(
      height: _height,
      fallbackWidth: _fallbackWidth,
      color: theme.subtleSurface,
      children: [
        if (title != null)
          PositionedDirectional(
            start: _captionInset,
            end: _captionInset,
            bottom: _captionInset,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                title,
                style: theme.caption.copyWith(color: theme.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        // Over the caption, so it stays in reach when large text runs into it.
        _buildControl(context),
        if (_player case final player? when _isLoaded) _Progress(player: player),
      ],
    );
  }

  Widget _buildControl(BuildContext context) {
    final theme = A2UISurfaceScope.of(context).theme;
    if (widget.source == null) return const A2UIMediaUnavailable(icon: Icons.volume_up_rounded);
    final player = _player;
    if (player != null && !_isLoaded) return const A2UISpinner();
    return Center(
      child: A2UIPlayButton(
        isPlaying: player != null && player.playing,
        size: _buttonSize,
        color: theme.accent,
        onPressed: player == null ? _handlePlay : _handleToggle,
      ),
    );
  }
}

// A pause, or the seek to the start, that fails leaves the player as it is,
// which the button shows.
void _ignore(Object error) {}

// How far [player] has played and loaded its audio.
class _Progress extends StatelessWidget {
  const _Progress({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final duration = player.duration?.inMilliseconds ?? 0;
        final position = snapshot.data ?? player.position;
        return A2UIMediaProgress(
          played: duration == 0 ? 0.0 : position.inMilliseconds / duration,
          loaded: duration == 0 ? 0.0 : player.bufferedPosition.inMilliseconds / duration,
        );
      },
    );
  }
}
