import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_arguments.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component_context.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component_definition.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_entrance.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// One of the app's own widgets, such as a map or a place card, that the agent
/// can use in its generated UI.
///
/// A component has three parts:
/// - a [definition] that tells the agent its name, its parameters and its
///   events
/// - [readArguments], which turns the values the agent filled in into a [T]
/// - [build], which builds the widget from that [T]
///
/// The agent places a component by its name, so the same component works in
/// every format. A component can also load its own data on the device, such
/// as the person's calendar, without sending it to the agent.
///
/// ```dart
/// class PlaceCardComponent extends AIUIComponent<String> {
///   const PlaceCardComponent();
///
///   @override
///   AIUIComponentDefinition get definition => const AIUIComponentDefinition(
///     name: 'place_card',
///     description: 'A photo and a short summary of a place.',
///     parameters: [AIUIParameter.required('title', AIUIParameterType.string)],
///     events: [AIUIComponentEvent(name: 'ask_about', description: 'The person asks about the place.')],
///   );
///
///   @override
///   String readArguments(AIUIArguments arguments) => arguments.string('title');
///
///   @override
///   Widget build(BuildContext context, String title, AIUIComponentContext ui) => PlaceCard(
///     title: title,
///     onTap: () => ui.emit('ask_about', label: 'Tell me more about $title'),
///   );
/// }
/// ```
///
/// Extend it rather than implementing it. Members added in later versions come
/// with a default, so a subclass keeps compiling, while a class that
/// `implements` it would break.
abstract class AIUIComponent<T> {
  /// Creates an [AIUIComponent].
  const AIUIComponent();

  /// Describes the component to the agent.
  AIUIComponentDefinition get definition;

  /// The name the agent uses to place the component: the [definition]'s
  /// name.
  String get name => definition.name;

  /// Turns the values the agent filled in into the [T] that [build] uses.
  ///
  /// Throws when the values are incomplete or have the wrong type, as
  /// [AIUIArguments]' getters do. The component then shows nothing, which is
  /// what happens while the agent is still writing them.
  T readArguments(AIUIArguments arguments);

  /// Builds the widget for the [arguments] that [readArguments] returned.
  ///
  /// When the person interacts with it, the widget tells the agent with
  /// `ui.emit`.
  Widget build(BuildContext context, T arguments, AIUIComponentContext ui);

  /// The component's widget for the [arguments] the agent wrote, or `null`
  /// when [readArguments] throws, such as while the agent is still writing
  /// them.
  ///
  /// A [FormatException], which [AIUIArguments] throws, means the agent's
  /// arguments don't fit, and is reported in debug builds once the UI is
  /// written. Anything else is the app's own error, and is reported to
  /// [FlutterError.onError].
  ///
  /// The widget is wrapped in an [AIUIEntrance], so it animates in when it
  /// appears. Renderers call this to place a component.
  Widget? view(Map<String, Object?> arguments, AIUIComponentContext context) {
    final T read;
    try {
      read = readArguments(AIUIArguments(arguments));
    } on FormatException catch (error) {
      if (!context.isStreaming) {
        reportPartIssue(() => 'The arguments of the component "$name" don\'t fit its parameters ($error).');
      }
      return null;
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while reading the arguments of the component "$name"'),
        ),
      );
      return null;
    }
    return AIUIEntrance(child: Builder(builder: (buildContext) => build(buildContext, read, context)));
  }

  @override
  String toString() => 'AIUIComponent($name)';
}
