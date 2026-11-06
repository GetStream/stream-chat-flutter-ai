import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_citations.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_strings.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';

/// Builds the chat library's `Card`: its `children` in a column on a raised,
/// bordered surface as wide as the space it is given, with its `sources`
/// below them.
///
/// A `[n]` in the text of its children links to the nth source that has a
/// web address; a source without one is counted but isn't linked.
///
/// Internal to the package.
@internal
Widget buildOpenUIChatCard(BuildContext context, OpenUIComponentScope scope) {
  final theme = OpenUITheme.of(context);
  final colors = theme.colors!;
  final sources = [
    for (final source in openUIJsonList(scope.value('sources')))
      if (source is Map<String, Object?>) source,
  ];
  final addresses = {
    for (final (index, source) in sources.indexed)
      if (source['url'] case final String url when url.isNotEmpty) index + 1: url,
  };
  return OpenUICitationSources(
    sources: addresses,
    child: SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(theme.radius!.large!),
          border: Border.all(color: colors.border!.withValues(alpha: colors.border!.a * _borderOpacity), width: 0.5),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing!.l!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: theme.spacing!.m!,
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

  final List<Map<String, Object?>> sources;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: theme.spacing!.s!,
      children: [
        SizedBox(
          width: double.infinity,
          height: 1,
          child: ColoredBox(color: colors.border!),
        ),
        Text(
          OpenUIStrings.sourcesTitle,
          style: theme.textStyles!.caption!.copyWith(fontWeight: FontWeight.w600, color: colors.textSecondary),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.spacing!.s!,
              children: [for (final (index, source) in sources.indexed) _Source(number: index + 1, source: source)],
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
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    final styles = theme.textStyles!;
    final url = source['url'] is String ? source['url']! as String : '';
    final title = source['title'] is String ? source['title']! as String : OpenUIStrings.untitledSource;
    final name = source['sourceName'] is String ? source['sourceName']! as String : '';
    final badge = openUIScaled(context, 18);
    return Semantics(
      button: url.isNotEmpty,
      link: url.isNotEmpty,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: url.isEmpty ? null : () => openOpenUILink(context, url),
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: openUIScaled(context, _sourceWidth)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.sunkenSurface,
              borderRadius: BorderRadius.circular(theme.radius!.small!),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing!.s!),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: badge, minHeight: badge),
                      child: Center(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          '$number',
                          style: styles.caption!.copyWith(fontWeight: FontWeight.w700, color: colors.onAccent),
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
                          style: styles.caption!.copyWith(fontWeight: FontWeight.w500, color: colors.textPrimary),
                        ),
                        if (name.isNotEmpty)
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: styles.caption!.copyWith(color: colors.textSecondary),
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
