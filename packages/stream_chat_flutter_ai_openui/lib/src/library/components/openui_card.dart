import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_citations.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_strings.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Builds the chat library's `Card`: its `children` in a column on a raised,
/// bordered surface as wide as the space it is given, with its `sources`
/// below them.
///
/// A `[n]` in the text of its children links to the nth entry of its `sources`
/// when that is a source with a web address; an entry that isn't one is
/// counted but isn't linked.
///
/// Internal to the package.
@internal
Widget buildOpenUIChatCard(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUIViewScope.of(context).theme;
  // Numbered as the model listed them, so its `[n]` names the nth entry even
  // when an entry before it isn't a source.
  final listed = openUIJsonList(scope.value('sources'));
  final sources = [
    for (final (index, source) in listed.indexed)
      if (source is Map<String, Object?>) (number: index + 1, source: source),
  ];
  final addresses = {
    for (final (:number, :source) in sources)
      if (source['url'] case final String url when url.isNotEmpty) number: url,
  };
  return OpenUICitationSources(
    sources: addresses,
    child: SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(theme.cornerRadius),
          border: Border.all(color: theme.border.withValues(alpha: theme.border.a * _borderOpacity), width: 0.5),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.lSpacing),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.mSpacing,
            children: [
              scope.buildProp('children'),
              if (sources.isNotEmpty) _Sources(sources: sources),
            ],
          ),
        ),
      ),
    ),
  );
}

// How opaque a card's border is, of its color's own opacity.
const _borderOpacity = 0.6;

class _Sources extends StatelessWidget {
  const _Sources({required this.sources});

  final List<({int number, Map<String, Object?> source})> sources;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.sSpacing,
      children: [
        SizedBox(
          width: double.infinity,
          height: 1,
          child: ColoredBox(color: theme.border),
        ),
        Text(
          OpenUIStrings.sourcesTitle,
          style: theme.caption.copyWith(fontWeight: FontWeight.w600, color: theme.secondaryText),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.sSpacing,
              children: [for (final (:number, :source) in sources) _Source(number: number, source: source)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Source extends StatelessWidget {
  const _Source({required this.number, required this.source});

  final int number;
  final Map<String, Object?> source;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final url = source['url'] is String ? source['url']! as String : '';
    // Only a link the view can open is announced as one.
    final openable = OpenUIViewScope.of(context).openLink != null && openableOpenUILink(url) != null;
    final title = source['title'] is String ? source['title']! as String : OpenUIStrings.untitledSource;
    final name = source['sourceName'] is String ? source['sourceName']! as String : '';
    final badge = openUIScaled(context, 18);
    return Semantics(
      button: openable,
      link: openable,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: openable ? () => openOpenUILink(context, url) : null,
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: openUIScaled(context, _sourceWidth)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.sunkenSurface,
              borderRadius: BorderRadius.circular(theme.smallCornerRadius),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.sSpacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: badge, minHeight: badge),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          '$number',
                          style: theme.caption.copyWith(fontWeight: FontWeight.w700, color: theme.onAccent),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.caption.copyWith(fontWeight: FontWeight.w500, color: theme.text),
                        ),
                        if (name.isNotEmpty)
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.caption.copyWith(color: theme.secondaryText),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// The width of a source's box, before the text size scales it.
const _sourceWidth = 180.0;
