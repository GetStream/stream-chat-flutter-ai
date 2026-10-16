import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart' show MarkdownTapLinkCallback;
import 'package:stream_chat_flutter_ai/src/localization/ai_translations.dart';
import 'package:stream_chat_flutter_ai/src/parts/ai_reasoning_part.dart';
import 'package:stream_chat_flutter_ai/src/reasoning/reasoning_text.dart';
import 'package:stream_chat_flutter_ai/src/reasoning/resolved_reasoning_theme.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/theme/ai_theme.dart';
import 'package:stream_chat_flutter_ai/src/theme/components/reasoning_theme.dart';

/// {@template streamingReasoningView}
/// A model's reasoning (its "thinking"), shown alongside its reply.
///
/// While the model thinks, the reasoning is open under a "Thinking… 7s"
/// header: a panel that grows with the thoughts up to [maxExpandedHeight],
/// then scrolls and keeps the newest in view, revealing new text smoothly as it
/// arrives. When the model is done the view folds into "Thought for 12s" and
/// its [summary], and tapping the header opens the whole reasoning again. Once
/// the reader taps the header, their choice wins over the automatic opening
/// and folding.
///
/// ```dart
/// StreamingReasoningView(text: reasoning, isThinking: answer.isEmpty, duration: elapsed)
/// ```
///
/// For an `ai_reasoning` step, [StreamingReasoningView.part] reads the status,
/// duration and summary from the [AIReasoningPart].
///
/// Reasoning can run to tens of kilobytes and grow many times a second, so the
/// view only lays out what changes: the text is split into paragraphs at blank
/// lines, the paragraphs are built lazily, and only the paragraph still being
/// written is built again. Each paragraph renders inline markdown — bold,
/// italics, inline code and links.
///
/// Folding shrinks the panel in place over [foldDuration] along [foldCurve],
/// so whatever sits below glides up rather than jumping. A reply that only
/// starts showing its answer once the reasoning has folded can wait that long.
///
/// Styling resolves per field: [theme], then the nearest [ReasoningTheme],
/// then [AITheme.reasoningTheme], then defaults derived from the ambient
/// [ThemeData].
///
/// **Accessibility.** The header is a single button labelled with its title
/// (and the summary, while folded), with a hint saying what tapping it does.
/// Folded reasoning is hidden from assistive technology. With reduced motion
/// on ([MediaQueryData.disableAnimations]) nothing shimmers or pulses, the
/// panel opens and folds at once, and new text appears at once.
/// {@endtemplate}
class StreamingReasoningView extends StatefulWidget {
  /// {@macro streamingReasoningView}
  const StreamingReasoningView({
    super.key,
    required this.text,
    required this.isThinking,
    this.duration,
    this.summary,
    this.footnote,
    this.initiallyExpanded = false,
    this.showsLiveReasoning = true,
    this.maxExpandedHeight,
    this.theme,
    this.onExpandedChanged,
    this.onTapLink,
  }) : assert(maxExpandedHeight == null || maxExpandedHeight >= 0, 'maxExpandedHeight must not be negative');

  /// Shows a reasoning step: its full [text] when the app has it, otherwise
  /// the step's [AIReasoningPart.preview] (or, failing that, its summary).
  ///
  /// [AIReasoningPart.isStreaming], [AIReasoningPart.duration] and
  /// [AIReasoningPart.summary] fill [isThinking], [duration] and [summary].
  StreamingReasoningView.part(
    AIReasoningPart part, {
    Key? key,
    String? text,
    String? footnote,
    bool initiallyExpanded = false,
    bool showsLiveReasoning = true,
    double? maxExpandedHeight,
    ReasoningThemeData? theme,
    ValueChanged<bool>? onExpandedChanged,
    MarkdownTapLinkCallback? onTapLink,
  }) : this(
         key: key,
         text: text ?? part.preview ?? part.summary ?? '',
         isThinking: part.isStreaming,
         duration: part.duration,
         summary: part.summary,
         footnote: footnote,
         initiallyExpanded: initiallyExpanded,
         showsLiveReasoning: showsLiveReasoning,
         maxExpandedHeight: maxExpandedHeight,
         theme: theme,
         onExpandedChanged: onExpandedChanged,
         onTapLink: onTapLink,
       );

  /// How long the reasoning takes to fold or open.
  ///
  /// A reply that types its answer only after this lets the reasoning fold
  /// first, rather than the two moving against each other.
  static const foldDuration = Duration(milliseconds: 450);

