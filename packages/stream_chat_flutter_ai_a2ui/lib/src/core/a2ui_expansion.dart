part of 'a2ui_adapter.dart';

// The most components a surface may expand to, counting a component once for
// each place it shows. A component listed as a child several times on each
// level, or a template inside a template, multiplies the components under it,
// and the core builds every one of them, so a few kilobytes of components
// could otherwise build millions.
const _maxExpandedComponents = 5000;

// How deep below the root components may nest, as the core's own limit
// (`maxComponentDepth`), which it only checks when it validates messages for
// an agent. A deeper chain would overflow the stack when it is drawn.
const _maxDepth = 50;

// Why a surface's tree isn't built.
sealed class _Expansion {
  const _Expansion();
}

// The surface expands to more than [_maxExpandedComponents] components.
final class _TooManyComponents extends _Expansion {
  const _TooManyComponents();
}

// Component [id] nests more than [_maxDepth] levels below the root.
final class _NestedTooDeep extends _Expansion {
  const _NestedTooDeep(this.id);

  final String id;
}

// Why the tree from [rootId] in [components] can't be built, or `null` when
// it can.
//
// Walks the tree as the core builds it, and stops at the first component past
// a limit, so it takes at most `_maxExpandedComponents + 1` steps. A
// component counts once for each place it shows, a template child once for
// each item of the list [read] gives at its path, and a reference to a
// component that hasn't arrived, or to one of its own ancestors, once without
// its children. As in the core, an ancestor is the same component at the same
// data path, so a template may place its own component for each item. A component's children are the ids its type's [refs] name.
_Expansion? _expansionLimit(
  Map<String, Map<String, Object?>> components,
  core.ComponentRefMap Function(String? catalogId) refs, {
  required String rootId,
  required Object? Function(String path) read,
}) {
  var count = 0;
  final ancestors = <(String, String)>{};
  _Expansion? visit(String id, String dataPath, int depth) {
    count += 1;
    if (count > _maxExpandedComponents) return const _TooManyComponents();
    final component = components[id];
    if (component == null || ancestors.contains((id, dataPath))) return null;
    if (depth > _maxDepth) return _NestedTooDeep(id);
    ancestors.add((id, dataPath));
    final catalogId = component['catalogId'];
    final fields = refs(catalogId is String ? catalogId : null).fieldsFor('${component['component']}');
    for (final MapEntry(:key, :value) in fields.entries) {
      for (final (child, childPath) in _references(component[key], value, dataPath, read)) {
        final limit = visit(child, childPath, depth + 1);
        if (limit != null) return limit;
      }
    }
    ancestors.remove((id, dataPath));
    return null;
  }

  return visit(rootId, '/', 0);
}

// The components [value] places, as a property of [kind] read at
// [dataPath], each with the data path its own bindings read from.
Iterable<(String, String)> _references(
  Object? value,
  core.RefKind kind,
  String dataPath,
  Object? Function(String path) read,
) sync* {
  switch (kind) {
    case core.SingleRef():
      if (value is String) yield (value, dataPath);
    case core.ListRef():
      if (value is List<Object?>) {
        for (final id in value) {
          yield ('$id', dataPath);
        }
      } else if (value case {'componentId': final String template, 'path': final String path}) {
        final listPath = _resolvePath(dataPath, path);
        final items = read(listPath);
        if (items is! List<Object?>) return;
        for (var index = 0; index < items.length; index += 1) {
          yield (template, _resolvePath(listPath, '$index'));
        }
      }
    // No basic-catalog component has ids in a nested list, but another
    // catalog's may.
    case core.NestedRef(:final fields, :final includesIds):
      if (value is! List<Object?>) return;
      for (final item in value) {
        if (item is String && includesIds) yield (item, dataPath);
        if (item is! Map<String, Object?>) continue;
        for (final MapEntry(:key, value: itemKind) in fields.entries) {
          yield* _references(item[key], itemKind, dataPath, read);
        }
      }
  }
}

// [path] read from [base], as the core resolves a data path.
String _resolvePath(String base, String path) {
  if (path.startsWith('/')) return path;
  final trimmed = base.length > 1 && base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  if (path.isEmpty || path == '.') return trimmed;
  return '${trimmed == '/' ? '' : trimmed}/$path';
}
