import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_item_context.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_node_props.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_strings.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `SnippetCardBlock`: its `items` as cards, each with a `lhs` and,
/// beside it or below when there is no room, a smaller `rhs`.
///
/// A snippet block is always a grid.
///
/// With an `action`, the block's items can be tapped, unless the reply is
/// still streaming, to run it with what the tapped item shows merged in.
///
/// Internal to the package.
@internal
Widget buildOpenUISnippetCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(
    context,
    scope,
    kind: 'Snippet',
    describe: _describeSnippet,
    minItem: 150,
    carouselItem: 220,
    forceGrid: true,
    equalHeight: true,
    (context, item) {
      final lhs = item.element('lhs');
      final rhs = item.element('rhs');
      return _Surface(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: OpenUIViewScope.of(context).theme.sSpacing,
          runSpacing: OpenUIViewScope.of(context).theme.sSpacing,
          children: [
            if (lhs != null) item.scope.buildNode(lhs),
            if (rhs != null) item.scope.buildNode(withOpenUIProps(rhs, {'size': const OpenUIString('xs')})),
          ],
        ),
      );
    },
  );
}

/// Builds an `OverviewCardBlock`: its `items` as cards, each with a `top`
/// component and a `bottom` metric at the card's foot.
///
/// The `bottom` is drawn as a `MetricIndicatorInline` whatever its type is.
///
/// With an `action`, the block's items can be tapped, unless the reply is
/// still streaming, to run it with what the tapped item shows merged in.
///
/// Internal to the package.
@internal
Widget buildOpenUIOverviewCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(
    context,
    scope,
    kind: 'Overview',
    describe: _describeOverview,
    minItem: 140,
    carouselItem: 180,
    equalHeight: true,
    (context, item) {
      final top = item.element('top');
      final bottom = item.element('bottom');
      return _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: OpenUIViewScope.of(context).theme.mSpacing,
          children: [
            if (top != null) item.scope.buildNode(top),
            const Spacer(),
            if (bottom != null)
              // Drawn as a metric whatever its type is.
              item.scope.buildNode(
                ElementNode(
                  typeName: 'MetricIndicatorInline',
                  props: bottom.props,
                  partial: bottom.partial,
                  hasDynamicProps: bottom.hasDynamicProps,
                  statementId: bottom.statementId,
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Builds a `ContextCardBlock`: its `items` as cards, each with a `title`, a
/// `body` and, when it has a `bgImageSrc`, that image behind them.
///
/// A `title` that is a `Tag` is drawn as a tag. The `bgColor` isn't drawn.
///
/// With an `action`, the block's items can be tapped, unless the reply is
/// still streaming, to run it with what the tapped item shows merged in.
///
/// Internal to the package.
@internal
Widget buildOpenUIContextCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(
    context,
    scope,
    kind: 'Context',
    describe: _describeContext,
    minItem: 150,
    carouselItem: 210,
    equalHeight: true,
    (context, item) {
      final theme = OpenUIViewScope.of(context).theme;
      final source = item.scope.string('bgImageSrc');
      final image = source != null && source.isNotEmpty;
      final titleNode = item.element('title');
      final body = item.scope.text('body') ?? '';
      final scheme = context.streamColorScheme;
      final onImage = image ? scheme.textOnAccent : null;
      final titleText = openUIJsonText(item.scope.value('title'));
      final title = titleNode != null && titleNode.typeName == 'Tag'
          ? item.scope.buildNode(titleNode)
          : titleText.isEmpty
          ? null
          : Text(
              titleText,
              style: theme.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: image ? onImage!.withValues(alpha: 0.9) : theme.secondaryText,
              ),
            );
      return ClipRRect(
        borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: image
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        OpenUIRemoteImage(source: source, alt: item.scope.text('bgImageAlt')),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [scheme.backgroundOverlayDark, scheme.backgroundOverlayDarkStrong],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ColoredBox(color: theme.sunkenSurface),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: image ? 150 : 100),
              child: Padding(
                padding: EdgeInsets.all(theme.mSpacing),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: theme.sSpacing,
                    children: [
                      ?title,
                      Expanded(
                        child: ConstrainedBox(constraints: BoxConstraints(minHeight: image ? 40 : 0)),
                      ),
                      if (body.isNotEmpty)
                        OpenUIMarkdownText(
                          data: body,
                          style: theme.bodySmall.copyWith(fontWeight: FontWeight.w600),
                          color: onImage ?? theme.text,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Builds a `CompositeCardBlock`: its `items` as cards, each with a `header`,
/// a `body` of components and a `footer` with a `price` and a `button`.
///
/// Components in the `body` and `footer` are drawn smaller to fit the card;
/// see [normalizeOpenUICompositeProps]. The `button` runs its own action.
///
/// With an `action`, the block's items can be tapped, unless the reply is
/// still streaming, to run it with what the tapped item shows merged in.
///
/// Internal to the package.
@internal
Widget buildOpenUICompositeCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(
    context,
    scope,
    kind: 'Composite',
    describe: _describeComposite,
    minItem: 250,
    carouselItem: 270,
    equalHeight: true,
    (context, item) {
      final spacing = OpenUIViewScope.of(context).theme.mSpacing;
      final header = item.element('header');
      final footerPrice = item.scope.elementField('footer', 'price');
      final footerButton = item.scope.elementField('footer', 'button');
      final hasFooter = item.scope.value('footer') is Map;
      return _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: spacing,
          children: [
            if (header != null) item.scope.buildNode(header),
            for (final node in item.scope.elements('body'))
              item.scope.buildNode(normalizeOpenUICompositeProps(node, footer: false)),
            const Spacer(),
            if (hasFooter)
              Row(
                spacing: spacing,
                children: [
                  if (footerPrice != null)
                    Expanded(child: item.scope.buildNode(normalizeOpenUICompositeProps(footerPrice, footer: true))),
                  if (footerPrice == null) const Spacer(),
                  if (footerButton != null)
                    item.scope.buildNode(withOpenUIProps(footerButton, {'size': const OpenUIString('small')})),
                ],
              ),
          ],
        ),
      );
    },
  );
}

/// Builds a `VisualCardBlock`: its `items` as cards, each an image
/// (`bgImageSrc`) with its `body` over the foot of it and its `tag` at the top.
///
/// With an `action`, the block's items can be tapped, unless the reply is
/// still streaming, to run it with what the tapped item shows merged in.
///
/// Internal to the package.
@internal
Widget buildOpenUIVisualCardBlock(BuildContext context, OpenUIComponentScope scope) {
  return _block(
    context,
    scope,
    kind: 'Visual',
    describe: _describeVisual,
    minItem: 150,
    carouselItem: 200,
    equalHeight: true,
    (context, item) {
      final theme = OpenUIViewScope.of(context).theme;
      final bodyNode = item.element('body');
      final bodyScope = bodyNode == null ? null : item.scope.scopeOf(bodyNode);
      final tag = item.element('tag');
      final scheme = context.streamColorScheme;
      final white = scheme.textOnAccent;
      return ClipRRect(
        borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OpenUIRemoteImage(source: item.scope.string('bgImageSrc'), alt: item.scope.text('bgImageAlt')),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [scheme.backgroundOverlayDark.withValues(alpha: 0), scheme.backgroundOverlayDarkStrong],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 190),
              child: Padding(
                padding: EdgeInsets.all(theme.mSpacing),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tag != null)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(theme.pillCornerRadius),
                          ),
                          child: item.scope.buildNode(tag),
                        ),
                      const Expanded(child: SizedBox.shrink()),
                      if (bodyScope != null) ...[
                        Text(
                          bodyScope.text('value') ?? '',
                          style: theme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: white),
                        ),
                        if ((bodyScope.text('subtext') ?? '').isNotEmpty)
                          Text(
                            bodyScope.text('subtext')!,
                            style: theme.caption.copyWith(color: white.withValues(alpha: 0.85)),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// [node], a component in the body or footer of a composite card item, with
/// the props that make it fit the card.
///
/// - `Text` and `BoldText` in the body get the size `xs`.
/// - `AreaChart`, `BarChart` and `LineChart` get the `height` 180.
/// - `ListBlock` gets the size `small`, `EntityList` the size `small` without
///   its `header` and `footer`, `TagBlock` the size `sm` and `Button` the size
///   `small`.
///
/// Any other component is returned as it is. Internal to the package.
@internal
ElementNode normalizeOpenUICompositeProps(ElementNode node, {required bool footer}) {
  return switch (node.typeName) {
    'Text' || 'BoldText' when !footer => withOpenUIProps(node, {'size': const OpenUIString('xs')}),
    'AreaChart' || 'BarChart' || 'LineChart' => withOpenUIProps(node, {'height': const OpenUINumber(180)}),
    'ListBlock' => withOpenUIProps(node, {'size': const OpenUIString('small')}),
    'EntityList' => withOpenUIProps(
      ElementNode(
        typeName: node.typeName,
        props: {
          for (final MapEntry(:key, :value) in node.props.entries)
            if (key != 'header' && key != 'footer') key: value,
        },
        partial: node.partial,
        hasDynamicProps: node.hasDynamicProps,
        statementId: node.statementId,
      ),
      {'size': const OpenUIString('small')},
    ),
    'TagBlock' => withOpenUIProps(node, {'size': const OpenUIString('sm')}),
    'Button' => withOpenUIProps(node, {'size': const OpenUIString('small')}),
    _ => node,
  };
}

// What [build] builds for the item [node], or nothing when it throws; the
// error goes to [FlutterError.reportError], as for any component.
Widget _guarded(ElementNode node, Widget Function() build) {
  try {
    return build();
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'stream_chat_flutter_ai_openui',
        context: ErrorDescription("while building the OpenUI card item '${node.typeName}'"),
      ),
    );
    return const SizedBox.shrink();
  }
}

// One item of a block, read through its own scope.
class _Item {
  const _Item(this.scope);

  final OpenUIComponentScope scope;

  ElementNode? element(String name) => scope.elements(name).firstOrNull;

  // The prop [field] of the component in the prop [name].
  OpenUIValue? sub(String name, String field) => element(name)?.props[field];
}

// What a tap on a card item sends: the label it runs the block's action with,
// or `null` for the block's numbered one, and the item's context, without its
// `itemIndex`.
typedef _Description = (String?, Map<String, OpenUIValue>);

// [value] when it is a string.
OpenUIString? _string(OpenUIValue? value) => value is OpenUIString ? value : null;

// The text of the first string of [values].
String? _firstText(List<OpenUIValue?> values) => values.whereType<OpenUIString>().firstOrNull?.value;

_Description _describeSnippet(_Item item) {
  final id = _string(item.scope.prop('id'));
  final title = _string(item.sub('lhs', 'title'));
  return (
    _firstText([title, id]),
    {
      'itemId': ?id,
      'itemTitle': ?title,
      'itemSubtitle': ?_string(item.sub('lhs', 'subtitle')),
      'itemValue': ?_string(item.sub('rhs', 'value')),
    },
  );
}

_Description _describeOverview(_Item item) {
  final id = _string(item.scope.prop('id'));
  final title = _string(item.sub('top', 'title')) ?? _string(item.sub('top', 'value'));
  return (
    _firstText([title, id]),
    {
      'itemId': ?id,
      'itemTitle': ?title,
      'itemSubtitle': ?(_string(item.sub('top', 'subtitle')) ?? _string(item.sub('top', 'subtext'))),
      'itemMetricValue': ?item.sub('bottom', 'value'),
    },
  );
}

_Description _describeContext(_Item item) {
  final scope = item.scope;
  final title = switch (scope.prop('title')) {
    OpenUIString(:final value) => value,
    OpenUIElement(:final node) when node.typeName == 'Tag' => _string(node.props['text'])?.value ?? '',
    _ => '',
  };
  return (
    title.isNotEmpty ? title : scope.text('id'),
    {
      'itemId': ?scope.prop('id'),
      'itemTitle': OpenUIString(title),
      'itemBody': ?scope.prop('body'),
      'itemBgColor': ?scope.prop('bgColor'),
      'itemBgImageSrc': ?scope.prop('bgImageSrc'),
      'itemBgImageAlt': ?scope.prop('bgImageAlt'),
    },
  );
}

_Description _describeComposite(_Item item) {
  final scope = item.scope;
  final id = _string(scope.prop('id'));
  final title = _string(item.sub('header', 'title')) ?? _string(item.sub('header', 'value'));
  final alt = _string(item.sub('header', 'alt'));
  final footer = switch (scope.prop('footer')) {
    OpenUIObject(:final fields) => fields,
    _ => const <String, OpenUIValue>{},
  };
  OpenUIValue? footerProp(String name, String field) => switch (footer[name]) {
    OpenUIElement(:final node) => node.props[field],
    _ => null,
  };
  return (
    _firstText([title, alt, id]),
    {
      'itemId': ?id,
      'itemHeaderTitle': ?title,
      'itemHeaderSubtitle': ?(_string(item.sub('header', 'subtitle')) ?? _string(item.sub('header', 'subtext'))),
      'itemHeaderAlt': ?alt,
      'itemBodyCount': OpenUINumber(switch (scope.prop('body')) {
        OpenUIArray(:final items) => items.length.toDouble(),
        _ => 0,
      }),
      'itemFooterPrice': ?footerProp('price', 'value'),
      'itemFooterButtonLabel': ?footerProp('button', 'label'),
    },
  );
}

_Description _describeVisual(_Item item) {
  final scope = item.scope;
  final body = _string(item.sub('body', 'value'));
  final tag = _string(item.sub('tag', 'text'));
  return (
    body?.value ?? tag?.value ?? scope.text('id'),
    {
      'itemId': ?scope.prop('id'),
      'itemTag': ?tag,
      'itemBody': ?body,
      'itemBodySubtext': ?item.sub('body', 'subtext'),
      'itemBgImageSrc': ?scope.prop('bgImageSrc'),
      'itemBgImageAlt': ?scope.prop('bgImageAlt'),
    },
  );
}

Widget _block(
  BuildContext context,
  OpenUIComponentScope scope,
  Widget Function(BuildContext context, _Item item) build, {
  required String kind,
  required _Description Function(_Item item) describe,
  required double minItem,
  required double carouselItem,
  bool forceGrid = false,
  bool equalHeight = false,
}) {
  final theme = OpenUIViewScope.of(context).theme;
  final gap = openUIGap(theme, scope.value('gap'));
  final wantsCarousel = !forceGrid && scope.string('layout') == 'carousel';
  final action = scope.prop('action');
  final tappable = action != null && action is! OpenUINull;
  final items = [
    for (final (index, node) in scope.elements('items').indexed)
      Builder(
        builder: (context) {
          final item = _Item(scope.scopeOf(node));
          final card = _guarded(node, () => build(context, item));
          if (!tappable) return card;
          return OpenUIPressable(
            onTap: scope.isStreaming
                ? null
                : () {
                    final (label, context_) = describe(item);
                    triggerOpenUIAction(
                      context,
                      scope,
                      label: label ?? OpenUIStrings.cardItem(kind, index + 1),
                      action: mergeOpenUIItemContext(action, {
                        'itemIndex': OpenUINumber(index.toDouble()),
                        ...context_,
                      }),
                    );
                  },
            child: card,
          );
        },
      ),
  ];
  if (items.isEmpty) return const SizedBox.shrink();
  Widget fit(Widget row) => equalHeight ? IntrinsicHeight(child: row) : row;
  Widget carousel() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: fit(
        Row(
          crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
          spacing: gap,
          children: [for (final item in items) SizedBox(width: carouselItem, child: item)],
        ),
      ),
    );
  }

  if (wantsCarousel) return carousel();
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      // Columns share a width that is bounded; where it isn't, the items scroll.
      if (!width.isFinite) return carousel();
      final columns = math.max(1, math.min(3, math.min(items.length, ((width + gap) / (minItem + gap)).floor())));
      return Column(
        spacing: gap,
        children: [
          for (var start = 0; start < items.length; start += columns)
            fit(
              Row(
                crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
                spacing: gap,
                children: [
                  for (var index = start; index < start + columns; index++)
                    Expanded(child: index < items.length ? items[index] : const SizedBox.shrink()),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.sunkenSurface,
        borderRadius: BorderRadius.circular(theme.mediumCornerRadius),
      ),
      child: Padding(padding: EdgeInsets.all(theme.mSpacing), child: child),
    );
  }
}
