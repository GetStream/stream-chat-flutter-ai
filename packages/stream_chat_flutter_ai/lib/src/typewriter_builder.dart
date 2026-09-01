import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

/// {@template typewriterState}
/// The current typing state of a typewriter.
/// {@endtemplate}
enum TypewriterState {
  /// The typewriter is not typing.
  idle,

  /// The typewriter is currently typing.
  typing,

  /// The typewriter is paused at the current char index.
  paused,

  /// The typewriter has stopped typing and has reset the current char index.
  stopped,
}

/// {@template typewriterValue}
/// A value class that holds the current text and typing state of a typewriter.
///
/// The [text] field holds the current text that has been typed out. The [state]
/// field holds the current typing state of the typewriter.
/// {@endtemplate}
class TypewriterValue {
  /// {@macro typewriterValue}
  const TypewriterValue({
    this.text = '',
    this.state = TypewriterState.idle,
  });

  /// The current text that has been typed out.
  final String text;

  /// The current typing state of the typewriter.
  final TypewriterState state;

  /// Creates a copy of this [TypewriterValue] with the given fields replaced
  /// by the new values.
  TypewriterValue copyWith({
    String? text,
    TypewriterState? state,
  }) {
    return TypewriterValue(
      text: text ?? this.text,
      state: state ?? this.state,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TypewriterValue && other.text == text && other.state == state;
  }

  @override
  int get hashCode => text.hashCode ^ state.hashCode;
}

/// {@template typewriterController}
/// A controller for a [TypewriterBuilder]. It allows you to control the
/// typing state of the typewriter. You can start, pause, and stop typing the
/// target text.
///
/// To use a [TypewriterController], simply create one and pass it to a
/// [TypewriterBuilder]. The builder will listen to the controller and
/// rebuild whenever the value changes. You can then control the typing state
/// by calling [startTyping], [pauseTyping], and [stopTyping] on the controller.
///
/// ```dart
/// final controller = TypewriterController(text: 'Hello, World!');
///
/// @override
/// Widget build(BuildContext context) {
///  return TypewriterBuilder(
///    controller: controller,
///    builder: (context, value, child) {
///      return Text(value.text);
///    },
///   );
///  }
///
/// // Start typing the target text.
/// controller.startTyping();
///
/// // Pause typing at the current char index.
/// controller.pauseTyping();
///
/// // Stop typing and reset the current char index.
/// controller.stopTyping();
///
/// // Update the target text.
/// controller.updateText('Hello, Flutter!');
/// ```
/// {@endtemplate}
class TypewriterController extends ValueNotifier<TypewriterValue> {
  /// {@macro typewriterController}
  TypewriterController({
    String text = '',
    this.typingSpeed = const Duration(milliseconds: 10),
  }) : super(TypewriterValue(text: text)) {
    // Start fully revealed: a controller constructed with its complete text
    // represents an already-finished message (e.g. one loaded from history),
    // not one waiting to be typed out.
    _targetText = value.text.characters;
    _currentCharIndex = _targetText.length;
  }

  /// The speed at which the text should be typed out.
  ///
  /// Defaults to `10 milliseconds` per character.
  final Duration typingSpeed;

  Timer? _timer;

  late int _currentCharIndex;
  late Characters _targetText;

  /// Every method here maintains the invariant
  /// `value.text == _targetText.take(_currentCharIndex).string`.
  ///
  /// Breaking it is what makes the displayed text go stale: the index is what
  /// [startTyping] checks to decide whether there is anything left to reveal,
  /// so an index that outruns the target silently freezes the view on text
  /// that is no longer being typed.
  void _reveal(int charIndex, {TypewriterState? state}) {
    _currentCharIndex = charIndex;
    value = value.copyWith(text: _targetText.take(charIndex).string, state: state);
  }

  /// Cancels the current typing timer and displays the target text immediately.
  ///
  /// This is useful when you want to display the target text immediately
  /// without typing it out.
  set text(String newText) {
    _timer?.cancel();
    _targetText = newText.characters;
    _reveal(_targetText.length, state: TypewriterState.idle);
  }

