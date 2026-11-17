import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The sources of the chat library's `Card` around [child], by their number:
/// what `[1]` in the text below it links to.
///
/// Internal to the package.
@internal
class OpenUICitationSources extends InheritedWidget {
  /// Creates the sources, whose keys count from 1.
  const OpenUICitationSources({super.key, required this.sources, required super.child});

  /// The address of each source that has one, by its number from 1.
  final Map<int, String> sources;

  /// The sources around [context], or an empty map.
  static Map<int, String> of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OpenUICitationSources>()?.sources ?? const {};
  }

  @override
  bool updateShouldNotify(OpenUICitationSources oldWidget) => !mapEquals(sources, oldWidget.sources);
}

/// Returns [text] with each `[n]` that names one of [sources] as a Markdown
/// link to it.
///
/// A `[n]` of one or two digits becomes `[[n]](address)`. It stays as written
/// in fenced code and code spans, after a `[` or a backslash, before a `(` or
/// a `:`, when there is no source n, and when the source's address has no
/// scheme.
///
/// Internal to the package.
@internal
String linkCitations(String text, Map<int, String> sources) {
  if (sources.isEmpty || !text.contains('[')) return text;
  final lines = text.split('\n');
  // The opening run of the fence we are in, or null.
  String? fence;
  for (final (index, line) in lines.indexed) {
    final trimmed = line.trim();
    if (fence != null) {
      if (trimmed.isNotEmpty && trimmed.length >= fence.length && trimmed == fence[0] * trimmed.length) fence = null;
      continue;
    }
    final opening = _fence.firstMatch(line.trimLeft());
    if (opening != null && !(opening[1]!.startsWith('`') && opening[2]!.contains('`'))) {
      fence = opening[1];
      continue;
    }
    lines[index] = _linkLine(line, sources);
  }
  return lines.join('\n');
}

// An opening fence: its run of backticks or tildes, and the rest of the line.
final _fence = RegExp(r'^(`{3,}|~{3,})(.*)$');

String _linkLine(String line, Map<int, String> sources) {
  final out = StringBuffer();
  var i = 0;
  while (i < line.length) {
    final char = line[i];
    if (char == '`') {
      var run = 0;
      while (i + run < line.length && line[i + run] == '`') {
        run++;
      }
      final ticks = '`' * run;
      var close = line.indexOf(ticks, i + run);
      while (close != -1 && ((close + run < line.length && line[close + run] == '`') || line[close - 1] == '`')) {
        close = line.indexOf(ticks, close + 1);
      }
      if (close == -1) {
        out.write(ticks);
        i += run;
      } else {
        out.write(line.substring(i, close + run));
        i = close + run;
      }
      continue;
    }
    if (char == '[' && (i == 0 || (line[i - 1] != '[' && line[i - 1] != r'\'))) {
      final citation = _citationAt(line, i, sources);
      if (citation != null) {
        out.write(citation.$1);
        i = citation.$2;
        continue;
      }
    }
    out.write(char);
    i++;
  }
  return out.toString();
}

// The link for the `[n]` at [start] and where it ends, or null.
(String, int)? _citationAt(String line, int start, Map<int, String> sources) {
  var end = start + 1;
  while (end < line.length && end - start - 1 < 3 && _isDigit(line.codeUnitAt(end))) {
    end++;
  }
  final digits = end - start - 1;
  if (digits < 1 || digits > 2 || end >= line.length || line[end] != ']') return null;
  if (end + 1 < line.length && (line[end + 1] == '(' || line[end + 1] == ':')) return null;
  final number = int.parse(line.substring(start + 1, end));
  final address = sources[number]?.trim();
  final uri = address == null ? null : Uri.tryParse(address);
  if (uri == null || !uri.hasScheme) return null;
  final destination = uri
      .toString()
      .replaceAll('(', '%28')
      .replaceAll(')', '%29')
      .replaceAll(' ', '%20')
      .replaceAll('<', '%3C')
      .replaceAll('>', '%3E')
      .replaceAll('"', '%22');
  return ('[[$number]]($destination)', end + 1);
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;
