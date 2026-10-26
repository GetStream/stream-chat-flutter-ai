import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/src/parts/resolved_tool_call_theme.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
// Not doc-only: the `theme` parameter is a [ToolCallThemeData].
import 'package:stream_chat_flutter_ai/src/theme/components/tool_call_theme.dart';
import 'package:stream_chat_flutter_ai/src/util/shimmer.dart';

/// {@template aiToolCallView}
/// One tool call an agent made: what it is doing, how it went, and how long it
/// took — the default view of an `ai_tool_call` step.
///
/// ```dart
/// AIToolCallView(call: part.toolCall!)
/// ```
///
/// The row reads, from the start:
///
///  * **A status icon,** following [AIToolCallPart.status]. A small spinner
///    while the call runs (and for a status this package doesn't know, which
///    counts as still in progress — debug builds say so); a shimmering hand
///    while it waits for approval, or a phone while it waits for a device; a
///    check once completed, an exclamation mark once failed, and a cross once
///    cancelled.
///  * **The title:** [AIToolCallPart.displayName] (the agent's title, or the
///    tool's name with underscores turned into spaces), or
///    [AITranslations.toolCallFallbackTitle] when the agent sent neither.
///  * **A detail line** under the title: the call's
///    [AIToolCallPart.summaryText] when it has one, otherwise what it waits for
///    or how it ended, such as "Waiting for approval" or "Didn't complete". A
///    running or completed call without a summary has no detail line.
///  * **The duration**, when known, at the end once the call has finished:
///    `0.4s` under a second, otherwise `12s` or `1m 5s`
///    ([AITranslations.toolCallDuration]).
///
/// A declined call ([AIToolCallPart.isDeclined]) says so in its detail line
/// and to screen readers whatever its status says, while its icon still
/// follows the status: the hand while the backend has yet to cancel the call,
/// then the cross.
///
/// It is a row of text, so give it a bounded width, as a chat list does.
///
/// Styling resolves per field: [theme], then the nearest [ToolCallTheme], then
/// [AITheme.toolCallTheme], then the defaults, most of them derived from the
/// ambient [ThemeData].
///
/// **Accessibility.** The row is a single node whose label reads the title,
/// the status, the summary and the duration, such as "Checking the weather,
/// Completed, Sunny, 21°C, 0.8s". Once the row has shown the call running or
/// waiting, it is a polite live region, so a screen reader announces the call
/// finishing or starting to wait without the reader having to go back to it.
/// The label only changes when the call's title, status, summary or duration
/// does — each of those is announced — so a call that just sits there stays
/// quiet. A row built for a call that has already finished, such as one
/// scrolled into view from history, is not a live region: screen readers
/// announce a live region as it appears, and there is no news in it. With reduced motion on
/// ([MediaQueryData.disableAnimations]) nothing shimmers and a running call
/// shows a static icon instead of a spinner.
/// {@endtemplate}
class AIToolCallView extends StatefulWidget {
  /// {@macro aiToolCallView}
  const AIToolCallView({super.key, required this.call, this.theme});

  /// The tool call to show.
  final AIToolCallPart call;

  /// Overrides for this view, layered over the ambient [ToolCallTheme]. Its
  /// text styles merge over the themed ones rather than replacing them.
  final ToolCallThemeData? theme;

  @override
  State<AIToolCallView> createState() => _AIToolCallViewState();
}

/// What the row shows, folding [AIToolCallPart.status] and the approval's
/// decision into one.
enum _ToolCallState {
  running,
  awaitingApproval,
  awaitingClient,
  completed,
  failed,
  cancelled,
  declined;

  /// What the detail line and screen readers say. Declined comes first: the
  /// call never ran, whatever its status says yet.
  static _ToolCallState of(AIToolCallPart call) => call.isDeclined ? declined : ofStatus(call);

  /// What the icon shows: the status alone, declined or not.
  static _ToolCallState ofStatus(AIToolCallPart call) {
    return switch (call.status) {
      AIToolCallStatus.awaitingApproval => awaitingApproval,
      AIToolCallStatus.awaitingClient => awaitingClient,
      AIToolCallStatus.completed => completed,
      AIToolCallStatus.failed => failed,
      AIToolCallStatus.cancelled => cancelled,
      // `running`, and any status this package doesn't know.
      _ => running,
    };
  }

  bool get isAwaiting => this == awaitingApproval || this == awaitingClient;

  /// Whether the call may still change: running or waiting.
  bool get isLive => this == running || isAwaiting;

  /// The status in words, for the detail line (when the call has no summary)
  /// and for screen readers. `null` where the row shows no detail by default.
  String? detail(AITranslations translations) => switch (this) {
    running || completed => null,
    awaitingApproval => translations.toolCallAwaitingApproval,
    awaitingClient => translations.toolCallAwaitingClient,
    failed => translations.toolCallFailed,
    cancelled => translations.toolCallCancelled,
    declined => translations.toolCallDeclined,
  };

  /// The status in words for screen readers, which always hear one.
  String label(AITranslations translations) => switch (this) {
    running => translations.toolCallRunning,
    completed => translations.toolCallCompleted,
    awaitingApproval => translations.toolCallAwaitingApproval,
    awaitingClient => translations.toolCallAwaitingClient,
    failed => translations.toolCallFailed,
    cancelled => translations.toolCallCancelled,
    declined => translations.toolCallDeclined,
  };
}

