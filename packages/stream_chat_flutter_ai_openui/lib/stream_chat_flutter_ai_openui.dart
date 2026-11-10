/// Interactive UI that an agent writes in
/// [OpenUI Lang](https://github.com/thesysdev/openui) 1.0 in its replies, for
/// the generative UI of `stream_chat_flutter_ai`.
///
/// This package is in development: its components are customized with an
/// `OpenUILibrary` and an `OpenUITheme`, and the renderer that shows them in
/// a conversation comes later.
library;

export 'src/library/openui_component_name.dart' show OpenUIComponentName;
export 'src/library/openui_component_scope.dart' show OpenUIComponentScope;
export 'src/library/openui_library.dart' show OpenUIComponentBuilder, OpenUILibrary;
export 'src/library/openui_theme.dart' show OpenUITheme, OpenUIThemeData;