  /// The curve the reasoning folds and opens along. Use it, with
  /// [foldDuration], for changes of your own that should move with it.
  static const Curve foldCurve = Curves.easeInOutCubic;

  /// The reasoning so far. Blank lines separate paragraphs, and inline
  /// markdown (bold, italics, code and links) is rendered.
  final String text;

  /// Whether the model is still thinking. While it is, the header counts the
  /// seconds and new text is revealed as it streams in.
  final bool isThinking;

  /// How long the model has thought.
  ///
  /// While [isThinking], the header counts on from it, a second at a time;
  /// leave it `null` to count from when this view first saw the model
  /// thinking. Once done, the header reads "Thought for" this — or, when
  /// `null`, how long this view saw the model think.
  final Duration? duration;

  /// A one-line summary, shown beside the header while the finished reasoning
  /// is folded.
  final String? summary;

  /// A note under the open reasoning, such as how long it is kept. Shown only
  /// once the model is done, and only when the reader opened the reasoning
  /// (or [initiallyExpanded] is set) — appearing as the reasoning folds by
  /// itself would push the reply down just as it starts.
  final String? footnote;

  /// Whether the reasoning is open once the model is done. Defaults to `false`,
  /// folding it.
  final bool initiallyExpanded;

  /// Whether the reasoning is open while the model thinks. Defaults to `true`.
  final bool showsLiveReasoning;

  /// How tall the open reasoning grows before it scrolls.
  ///
  /// See [ReasoningThemeData.maxExpandedHeight]; defaults to 260.
  final double? maxExpandedHeight;

  /// Overrides for this view, layered over the ambient [ReasoningTheme]. Its
  /// text styles merge over the themed ones rather than replacing them.
  final ReasoningThemeData? theme;

  /// Called when the reasoning opens or folds, whether the reader tapped the
  /// header or the view did it by itself. Changes made during a build are
  /// reported after the frame, so it is safe to call `setState` from here.
  final ValueChanged<bool>? onExpandedChanged;

  /// Called when the reader taps a link in the reasoning. Links are drawn but
  /// not tappable without it.
  final MarkdownTapLinkCallback? onTapLink;

  @override
  State<StreamingReasoningView> createState() => _StreamingReasoningViewState();
}

class _StreamingReasoningViewState extends State<StreamingReasoningView> with TickerProviderStateMixin {
  /// What the reader chose by tapping the header. Until they do, the reasoning
  /// is open while the model thinks and folded once it is done.
  bool? _choice;

  /// Whether the reasoning is open, or opening.
  late bool _open;

  /// 0 folded, 1 open. The panel stays mounted, at no height, until it reaches
  /// 0.
  late final AnimationController _fold;
  late final CurvedAnimation _foldCurve;

  /// Drives the shimmer and the icon's pulse while the model thinks. Created on
  /// first use, so a finished step never allocates a ticker.
  AnimationController? _activity;

  /// Ticks [_elapsed] once a second while the model thinks.
  Timer? _clock;

  /// How long the model has thought, as the header shows it while it thinks.
  late Duration _elapsed;

  /// How long this view saw the model think, for a finished step whose
  /// [StreamingReasoningView.duration] does not say.
  Duration? _thoughtFor;

  bool _reduceMotion = false;
  bool _didInitDependencies = false;

  /// An expansion change waiting for the frame to end before it is reported.
  bool? _pendingExpanded;

  bool get _opensByDefault => widget.isThinking ? widget.showsLiveReasoning : widget.initiallyExpanded;

  @override
  void initState() {
    super.initState();
    _open = _opensByDefault;
    _elapsed = widget.duration ?? Duration.zero;
    // Live reasoning joins the layout at no height and unfolds once it
    // appears, rather than pushing everything below it aside in one frame.
    _fold = AnimationController(
      vsync: this,
      duration: StreamingReasoningView.foldDuration,
      value: _open && !widget.isThinking ? 1 : 0,
    )..addStatusListener(_onFoldStatus);
    _foldCurve = CurvedAnimation(parent: _fold, curve: StreamingReasoningView.foldCurve);
    if (widget.isThinking) _startClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final changed = reduceMotion != _reduceMotion;
    _reduceMotion = reduceMotion;

    if (!_didInitDependencies) {
      _didInitDependencies = true;
      if (_open && _fold.value == 0) _animateFold(open: true);
    } else if (changed && _reduceMotion) {
      // Reduced motion switched on mid-fold: jump to where it was going.
      _fold.value = _open ? 1 : 0;
    }
    _syncActivity();
  }

