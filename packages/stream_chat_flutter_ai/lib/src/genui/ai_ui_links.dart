import 'package:stream_chat_flutter_ai/src/genui/ai_ui_host.dart';

/// The links generated UI may hand to [AIUIHosting.open].
///
/// An agent writes every link in its replies, so a renderer passes on only
/// web, email and phone links, whatever opens them; a link to another app or
/// a file never reaches the app.
///
/// The host's default opener is stricter still: it opens web links to a host
/// and email links only. An app that passes its own `open` gets the links
/// these schemes allow and decides which of them it opens.
abstract final class AIUILinks {
  /// The schemes a link may have: `http`, `https`, `mailto` and `tel`.
  static const schemes = {'http', 'https', 'mailto', 'tel'};

  /// Whether generated UI may hand [url] to the host: whether its scheme is
  /// one of [schemes], in any case.
  static bool allows(Uri url) => schemes.contains(url.scheme.toLowerCase());
}
