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
///
/// The tree is walked once: a node is equal to its previous one exactly when
/// its own fields match and every child came back as the previous child, so
/// no subtree is compared more than once.
ElementNode reuseUnchanged(ElementNode next, ElementNode? previous) {
  if (previous == null) return next;
  return _reuseNode(next, previous);
}

ElementNode _reuseNode(ElementNode next, ElementNode previous) {
  if (identical(next, previous)) return previous;
  if (next.typeName != previous.typeName) return next;
  final props = _reuseFields(next.props, previous.props);
  if (props == null &&
      next.partial == previous.partial &&
      next.hasDynamicProps == previous.hasDynamicProps &&
      next.statementId == previous.statementId) {
    return previous;
  }
  return ElementNode(
    typeName: next.typeName,
    props: props ?? previous.props,
    partial: next.partial,
    hasDynamicProps: next.hasDynamicProps,
    statementId: next.statementId,
  );
}

OpenUIValue _reuseValue(OpenUIValue next, OpenUIValue? previous) {
  if (previous == null) return next;
  if (identical(next, previous)) return previous;
  switch ((next, previous)) {
    case (OpenUIElement(node: final n), OpenUIElement(node: final p)):
      final node = _reuseNode(n, p);
      return identical(node, p) ? previous : OpenUIElement(node);
    case (OpenUIArray(items: final n), OpenUIArray(items: final p)):
      final items = _reuseItems(n, p);
      return items == null ? previous : OpenUIArray(items);
    case (OpenUIObject(fields: final n), OpenUIObject(fields: final p)):
      final fields = _reuseFields(n, p);
      return fields == null ? previous : OpenUIObject(fields);
    case (OpenUIElement() || OpenUIArray() || OpenUIObject(), _):
      return next;
    default:
      return next == previous ? previous : next;
  }
}

/// The fields of [next] with the values of [previous] reused, or `null` when
/// they equal [previous], so it can be kept as it is.
Map<String, OpenUIValue>? _reuseFields(Map<String, OpenUIValue> next, Map<String, OpenUIValue> previous) {
  final fields = <String, OpenUIValue>{};
  var same = next.length == previous.length;
  for (final MapEntry(:key, :value) in next.entries) {
    final old = previous[key];
    final reused = _reuseValue(value, old);
    same = same && old != null && identical(reused, old);
    fields[key] = reused;
  }
  return same ? null : fields;
}

/// The items of [next] with the items of [previous] reused, or `null` when
/// they equal [previous], so it can be kept as it is.
List<OpenUIValue>? _reuseItems(List<OpenUIValue> next, List<OpenUIValue> previous) {
  Map<String, OpenUIValue>? byStatement;
  final items = <OpenUIValue>[];
  var same = next.length == previous.length;
  for (var i = 0; i < next.length; i++) {
    final atIndex = i < previous.length ? previous[i] : null;
    final match = switch (next[i]) {
      OpenUIElement(:final node) when node.statementId != null =>
        (byStatement ??= _byStatement(previous))[node.statementId] ?? atIndex,
      _ => atIndex,
    };
    final reused = _reuseValue(next[i], match);
    // A statement used twice in an array is matched to its last use, which
    // can be equal to the item at this index without being the same object.
    same = same && (identical(reused, atIndex) || (!identical(match, atIndex) && reused == atIndex));
    items.add(reused);
  }
  return same ? null : items;
}

Map<String, OpenUIValue> _byStatement(List<OpenUIValue> items) => {
  for (final item in items)
    if (item case OpenUIElement(:final node) when node.statementId != null) node.statementId!: item,
};
