/// Interactive UI that an agent writes in
/// [OpenUI Lang](https://github.com/thesysdev/openui) 1.0 in its replies, for
/// the generative UI of `stream_chat_flutter_ai`.
///
/// Add an [OpenUIRenderer] to the conversation's `AIUIHost`. Its components
/// are customized with an [OpenUILibrary] and an [OpenUITheme].
library;

import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_renderer.dart';

export 'src/library/openui_component_name.dart' show OpenUIComponentName;
export 'src/library/openui_component_scope.dart' show OpenUIComponentScope;
export 'src/library/openui_library.dart' show OpenUIComponentBuilder, OpenUILibrary;
export 'src/library/openui_theme.dart' show OpenUITheme, OpenUIThemeData;
export 'src/openui_error.dart' show OpenUIError, OpenUIErrorCode, OpenUIErrorSource;
export 'src/openui_renderer.dart' show OpenUIErrorHandler, OpenUIRenderer;
