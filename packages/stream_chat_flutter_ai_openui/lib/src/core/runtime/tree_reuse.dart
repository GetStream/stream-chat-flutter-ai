import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

/// Gives [next], a freshly evaluated tree, the objects of [previous] wherever
/// the two are equal, so the parts of a reply that did not change keep their
/// identity from one evaluation to the next.
///
/// Elements are matched by position in their parent's props and arrays, and
/// array items that are statements are also matched by the statement they
/// came from, so reordered, added and removed children still find their
/// previous objects.
ElementNode reuseUnchanged(ElementNode next, ElementNode? previous) {
  if (previous == null) return next;
  return _reuseNode(next, previous);
}

ElementNode _reuseNode(ElementNode next, ElementNode previous) {
  if (identical(next, previous) || next == previous) return previous;
  if (next.typeName != previous.typeName) return next;
  final props = {
    for (final MapEntry(:key, :value) in next.props.entries) key: _reuseValue(value, previous.props[key]),
  };
  return ElementNode(
    typeName: next.typeName,
    props: props,
    partial: next.partial,
    hasDynamicProps: next.hasDynamicProps,
    statementId: next.statementId,
  );
}

OpenUIValue _reuseValue(OpenUIValue next, OpenUIValue? previous) {
  if (previous == null) return next;
  if (identical(next, previous) || next == previous) return previous;
  return switch ((next, previous)) {
    (OpenUIElement(node: final n), OpenUIElement(node: final p)) => OpenUIElement(_reuseNode(n, p)),
    (OpenUIArray(items: final n), OpenUIArray(items: final p)) => OpenUIArray(_reuseItems(n, p)),
    (OpenUIObject(fields: final n), OpenUIObject(fields: final p)) => OpenUIObject({
      for (final MapEntry(:key, :value) in n.entries) key: _reuseValue(value, p[key]),
    }),
    _ => next,
  };
}

List<OpenUIValue> _reuseItems(List<OpenUIValue> next, List<OpenUIValue> previous) {
  final byStatement = <String, OpenUIValue>{
    for (final item in previous)
      if (item case OpenUIElement(:final node) when node.statementId != null) node.statementId!: item,
  };
  return [
    for (var i = 0; i < next.length; i++)
      _reuseValue(
        next[i],
        switch (next[i]) {
          OpenUIElement(:final node) when node.statementId != null && byStatement.containsKey(node.statementId) =>
            byStatement[node.statementId],
          _ => i < previous.length ? previous[i] : null,
        },
      ),
  ];
}
