part of 'a2ui_adapter.dart';

// The problems that keep the tree of [surface] from being whole, in the
// order they are found: a component that holds itself or names a child that
// doesn't exist, no `root` component, and components that hold each other in
// a circle. A component the root doesn't reach is fine: a streamed reply
// leaves behind the placeholders it replaced. Nesting too deep is reported
// as the messages apply (see [_expansionLimit]).
List<A2UIError> _topologyErrors(A2UISurface surface, A2UICatalogs catalogs) {
  final components = surface._componentsById();
  final defaultCatalogId = surface._model.defaultCatalog?.id;
  final references = {
    for (final MapEntry(key: id, value: component) in components.entries)
      id: _childReferences(component, catalogs._refsOf(_catalogIdOf(component) ?? defaultCatalogId)),
  };
  final errors = <A2UIError>[];
  void add(A2UIErrorCode code, String message) {
    errors.add(A2UIError(code: code, message: message, surfaceId: surface.id));
  }

  for (final MapEntry(key: id, value: children) in references.entries) {
    for (final (field, childId) in children) {
      if (childId == id) {
        add(
          A2UIErrorCode.recursionLimitExceeded,
          "Self-reference detected: component '$id' refers to itself in field '$field'.",
        );
      } else if (!components.containsKey(childId)) {
        add(
          A2UIErrorCode.integrityError,
          "Dangling reference: component '$id' references non-existent component '$childId' in field '$field'.",
        );
      }
    }
  }
  const rootId = 'root';
  if (!components.containsKey(rootId)) {
    add(
      A2UIErrorCode.validationFailed,
      "Missing root component: surface '${surface.id}' has no component with id '$rootId'.",
    );
    return errors;
  }
  final cycle = _cycleFrom(rootId, references);
  if (cycle != null) {
    add(A2UIErrorCode.recursionLimitExceeded, 'Circular reference detected: ${cycle.join(' -> ')}.');
  }
  return errors;
}

String? _catalogIdOf(Map<String, Object?> component) {
  final catalogId = component['catalogId'];
  return catalogId is String ? catalogId : null;
}

// The children [component] names, each with the field that names it, such as
// `children[1]` or `tabs[0].child`. A template names its component once.
List<(String, String)> _childReferences(Map<String, Object?> component, core.ComponentRefMap refs) {
  final fields = refs.fieldsFor('${component['component']}');
  return [
    for (final MapEntry(:key, :value) in fields.entries) ..._namedIn(component[key], value, key),
  ];
}

Iterable<(String, String)> _namedIn(Object? value, core.RefKind kind, String field) sync* {
  switch (kind) {
    case core.SingleRef():
      if (value is String) yield (field, value);
    case core.ListRef():
      if (value is List<Object?>) {
        for (final (index, id) in value.indexed) {
          yield ('$field[$index]', '$id');
        }
      } else if (value case {'componentId': final String template}) {
        yield ('$field.componentId', template);
      }
    case core.NestedRef(:final fields, :final includesIds):
      if (value is! List<Object?>) return;
      for (final (index, item) in value.indexed) {
        if (item is String && includesIds) yield ('$field[$index]', item);
        if (item is! Map<String, Object?>) continue;
        for (final MapEntry(key: itemKey, value: itemKind) in fields.entries) {
          yield* _namedIn(item[itemKey], itemKind, '$field[$index].$itemKey');
        }
      }
  }
}

// The children of [id] that exist, leaving out references to itself.
Iterable<String> _existingChildren(String id, Map<String, List<(String, String)>> references) sync* {
  for (final (_, child) in references[id] ?? const <(String, String)>[]) {
    if (child != id && references.containsKey(child)) yield child;
  }
}

// The ids along a circle the components [start] reaches hold, ending with the
// one that closes it, or `null` when there is none. Walks without recursion,
// so a long chain of components can't overflow the stack.
List<String>? _cycleFrom(String start, Map<String, List<(String, String)>> references) {
  final done = <String>{};
  final path = <String>[start];
  final onPath = <String>{start};
  final pending = <Iterator<String>>[_existingChildren(start, references).iterator];
  while (pending.isNotEmpty) {
    final children = pending.last;
    if (!children.moveNext()) {
      pending.removeLast();
      final id = path.removeLast();
      onPath.remove(id);
      done.add(id);
      continue;
    }
    final child = children.current;
    if (done.contains(child)) continue;
    if (onPath.contains(child)) return [...path.sublist(path.indexOf(child)), child];
    path.add(child);
    onPath.add(child);
    pending.add(_existingChildren(child, references).iterator);
  }
  return null;
}
