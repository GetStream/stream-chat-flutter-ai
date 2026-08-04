import 'package:markdown/markdown.dart' as md;

/// The AST tag that [MathInlineSyntax] and [MathBlockSyntax] emit.
///
/// Register a builder against this tag to render the expression; the raw TeX is
/// the element's `textContent`.
const kMathTag = 'math';

/// The attribute [MathInlineSyntax] and [MathBlockSyntax] set on the elements
/// they emit, to distinguish inline from display math.
///
/// The value is either [kMathDisplayInline] or [kMathDisplayBlock].
const kMathDisplayAttribute = 'display';

/// Value of [kMathDisplayAttribute] for math that flows with the surrounding
/// text, written `\(…\)` (or `$…$`).
const kMathDisplayInline = 'inline';

/// Value of [kMathDisplayAttribute] for math that occupies its own block,
/// written `\[…\]` (or `$$…$$`).
const kMathDisplayBlock = 'block';

/// Matches LaTeX that appears mid-line — `\(x^2\)` and `\[E = mc^2\]`, plus
/// `$x^2$` and `$$E = mc^2$$` when [useDollarDelimiters].
///
/// Emits an [kMathTag] element whose `textContent` is the TeX source.
/// [kMathDisplayAttribute] reflects the delimiter, so a `\[…\]` written in the
/// middle of a sentence still reports itself as display math — LLMs emit that
/// often, and [MathBlockSyntax] only claims a `\[` that begins a line.
///
/// **Register this after `md.CodeSyntax()`.** `package:markdown` evaluates
/// caller-supplied inline syntaxes before its own defaults (see
/// `inline_parser.dart`, "User specified syntaxes are the first syntaxes to be
/// evaluated"), so passing this syntax alone would let it claim the `$x$` inside
/// `` `$x$` `` before the backticks are considered. Pass `md.CodeSyntax()` first
/// in the same list to restore that precedence.
class MathInlineSyntax extends md.InlineSyntax {
  /// Creates a [MathInlineSyntax].
  ///
  /// When [useDollarDelimiters] is true, `$…$` and `$$…$$` are recognised in
  /// addition to `\(…\)` and `\[…\]`. It is off by default because `$` collides
  /// with currency in ordinary prose — "it costs $5 to $10" would otherwise
  /// typeset as math.
  MathInlineSyntax({this.useDollarDelimiters = false})
    : super(
        useDollarDelimiters ? _kBothPattern : _kBackslashPattern,
        // Both backslash forms start with the same character, so the parser can
        // rule this syntax out with a single code-unit check instead of running
        // the regex. The dollar variant has more than one opener, so it can't.
        startCharacter: useDollarDelimiters ? null : _kBackslash,
      );

  /// Whether `$…$` and `$$…$$` are recognised alongside `\(…\)` and `\[…\]`.
  final bool useDollarDelimiters;

  static const _kBackslash = 0x5C;

  // Group order is (block, inline) per delimiter family — `onMatch` relies on
  // it. The double-dollar alternative has to precede the single-dollar one, or
  // `$$x$$` would match as an empty `$…$` pair.
  static const _kBackslashPattern = r'\\\[([\s\S]+?)\\\]|\\\((.+?)\\\)';
  static const _kBothPattern =
      r'\\\[([\s\S]+?)\\\]|\\\((.+?)\\\)'
      r'|\$\$([\s\S]+?)\$\$|\$([^$\n]+?)\$';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    String? group(int i) => i <= match.groupCount ? match[i] : null;

    final blockTex = group(1) ?? group(3);
    final tex = blockTex ?? group(2) ?? group(4) ?? '';

    if (tex.trim().isEmpty) {
      // Nothing to typeset — keep the source text rather than dropping it.
      // Must still return true: `InlineSyntax.tryMatch` only consumes the match
      // when `onMatch` does, and its caller treats a match as progress either
      // way, so returning false here would spin the parser.
      parser.addNode(md.Text(match[0]!));
      return true;
    }

    parser.addNode(
      md.Element.text(kMathTag, tex.trim())
        ..attributes[kMathDisplayAttribute] = blockTex != null ? kMathDisplayBlock : kMathDisplayInline,
    );
    return true;
  }
}

/// Matches display LaTeX — `\[…\]`, and `$$…$$` when [useDollarDelimiters].
///
/// The expression may sit on the opening line (`\[E = mc^2\]`) or span lines:
///
/// ```text
/// \[
///   E = mc^2
/// \]
/// ```
///
/// Emits an [kMathTag] element whose `textContent` is the TeX source, with
/// [kMathDisplayAttribute] set to [kMathDisplayBlock].
///
/// An **unterminated** block still emits an element, mirroring how
/// `package:markdown` treats an unclosed code fence (CommonMark requires the
/// fence to run to the end of the document). That matters while streaming: the
/// expression typesets as it arrives instead of showing a bare `\[` until the
/// closing delimiter lands.
///
/// The [kMathTag] element is wrapped in a paragraph rather than emitted as a
/// block element of its own. `flutter_markdown_plus` decides block-vs-inline per
/// *builder*, not per element, so one tag cannot be both — and registering a new
/// block tag appends to a process-global list on every build (see
/// `flutter_markdown_plus`' `_kBlockTags`), which grows without bound under the
/// ~10ms rebuild cadence of a streaming message. Wrapping in `p` keeps a single
/// inline `math` builder sufficient for both forms and leaves that list alone.
class MathBlockSyntax extends md.BlockSyntax {
  /// Creates a [MathBlockSyntax].
  ///
  /// When [useDollarDelimiters] is true, `$$…$$` is recognised in addition to
  /// `\[…\]`. See [MathInlineSyntax.useDollarDelimiters] for why it is off by
  /// default.
  const MathBlockSyntax({this.useDollarDelimiters = false});

  /// Whether `$$…$$` is recognised alongside `\[…\]`.
  final bool useDollarDelimiters;

  static final _kParenPattern = RegExp(r'^\s{0,3}\\\[');
  static final _kBothPattern = RegExp(r'^\s{0,3}(?:\\\[|\$\$)');

  @override
  RegExp get pattern => useDollarDelimiters ? _kBothPattern : _kParenPattern;

  @override
  md.Node? parse(md.BlockParser parser) {
    final opening = pattern.firstMatch(parser.current.content)!;
    final closer = opening[0]!.trimLeft() == r'$$' ? r'$$' : r'\]';

    final lines = <String>[];
    // Whatever follows the opening delimiter on the same line.
    final head = parser.current.content.substring(opening.end);
    parser.advance();

    final headClose = head.indexOf(closer);
    if (headClose >= 0) {
      lines.add(head.substring(0, headClose));
    } else {
      lines.add(head);
      while (!parser.isDone) {
        final line = parser.current.content;
        parser.advance();
        final close = line.indexOf(closer);
        if (close >= 0) {
          lines.add(line.substring(0, close));
          break;
        }
        lines.add(line);
      }
    }

    final tex = lines.join('\n').trim();
    // An empty `\[\]` carries nothing to render; the position has already
    // advanced, so returning null just drops the block.
    if (tex.isEmpty) return null;

    return md.Element('p', [
      md.Element.text(kMathTag, tex)..attributes[kMathDisplayAttribute] = kMathDisplayBlock,
    ]);
  }
}