  @override
  void didUpdateWidget(StreamingReasoningView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isThinking != widget.isThinking) {
      if (widget.isThinking) {
        _elapsed = widget.duration ?? Duration.zero;
        _startClock();
      } else {
        _stopClock();
        final reported = widget.duration ?? Duration.zero;
        _thoughtFor = reported > _elapsed ? reported : _elapsed;
      }
    } else if (widget.isThinking && widget.duration != oldWidget.duration && widget.duration != null) {
      // The host moved the count on; carry on from there, a full second later.
      _elapsed = widget.duration!;
      _startClock();
    }

    if (oldWidget.isThinking != widget.isThinking ||
        oldWidget.showsLiveReasoning != widget.showsLiveReasoning ||
        oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _setOpen(_choice ?? _opensByDefault);
    }
    _syncActivity();
  }

  @override
  void dispose() {
    _stopClock();
    _foldCurve.dispose();
    _fold.dispose();
    _activity?.dispose();
    super.dispose();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  /// Runs the shimmer and pulse only while the model thinks and motion is on.
  void _syncActivity() {
    if (widget.isThinking && !_reduceMotion) {
      final activity = _activity ??= AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
      if (!activity.isAnimating) activity.repeat();
    } else {
      _activity?.stop();
    }
  }

  void _onFoldStatus(AnimationStatus status) {
    // Folded all the way: drop the panel from the tree.
    if (status == AnimationStatus.dismissed && !_open && mounted) setState(() {});
  }

  void _animateFold({required bool open}) {
    if (_reduceMotion) {
      _fold.value = open ? 1 : 0;
    } else if (open) {
      unawaited(_fold.forward());
    } else {
      unawaited(_fold.reverse());
    }
  }

  void _setOpen(bool open) {
    if (open == _open) return;
    setState(() => _open = open);
    _animateFold(open: open);
    _reportExpanded(open);
  }

  void _toggle() {
    _choice = !_open;
    _setOpen(!_open);
  }

  /// Reports [expanded] now, or after the frame when called from inside one —
  /// [didUpdateWidget] runs mid-build, where a host's `setState` would throw.
  void _reportExpanded(bool expanded) {
    final inFrame = switch (SchedulerBinding.instance.schedulerPhase) {
      SchedulerPhase.persistentCallbacks || SchedulerPhase.midFrameMicrotasks => true,
      _ => false,
    };
    if (!inFrame && _pendingExpanded == null) {
      widget.onExpandedChanged?.call(expanded);
      return;
    }

    final alreadyScheduled = _pendingExpanded != null;
    _pendingExpanded = expanded;
    if (alreadyScheduled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pendingExpanded;
      _pendingExpanded = null;
      if (mounted && pending != null) widget.onExpandedChanged?.call(pending);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  String _title(AITranslations translations) {
    if (widget.isThinking) {
      if (_elapsed < const Duration(seconds: 1)) return translations.reasoningThinking;
      return translations.reasoningThinkingFor(translations.reasoningDuration(_elapsed));
    }
    final duration = widget.duration ?? _thoughtFor;
    if (duration == null) return translations.reasoningThought;
    const second = Duration(seconds: 1);
    return translations.reasoningThoughtFor(translations.reasoningDuration(duration < second ? second : duration));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ResolvedReasoningTheme.resolve(
      context,
      override: (widget.theme ?? const ReasoningThemeData()).copyWith(maxExpandedHeight: widget.maxExpandedHeight),
    );
    final translations = AITranslations.of(context);
    final title = _title(translations);
    final summary = widget.summary;
    final showsSummary = summary != null && summary.isNotEmpty && !widget.isThinking && !_open;
    final showsPanel = widget.text.isNotEmpty && (_open || !_fold.isDismissed);
    final showsFootnote =
        widget.footnote != null && !widget.isThinking && ((_choice ?? false) || widget.initiallyExpanded);

    final header = Semantics(
      container: true,
      button: true,
      expanded: _open,
      label: showsSummary ? '$title. $summary' : title,
      hint: _open ? translations.hideReasoningHint : translations.showReasoningHint,
      onTap: _toggle,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: _Header(
            title: title,
            summary: showsSummary ? summary : null,
            theme: theme,
            activity: widget.isThinking ? _activity : null,
            fold: _foldCurve,
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              if (showsPanel)
                ExcludeSemantics(
                  excluding: !_open,
                  // Shrinks in place and clips, so what sits below glides up.
                  child: SizeTransition(
                    sizeFactor: _foldCurve,
                    alignment: AlignmentDirectional.topStart,
                    child: FadeTransition(
                      opacity: _foldCurve,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          spacing: 6,
                          children: [
                            _ReasoningPanel(
                              text: widget.text,
                              isLive: widget.isThinking,
                              reduceMotion: _reduceMotion,
                              theme: theme,
                              onTapLink: widget.onTapLink,
                            ),
                            if (showsFootnote) Text(widget.footnote!, style: theme.footnoteStyle),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: widget.isThinking ? theme.shimmerColor : theme.ruleColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

/// The icon, title, summary and chevron.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.summary,
    required this.theme,
    required this.activity,
    required this.fold,
  });

  final String title;
  final String? summary;
  final ResolvedReasoningTheme theme;

  /// Running while the model thinks with motion on; `null` or stopped
  /// otherwise.
  final Animation<double>? activity;

  /// The panel's fold, which turns the chevron.
  final Animation<double> fold;

  @override
  Widget build(BuildContext context) {
    final titleStyle = theme.titleStyle.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final iconSize = (theme.titleStyle.fontSize ?? 14) * 1.2;
    final summaryColor = theme.textStyle.color!;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget titleText = Text(title, style: titleStyle, maxLines: 1, softWrap: false);
    Widget icon = Icon(Icons.psychology_outlined, size: iconSize, color: theme.iconColor);
    if (activity case final activity?) {
      titleText = _Shimmer(
        animation: activity,
        base: titleStyle.color!,
        highlight: theme.shimmerColor,
        child: titleText,
      );
      icon = _Pulse(animation: activity, child: icon);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        titleText,
        if (summary case final summary?) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              summary,
              style: theme.textStyle.copyWith(color: summaryColor.withValues(alpha: summaryColor.a * 0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(width: 4),
        RotationTransition(
          // A quarter turn towards the reading direction's "down".
          turns: Tween<double>(begin: 0, end: rtl ? -0.25 : 0.25).animate(fold),
          child: Icon(Icons.chevron_right, size: iconSize, color: theme.iconColor),
        ),
      ],
    );
  }
}

/// A highlight sweeping across [child] while [animation] runs.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.animation, required this.base, required this.highlight, required this.child});

  final Animation<double> animation;
  final Color base;
  final Color highlight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // From fully left of the text to fully right of it.
        final x = -1.6 + 3.2 * animation.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x - 0.6, 0),
            end: Alignment(x + 0.6, 0),
            colors: [base, highlight, base],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

/// [child] fading gently in and out while [animation] runs.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: 0.65 + 0.35 * math.cos(2 * math.pi * animation.value),
        child: child,
      ),
    );
  }
}

/// The reasoning, one paragraph at a time. It grows with the text up to the
/// theme's height, then scrolls, fading at the top so it reads as continuing
/// above. While the reasoning is live, new text is revealed smoothly and the
/// newest stays in view unless the reader scrolls up.
class _ReasoningPanel extends StatefulWidget {
  const _ReasoningPanel({
    required this.text,
    required this.isLive,
    required this.reduceMotion,
    required this.theme,
    required this.onTapLink,
  });

  final String text;
  final bool isLive;
  final bool reduceMotion;
  final ResolvedReasoningTheme theme;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  State<_ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<_ReasoningPanel> {
  /// How close to the end counts as "at the end" when the reader stops
  /// scrolling.
  static const _followSlop = 24.0;

  late final ReasoningTextReveal _reveal;
  final _paragraphs = ReasoningParagraphs();
  final _scroll = ScrollController();

  /// One widget per paragraph, reused for as long as its paragraph is
  /// unchanged — an identical widget is never rebuilt, so only the paragraph
  /// still being written is.
  var _views = <_ReasoningParagraph>[];

  /// Whether the newest text is kept in view.
  var _following = true;
  var _userScrolling = false;
  var _overflowing = false;
  var _followScheduled = false;

  @override
  void initState() {
    super.initState();
    // Opened text shows in full; only what arrives from here on is revealed.
    _reveal = ReasoningTextReveal(widget.text)..addListener(_onShown);
    _syncViews();
    // A finished trace opens at its start; a live one at its end.
    if (widget.isLive) _scheduleFollow();
  }

  @override
  void didUpdateWidget(_ReasoningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only whether links are tappable matters to the paragraphs, which call
    // the current callback through [_onTapLink]: a host passing a fresh closure
    // every build must not rebuild every paragraph.
    if (oldWidget.theme != widget.theme || (oldWidget.onTapLink == null) != (widget.onTapLink == null)) _views = [];
    if (oldWidget.isLive && !widget.isLive) _reveal.hurry();
    _reveal.update(widget.text, animated: widget.isLive && !widget.reduceMotion);
    if (widget.reduceMotion && _reveal.isRevealing) _reveal.update(widget.text, animated: false);
    _syncViews();
  }

  @override
  void dispose() {
    _reveal
      ..removeListener(_onShown)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onShown() {
    setState(_syncViews);
    // The last thoughts can land as the model stops thinking, so new text
    // keeps a reader who is following at the end either way.
    if (_following) _scheduleFollow();
  }

  void _syncViews() {
    final paragraphs = _paragraphs.update(_reveal.shown);
    final theme = widget.theme;
    _views = [
      for (var i = 0; i < paragraphs.length; i++)
        if (i < _views.length && _views[i].text == paragraphs[i])
          _views[i]
        else
          _ReasoningParagraph(
            text: paragraphs[i],
            theme: theme,
            onTapLink: widget.onTapLink == null ? null : _onTapLink,
          ),
    ];
  }

  void _onTapLink(String text, String? href, String title) => widget.onTapLink?.call(text, href, title);

  void _scheduleFollow([int attempts = 3]) {
    if (_followScheduled) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (!mounted || !_following || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.pixels == position.maxScrollExtent) return;
      // Either way: a lazy list estimates the extent of paragraphs it hasn't
      // built, so a jump can land past the real end, found once it is laid
      // out. Check again then.
      _scroll.jumpTo(position.maxScrollExtent);
      if (attempts > 1) _scheduleFollow(attempts - 1);
    });
  }

  bool _atEnd(ScrollMetrics metrics) => metrics.pixels >= metrics.maxScrollExtent - _followSlop;

  /// Only the reader's own scrolling stops or resumes following: the panel
  /// growing, or the jumps that follow, never do.
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification) {
      _userScrolling = notification.direction != ScrollDirection.idle;
      if (!_userScrolling) _following = _atEnd(notification.metrics);
    } else if (notification is ScrollUpdateNotification && _userScrolling) {
      _following = _atEnd(notification.metrics);
    }
    _updateOverflow(notification.metrics);
    return false;
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth == 0) _updateOverflow(notification.metrics);
    return false;
  }

  void _updateOverflow(ScrollMetrics metrics) {
    final overflowing = metrics.maxScrollExtent > 0;
    if (overflowing != _overflowing) setState(() => _overflowing = overflowing);
  }

  @override
  Widget build(BuildContext context) {
    final fadeTop = _overflowing ? const Color(0x00000000) : const Color(0xFF000000);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.theme.maxExpandedHeight),
          // Always present, so the list's state survives the fade appearing.
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fadeTop, const Color(0xFF000000)],
              stops: const [0, 0.14],
            ).createShader(bounds),
            child: _NoIntrinsics(
              child: ListView.separated(
                controller: _scroll,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _views.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _views[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reports no intrinsic size for [child] instead of asking it.
///
/// A lazy list can't measure itself without building every paragraph, so it
/// throws when asked — and hosts ask often: a chat bubble sized with
/// `IntrinsicWidth`, a `Table`. Answering zero lets the panel sit in one,
/// sized by whatever else is there, such as the header.
class _NoIntrinsics extends SingleChildRenderObjectWidget {
  const _NoIntrinsics({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoIntrinsics();
}

class _RenderNoIntrinsics extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.smallest;
}

/// One paragraph of reasoning, with its inline markdown rendered.
class _ReasoningParagraph extends StatefulWidget {
  const _ReasoningParagraph({required this.text, required this.theme, required this.onTapLink});

  final String text;
  final ResolvedReasoningTheme theme;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  State<_ReasoningParagraph> createState() => _ReasoningParagraphState();
}

class _ReasoningParagraphState extends State<_ReasoningParagraph> {
  final _recognizers = <GestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final style = widget.theme.textStyle;
    final onTapLink = widget.onTapLink;
    final spans = reasoningInlineSpans(
      widget.text,
      codeStyle: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Menlo', 'Consolas', 'Roboto Mono', 'DejaVu Sans Mono', 'Courier New'],
        fontSize: (style.fontSize ?? 14) * 0.92,
      ),
      linkStyle: TextStyle(color: widget.theme.shimmerColor, decoration: TextDecoration.underline),
      linkRecognizer: onTapLink == null
          ? null
          : (text, href, title) {
              final recognizer = TapGestureRecognizer()..onTap = () => onTapLink(text, href, title ?? '');
              _recognizers.add(recognizer);
              return recognizer;
            },
    );
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
