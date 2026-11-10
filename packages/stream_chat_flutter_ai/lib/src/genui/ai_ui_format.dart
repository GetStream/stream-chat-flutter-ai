/// The format, or language, an agent writes its generated UI in, such as A2UI
/// or OpenUI.
///
/// Any string is a valid format: each renderer says which format it reads, so
/// an app can also support a format of its own.
///
/// ```dart
/// const cards = AIUIFormat('acme-cards');
/// ```
extension type const AIUIFormat(String _) implements String {
  /// [OpenUI](https://github.com/thesysdev/openui) Lang, where the agent writes
  /// the UI as a short program.
  static const openUI = AIUIFormat('openui');

  /// [A2UI](https://a2ui.org), where the agent writes the UI as a series of
  /// JSON messages.
  static const a2ui = AIUIFormat('a2ui');
}
