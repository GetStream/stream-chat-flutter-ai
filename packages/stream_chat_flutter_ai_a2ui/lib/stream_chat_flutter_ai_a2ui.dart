/// Interactive UI that an agent writes in [A2UI](https://a2ui.org) 1.0 in its
/// replies, shown in the generative UI of `stream_chat_flutter_ai`.
///
/// An `A2UIRenderer` added to a conversation's `AIUIHost` shows each reply's
/// A2UI in place of its text: surfaces drawn from a catalog of components,
/// such as text, images, rows, columns, cards and tabs, and the fields,
/// choices and buttons a person uses, with a theme made from the app's Stream
/// design system. What the person does in them reaches the agent as their
/// next message.
///
/// ```dart
/// final ui = AIUIHost(
///   renderers: [A2UIRenderer()],
///   send: (action) => channel.sendMessage(
///     Message(text: action.label, extraData: action.toCustomData()),
///   ),
/// );
/// ```
///
/// An `A2UIThemeData` overrides the look of the components, whose unset values
/// come from the Stream theme, and an `A2UICatalog` holds their builders, each of which can be drawn another way. A builder draws
/// with the surface's theme through `A2UITheme.of`:
///
/// ```dart
/// // In a `static final` field: a catalog made in `build` is a new one each
/// // time, so everything drawn with it is built again.
/// static final catalog = A2UICatalog.basic.replacing('Divider', (context, scope) {
///   final border = A2UITheme.of(context).border ?? context.streamColorScheme.borderDefault;
///   return Container(height: 1, color: border);
/// });
///
/// final renderer = A2UIRenderer(
///   theme: A2UIThemeData(cornerRadius: 8),
///   catalog: catalog,
/// );
/// ```
library;

export 'src/a2ui_error.dart' show A2UIError, A2UIErrorCode;
export 'src/a2ui_renderer.dart' show A2UIErrorHandler, A2UIRenderer;
export 'src/catalog/a2ui_catalog.dart' show A2UICatalog, A2UIComponentBuilder;
export 'src/catalog/a2ui_component_scope.dart' show A2UIChild, A2UIComponentScope;
export 'src/catalog/a2ui_theme.dart' show A2UITheme, A2UIThemeData;
