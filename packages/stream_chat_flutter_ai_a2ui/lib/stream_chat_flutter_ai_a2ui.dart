/// Interactive UI that an agent writes in [A2UI](https://a2ui.org) 1.0 in its
/// replies, for the generative UI of `stream_chat_flutter_ai`.
///
/// A reply's A2UI is drawn from a catalog of components, such as text, images,
/// rows, columns, cards and tabs, and the fields, choices and buttons a person
/// uses, with a theme made from the app's Stream design system. An
/// `A2UITheme` overrides its look with an `A2UIThemeData`, whose unset values
/// come from the Stream theme, and an `A2UICatalog` holds its components, each
/// of which can be drawn another way. A builder draws with the surface's theme
/// through `A2UITheme.of`:
///
/// ```dart
/// A2UITheme(data: A2UIThemeData(cornerRadius: 8), child: child);
///
/// // In a `static final` field: a catalog made in `build` is a new one each
/// // time, so everything drawn with it is built again.
/// static final catalog = A2UICatalog.basic.replacing('Divider', (context, scope) {
///   final border = A2UITheme.of(context).border ?? context.streamColorScheme.borderDefault;
///   return Container(height: 1, color: border);
/// });
/// ```
///
/// The renderer that shows a reply's A2UI in a conversation, and takes a
/// theme and a catalog, is not part of the package yet.
library;

export 'src/catalog/a2ui_catalog.dart' show A2UICatalog, A2UIComponentBuilder;
export 'src/catalog/a2ui_component_scope.dart' show A2UIChild, A2UIComponentScope;
export 'src/catalog/a2ui_theme.dart' show A2UITheme, A2UIThemeData;