class _AIToolCallViewState extends State<AIToolCallView> with SingleTickerProviderStateMixin {
  /// Drives the shimmer while the call waits. Created on first use, so a
  /// finished call never allocates a ticker.
  AnimationController? _shimmer;

  bool _reduceMotion = false;

  /// Whether this row has shown the call running or waiting, making it a live
  /// region from then on. A screen reader announces a live region as it
  /// appears, so a call that was already finished when its row was built never
  /// becomes one.
  bool _announces = false;

  @override
  void initState() {
    super.initState();
    _announces = _ToolCallState.of(widget.call).isLive;
    _reportUnknownStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncShimmer();
  }

  @override
  void didUpdateWidget(AIToolCallView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.call.status != widget.call.status) _reportUnknownStatus();
    _announces = _announces || _ToolCallState.of(widget.call).isLive;
    _syncShimmer();
  }

  @override
  void dispose() {
    _shimmer?.dispose();
    super.dispose();
  }

  /// In debug builds, says so whenever the row starts showing a status this
  /// package doesn't know as still running — likely a newer backend.
  void _reportUnknownStatus() {
    final status = widget.call.status;
    if (status.isKnown) return;
    reportPartIssue(
      () =>
          'ai_tool_call "${widget.call.id}" has a status this package does not know, "${status.value}"; '
          'it is shown as still running.',
    );
  }

  /// Runs the shimmer only while the call's icon waits and motion is on.
  void _syncShimmer() {
    if (_ToolCallState.ofStatus(widget.call).isAwaiting && !_reduceMotion) {
      final shimmer = _shimmer ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
      if (!shimmer.isAnimating) shimmer.repeat();
    } else {
      _shimmer?.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedToolCallTheme.resolve(context, override: widget.theme);
    final translations = AITranslations.of(context);
    final call = widget.call;
    final state = _ToolCallState.of(call);

    final title = call.displayName.isEmpty ? translations.toolCallFallbackTitle : call.displayName;
    final summary = call.summaryText;
    final detail = summary ?? state.detail(translations);
    final duration = call.status.isFinished ? call.duration : null;
    final durationText = duration == null ? null : translations.toolCallDuration(duration);

    const gap = 8.0;
    return Semantics(
      container: true,
      liveRegion: _announces,
      label: [title, state.label(translations), ?summary, ?durationText].join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: theme.iconSize,
                child: Center(
                  child: _StatusIcon(
                    state: _ToolCallState.ofStatus(call),
                    theme: theme,
                    reduceMotion: _reduceMotion,
                    shimmer: _shimmer,
                  ),
                ),
              ),
              const SizedBox(width: gap),
              Expanded(child: Text(title, style: theme.titleStyle)),
              if (durationText != null) ...[
                const SizedBox(width: gap),
                Text(
                  durationText,
                  style: theme.detailStyle.copyWith(
                    fontFeatures: [...?theme.detailStyle.fontFeatures, const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          if (detail != null)
            Padding(
              padding: EdgeInsetsDirectional.only(start: theme.iconSize + gap, top: 2),
              child: Text(detail, style: theme.detailStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

/// The icon at the start of the row.
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.state, required this.theme, required this.reduceMotion, required this.shimmer});

  final _ToolCallState state;
  final ResolvedToolCallTheme theme;
  final bool reduceMotion;

  /// Running while the call waits with motion on; `null` or stopped otherwise.
  final Animation<double>? shimmer;

  @override
  Widget build(BuildContext context) {
    final size = theme.iconSize;
    Widget icon(IconData data, Color color) => Icon(data, size: size, color: color);
    Widget waiting(IconData data) {
      // Drawn in the accent; moving, a band of the title's color sweeps over
      // it.
      if (reduceMotion || shimmer == null) return icon(data, theme.accentColor);
      return Shimmer(
        animation: shimmer!,
        base: theme.accentColor,
        highlight: theme.titleStyle.color ?? theme.titleStyle.foreground?.color ?? theme.accentColor,
        child: icon(data, theme.accentColor),
      );
    }

    return switch (state) {
      // A spinner never stops, so reduced motion gets a still "in progress".
      _ToolCallState.running when reduceMotion => icon(Icons.more_horiz_rounded, theme.accentColor),
      _ToolCallState.running => SizedBox.square(
        // Inset a little: a ring fills its box, where a glyph leaves a margin.
        dimension: size * 0.85,
        child: CircularProgressIndicator(strokeWidth: math.max(1.5, size / 8), color: theme.accentColor),
      ),
      _ToolCallState.awaitingApproval => waiting(Icons.back_hand_outlined),
      _ToolCallState.awaitingClient => waiting(Icons.smartphone_outlined),
      _ToolCallState.completed => icon(Icons.check_rounded, theme.successColor),
      _ToolCallState.failed => icon(Icons.priority_high_rounded, theme.failureColor),
      // `declined` never gets here, as the icon follows the status alone.
      _ToolCallState.cancelled || _ToolCallState.declined => icon(Icons.close_rounded, theme.iconColor),
    };
  }
}
