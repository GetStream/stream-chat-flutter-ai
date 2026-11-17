/// The program a reply's generated UI holds.
///
/// One of the core's boundary files: code outside `lib/src/core/` may import
/// it.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/preprocessor.dart';

/// The OpenUI Lang program in `content`, the `content` of a reply's `ai_ui`
/// field, ready for the runtime.
///
/// The backend writes there what was inside the reply's fenced block. When
/// the block's closing fence wasn't a bare ```` ``` ```` line, such as
/// ```` ```Enjoy! ````, that fence and what the reply says after it follow
/// the program, and are cut off here; see
/// [Preprocessor.withoutTrailingFence]. Any other content is returned
/// unchanged.
String openUIProgramOf(String content) => Preprocessor.withoutTrailingFence(content);