  /// Updates the target text to [newText].
  ///
  /// If the controller is currently typing, the new text will be typed out
  /// automatically. If it is not typing, the new text will be typed out only
  /// if [autoStart] is true.
  ///
  /// [newText] is treated as a continuation when it starts with the text
  /// already on screen — the common streaming case, where each chunk appends
  /// to the last — and typing simply carries on from where it was.
  ///
  /// Anything else (a regenerated or edited message, a shorter replacement, an
  /// error message swapped in for a partial reply) is treated as a *new* text
  /// and revealed from the start. Without this, a replacement shorter than what
  /// is already displayed would leave the previous text on screen indefinitely,
  /// because there would be nothing left for [startTyping] to reveal.
  void updateText(String newText, {bool autoStart = true}) {
    final target = newText.characters;
    // Compared in grapheme clusters, the unit [_currentCharIndex] counts. A
    // plain `startsWith` is a UTF-16 test, and the two disagree when a chunk
    // boundary lands inside a cluster: "👨" is a prefix of "👨‍👩‍👦" by code unit
    // but not by grapheme, and treating that as a continuation left the index
    // past the end of a target one cluster long, freezing the view.
    final isContinuation = target.length >= _currentCharIndex && target.take(_currentCharIndex).string == value.text;
    _targetText = target;

    if (!isContinuation) {
      _timer?.cancel();
      _reveal(0, state: TypewriterState.idle);
    }

    // Start typing the new text if autoStart is true.
    //
    // This is only needed if the controller is currently not typing. If it is
    // typing, the new text will be typed out automatically.
    if (autoStart) startTyping();
  }

  /// Starts typing the target text.
  ///
  /// If the target text is already being typed out or is already all typed out,
  /// this method does nothing.
  ///
  /// To pause or stop typing, call [pauseTyping] or [stopTyping] respectively.
  void startTyping() {
    // If already typing, return.
    if (value.state == TypewriterState.typing) return;

    // If target text is already all typed out, return.
    if (_currentCharIndex >= _targetText.length) return;

    value = value.copyWith(state: TypewriterState.typing);

    // Defensive: never leave a previous timer running alongside a new one.
    _timer?.cancel();
    _timer = Timer.periodic(typingSpeed, (timer) {
      if (_currentCharIndex < _targetText.length) {
        _reveal(min(_currentCharIndex + 1, _targetText.length));
      } else {
        timer.cancel();
        value = value.copyWith(state: TypewriterState.idle);
      }
    });
  }

  /// Pauses typing at the current char index.
  ///
  /// To resume typing, call [startTyping].
  void pauseTyping() {
    if (value.state != TypewriterState.typing) return;

    _timer?.cancel();
    value = value.copyWith(state: TypewriterState.paused);
  }

  /// Stops typing and resets back to the start of the target text.
  ///
  /// Unlike [pauseTyping], this clears the revealed text as well as the char
  /// index, so a subsequent [startTyping] types the target out from the
  /// beginning rather than jumping from the fully-revealed text back to its
  /// first character.
  ///
  /// Note the "resets" — this empties the view. To end a stream while keeping
  /// what has been revealed, use [pauseTyping]; to end it showing everything
  /// received so far, use [finishTyping].
  void stopTyping() {
    _timer?.cancel();
    _reveal(0, state: TypewriterState.stopped);
  }

  /// Stops typing and reveals the whole target text at once.
  ///
  /// The natural companion to a "stop generating" control: the user wants the
  /// reply to stop growing, not to disappear ([stopTyping]) or to freeze
  /// half-written ([pauseTyping]).
  void finishTyping() {
    _timer?.cancel();
    _reveal(_targetText.length, state: TypewriterState.idle);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// {@template typewriterWidgetBuilder}
/// A widget builder for a [TypewriterBuilder]. It allows you to build a
/// widget depending on the [TypewriterValue]'s value.
/// {@endtemplate}
typedef TypewriterWidgetBuilder =
    Widget Function(
      BuildContext context,
      TypewriterValue value,
      Widget? child,
    );

/// {@template typewriterBuilder}
/// A widget that listens to a [TypewriterController] and rebuilds whenever the
/// value changes. It allows you to build a widget depending on the controller's
/// value.
/// {@endtemplate}
class TypewriterBuilder extends StatelessWidget {
  /// {@macro typewriterBuilder}
  const TypewriterBuilder({
    super.key,
    required this.controller,
    required this.builder,
    this.child,
  });

  /// The TypewriterController to listen to.
  final TypewriterController controller;

  /// The builder to build the widget depending on the controller's value.
  final TypewriterWidgetBuilder builder;

  /// The child widget to pass to the builder.
  ///
  /// This is typically used to pass a widget that does not depend on the
  /// controller's value.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: builder,
      child: child,
    );
  }
}
