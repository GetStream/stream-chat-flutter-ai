import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/graphql.dart';
import 'package:re_highlight/languages/ini.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/lua.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/objectivec.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/r.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scala.dart';
import 'package:re_highlight/languages/shell.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

/// The grammars `CodeBlockView` can highlight, keyed by fence language.
///
/// Curated rather than `re_highlight`'s own `builtinAllLanguages`, and
/// deliberately so. That map is a top-level `final` that references all 194 of
/// the bundled grammars, and each grammar is itself a top-level `final` holding
/// a tree of `Mode` constructor calls — so naming it makes 2.7 MB of Dart
/// source reachable, and nothing tree-shakes it back out of a host app. This
/// set is ~870 KB and covers what LLMs actually emit. Anything outside it falls
/// back to plain monospace text, which is the documented behaviour, not a
/// failure.
///
/// `swift` alone is 388 KB of that total — its grammar carries an enormous
/// built-in-identifier list. It stays in because it is the one language the
/// reference iOS package highlights at all.
///
/// Aliases don't need listing: [Highlight.registerLanguage] reads each
/// grammar's own `aliases`, so `js`/`jsx`/`mjs`, `ts`/`tsx`, `py`, `sh`, `yml`,
/// `c++`/`hpp`/`cxx`, `cs`/`c#`, `rb`, `kt`, `rs`, `md`, `objc`, `gql`,
/// `docker`, `html`/`svg`/`xhtml`, `text`/`txt` and `console` all resolve
/// through the entries below.
final Map<String, Mode> kCodeBlockLanguages = {
  'bash': langBash,
  'c': langC,
  'cpp': langCpp,
  'csharp': langCsharp,
  'css': langCss,
  'dart': langDart,
  'diff': langDiff,
  'dockerfile': langDockerfile,
  'go': langGo,
  'graphql': langGraphql,
  'ini': langIni,
  'java': langJava,
  'javascript': langJavascript,
  'json': langJson,
  'kotlin': langKotlin,
  'lua': langLua,
  'markdown': langMarkdown,
  'objectivec': langObjectivec,
  'php': langPhp,
  'plaintext': langPlaintext,
  'python': langPython,
  'r': langR,
  'ruby': langRuby,
  'rust': langRust,
  'scala': langScala,
  'shell': langShell,
  'sql': langSql,
  'swift': langSwift,
  'typescript': langTypescript,
  'xml': langXml,
  'yaml': langYaml,
};

/// The process-wide highlighter, with [kCodeBlockLanguages] registered.
///
/// A lazy top-level `final`, so the grammars are compiled on the first code
/// block a process renders rather than at startup, and only once.
final Highlight kCodeHighlight = Highlight()..registerLanguages(kCodeBlockLanguages);
