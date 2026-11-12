import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_generator.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/schemas/schema_dsl.dart';

// The test library of the OpenUI Lang specification's fixtures
// (conformance/generated/spec-library.json), written with this package's
// schema types.
LibraryDefinition specLibrary() {
  return LibraryDefinition(
    root: 'Stack',
    components: [
      ComponentSchema(
        'Stack',
        description: 'Lays out children in a column or a row',
        props: [
          required('children', array(any)),
          optional('direction', enumeration(['row', 'column'])),
        ],
      ),
      ComponentSchema(
        'Card',
        description: 'A titled container',
        props: [required('title', string), optional('children', array(any))],
      ),
      ComponentSchema(
        'Text',
        description: 'A run of text',
        props: [
          required('text', string),
          optional('variant', enumeration(['body', 'heading'])),
        ],
      ),
      ComponentSchema(
        'Tag',
        description: 'A small colored label',
        props: [
          required('text', string),
          optional('color', enumeration(['gray', 'green', 'red'])),
        ],
      ),
      ComponentSchema(
        'Metric',
        description: 'A labeled number',
        props: [required('label', string), required('value', number)],
      ),
      ComponentSchema(
        'Button',
        description: 'A clickable button',
        props: [
          required('label', string),
          optional('action', action),
          optional('variant', enumeration(['primary', 'secondary'])),
          optional('share', const PropType.actions(['CopyToClipboard', 'OpenUrl'])),
        ],
      ),
      ComponentSchema(
        'Form',
        description: 'Groups its inputs under a form name',
        props: [required('name', string), required('children', array(any))],
      ),
      ComponentSchema(
        'Input',
        description: 'A text field',
        props: [
          required('name', string),
          optional('placeholder', string),
          binding('value', string),
          optional('rules', object(const [])),
        ],
      ),
      ComponentSchema(
        'Select',
        description: 'A dropdown',
        props: [required('name', string), required('items', array(any)), binding('value', string)],
      ),
      ComponentSchema(
        'SelectItem',
        description: 'One option of a Select',
        props: [required('value', string), required('label', string)],
      ),
      ComponentSchema(
        'Table',
        description: 'A table built from columns',
        props: [required('columns', array(any))],
      ),
      ComponentSchema(
        'Col',
        description: 'One table column: a header and its cell values',
        props: [required('label', string), optional('data', array(any))],
      ),
    ],
    functions: [
      FunctionSchema(
        'Upper',
        description: 'The text in upper case',
        params: [required('text', string)],
        returns: string,
      ),
    ],
    actions: [
      ActionSchema('CopyToClipboard', description: 'Copies text to the clipboard', params: [required('text', string)]),
    ],
  );
}

/// The spec of a library, as a library spec file holds it.
///
/// It holds `root` when the library has one, each component's `signature`
/// and `description` by name as `components`, `componentGroups`,
/// `functions` and `actions` when it has any, and its JSON Schema as
/// `schema`.
extension LibrarySpec on LibraryDefinition {
  /// The library as a spec.
  Map<String, Object?> toSpec() {
    Map<String, Object?> entry(String signature, String description) {
      return {'signature': signature, 'description': description};
    }

    return {
      'root': ?root,
      'components': {
        for (final component in this.components) component.name: entry(component.signature, component.description),
      },
      if (componentGroups.isNotEmpty)
        'componentGroups': [
          for (final group in componentGroups)
            {
              'name': group.name,
              'components': group.components,
              if (group.notes.isNotEmpty) 'notes': group.notes,
            },
        ],
      if (functions.isNotEmpty)
        'functions': {
          for (final function in functions) function.name: entry(function.signature, function.description),
        },
      if (actions.isNotEmpty)
        'actions': {for (final action in actions) action.name: entry(action.signature, action.description)},
      'schema': toJsonSchema(),
    };
  }
}

/// Reads a library spec, as `jsonDecode` gives it, into the spec of a system
/// prompt.
///
/// Parts that are missing or of the wrong type read as empty, a `root` that
/// isn't a string as none.
PromptSpec promptSpecFromLibrarySpec(Map<String, Object?> spec, {PromptOptions options = const PromptOptions()}) {
  String? string(Object? value) => value is String ? value : null;
  List<Object?> list(Object? value) => value is List<Object?> ? value : const [];
  List<PromptEntry> entries(Object? section) {
    if (section is! Map<String, Object?>) return const [];
    return [
      for (final MapEntry(key: name, value: entry) in section.entries)
        if (entry is Map<String, Object?>)
          PromptEntry(name, string(entry['signature']) ?? '', string(entry['description']) ?? ''),
    ];
  }

  return PromptSpec(
    root: string(spec['root']),
    components: entries(spec['components']),
    componentGroups: [
      for (final group in list(spec['componentGroups']))
        if (group is Map<String, Object?>)
          ComponentGroup(
            string(group['name']) ?? '',
            components: list(group['components']).whereType<String>().toList(),
            notes: list(group['notes']).whereType<String>().toList(),
          ),
    ],
    functions: entries(spec['functions']),
    actions: entries(spec['actions']),
    options: options,
  );
}
