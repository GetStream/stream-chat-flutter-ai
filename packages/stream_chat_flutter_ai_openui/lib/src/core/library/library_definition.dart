/// The components, functions and actions a model can write a program with,
/// and the system prompt that teaches it to.
///
/// Internal to the package.
@internal
library;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_generator.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prop_type.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/schemas/built_in_libraries.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/skipped_component_log.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/builtin_calls.dart';

/// The components, functions and actions a model can write a program with,
/// and how the system prompt describes them.
///
/// ```dart
/// final library = LibraryDefinition.chat.removing(['Carousel']);
/// final prompt = library.systemPrompt();
/// ```
final class LibraryDefinition {
  /// Creates a library of [components], in library order, whose programs
  /// fall back to the [root] component.
  ///
  /// A component whose name an earlier one has replaces it in place. A
  /// function or action whose name is a built-in call, `Query`, `Mutation`,
  /// `ActionExpression`, a component, or an earlier function or action is
  /// left out.
  ///
  /// Throws an [ArgumentError] when [root] isn't one of the components.
  LibraryDefinition({
    this.root,
    required List<ComponentSchema> components,
    List<ComponentGroup> componentGroups = const [],
    this.defaultPromptOptions = const PromptOptions(),
    List<FunctionSchema> functions = const [],
    List<ActionSchema> actions = const [],
  }) : components = List.unmodifiable(_ordered(components)),
       componentGroups = List.unmodifiable(componentGroups) {
    if (root != null && !this.components.any((component) => component.name == root)) {
      throw ArgumentError.value(root, 'root', 'Not one of the components');
    }
    final names = {for (final component in this.components) component.name};
    bool claim(String name) {
      if (BuiltinCalls.isBuiltin(name) || BuiltinCalls.isReservedCall(name)) return false;
      return !_actionShapes.containsKey(name) && names.add(name);
    }

    this.functions = List.unmodifiable([
      for (final function in functions)
        if (claim(function.name)) function,
    ]);
    this.actions = List.unmodifiable([
      for (final action in actions)
        if (claim(action.name)) action,
    ]);
  }

  /// The chat library, whose programs fall back to a vertical `Card` as
  /// their root.
  static final LibraryDefinition chat = LibraryDefinition(
    root: chatRoot,
    components: chatComponents,
    componentGroups: chatComponentGroups,
    defaultPromptOptions: PromptOptions(additionalRules: chatAdditionalRules, examples: chatExamples),
  );

  /// The standard library, whose programs fall back to a `Stack` as their
  /// root, with layouts, modals and cards for a whole screen.
  static final LibraryDefinition standard = LibraryDefinition(
    root: standardRoot,
    components: standardComponents,
    componentGroups: standardComponentGroups,
    defaultPromptOptions: PromptOptions(additionalRules: standardAdditionalRules, examples: standardExamples),
  );

  /// The component a program without a `root` statement falls back to, or
  /// `null` when there is none.
  final String? root;

  /// The components, in library order.
  final List<ComponentSchema> components;

  /// How the system prompt groups the components.
  final List<ComponentGroup> componentGroups;

  /// The examples and rules [systemPrompt] uses when it is given no options.
  final PromptOptions defaultPromptOptions;

  /// The app's functions, called as `@Name(...)`.
  late final List<FunctionSchema> functions;

  /// The app's action steps, used as `@Name(...)` in actions.
  late final List<ActionSchema> actions;

  /// The library compiled for reading programs.
  late final OpenUILibrarySchema schema = OpenUILibrarySchema.fromJsonSchema(toJsonSchema(), root: root);

  /// Whether a program can call a component named `name`.
  ///
  /// A callable name is an ASCII capital letter, then ASCII letters and
  /// digits, and neither a built-in call, `Query`, `Mutation`, nor the name of
  /// an action's shape (`ActionExpression`, `OpenUrl` or `ToAssistant`).
  static bool isCallableName(String name) {
    if (!_callableName.hasMatch(name)) return false;
    if (BuiltinCalls.isBuiltin(name)) return false;
    if (_actionShapes.containsKey(name)) return false;
    return !BuiltinCalls.isReservedCall(name);
  }

  /// A function that says whether a component named `name` can join this
  /// library, and claims the name when it can.
  ///
  /// A name can't join when it can't be called in a program (see
  /// [isCallableName]) or when it is already a component, function or action
  /// of this library or one the function claimed before. It logs why, in
  /// debug mode, when it turns a name down.
  bool Function(String name) componentNameClaim() {
    final taken = {
      ...componentNames,
      for (final function in functions) function.name,
      for (final action in actions) action.name,
    };
    return (name) {
      if (!isCallableName(name)) {
        logSkippedComponent('OpenUI: skipped the component "$name": its name can\'t be called in a program.');
        return false;
      }
      if (!taken.add(name)) {
        logSkippedComponent(
          'OpenUI: skipped the component "$name": the library already has a component, function or action '
          'by that name.',
        );
        return false;
      }
      return true;
    };
  }

  static List<ComponentSchema> _ordered(List<ComponentSchema> components) {
    final byName = <String, ComponentSchema>{};
    for (final component in components) {
      byName[component.name] = component;
    }
    return byName.values.toList();
  }

  static final _callableName = RegExp(r'^[A-Z][A-Za-z0-9]*$');

  // The shapes of the built-in action steps an action prop takes.
  static const _actionShapes = <String, Map<String, Object?>>{
    PropType.actionExpression: {
      'anyOf': [_openUrlShape, _toAssistantShape, _customStepShape],
    },
    'OpenUrl': _openUrlShape,
    'ToAssistant': _toAssistantShape,
  };

  static const _openUrlShape = <String, Object?>{
    'type': 'object',
    'properties': {
      'type': {'type': 'string', 'const': 'open_url'},
      'url': {'type': 'string'},
    },
    'required': ['type', 'url'],
    'additionalProperties': false,
  };

  static const _toAssistantShape = <String, Object?>{
    'type': 'object',
    'properties': {
      'type': {'type': 'string', 'const': 'continue_conversation'},
      'context': {'type': 'string'},
    },
    'required': ['type'],
    'additionalProperties': false,
  };

  static const _customStepShape = <String, Object?>{
    'type': 'object',
    'properties': {
      'type': {'type': 'string'},
      'params': {
        'type': 'object',
        'propertyNames': {'type': 'string'},
        'additionalProperties': <String, Object?>{},
      },
    },
    'required': ['type'],
    'additionalProperties': false,
  };

  /// The component names, in library order.
  List<String> get componentNames => [for (final component in components) component.name];

  /// The component `name`, or `null` when the library has none.
  ComponentSchema? component(String name) => components.firstWhereOrNull((component) => component.name == name);

  /// Whether `prop` of `component` also takes a `$variable`, which it reads
  /// and writes.
  bool isBindable(String component, String prop) {
    return this.component(component)?.props.any((schema) => schema.name == prop && schema.bindable) ?? false;
  }

  /// The library as a JSON Schema document.
  ///
  /// Each component is a `$defs` entry, as are the shapes of the actions its
  /// props take; the entries are in the order they are first reached, depth
  /// first, from the components in library order. `properties` and
  /// `required` name every component, and `functions` and `actions` describe
  /// the library's own, when it has any.
  Map<String, Object?> toJsonSchema() {
    final byName = {for (final component in components) component.name: component};
    final shapes = {..._actionShapes, for (final action in actions) action.name: action.stepSchema};
    final definitions = <String, Object?>{};
    void visit(DefinitionReference reference) {
      if (definitions.containsKey(reference.name)) return;
      final component = byName[reference.name];
      if (component != null) {
        definitions[reference.name] = component.jsonSchema;
        for (final prop in component.props) {
          prop.type.definitionReferences.forEach(visit);
        }
        return;
      }
      if (!reference.isAction) return;
      final shape = shapes[reference.name];
      if (shape != null) definitions[reference.name] = shape;
    }

    for (final component in components) {
      visit(DefinitionReference(component.name));
    }
    return {
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      'type': 'object',
      'properties': {
        for (final component in components) component.name: {r'$ref': '#/\$defs/${component.name}'},
      },
      'required': componentNames,
      'additionalProperties': false,
      r'$defs': definitions,
      if (functions.isNotEmpty)
        'functions': {
          for (final function in functions)
            function.name: {
              'description': function.description,
              'params': function.paramsSchema,
              if (function.returns case final returns?) 'returns': returns.jsonSchema,
            },
        },
      if (actions.isNotEmpty)
        'actions': {
          for (final action in actions) action.name: {'description': action.description, 'params': action.paramsSchema},
        },
    };
  }

  /// The system prompt that teaches a model to write programs with this
  /// library, generated with `options`, or with [defaultPromptOptions] when
  /// `options` is `null`.
  String systemPrompt([PromptOptions? options]) {
    return PromptGenerator.generate(
      PromptSpec(
        root: root,
        components: [
          for (final component in components) PromptEntry(component.name, component.signature, component.description),
        ],
        componentGroups: componentGroups,
        functions: [
          for (final function in functions) PromptEntry(function.name, function.signature, function.description),
        ],
        actions: [for (final action in actions) PromptEntry(action.name, action.signature, action.description)],
        options: options ?? defaultPromptOptions,
      ),
    );
  }

  /// A copy of this library without the components named in `names`.
  ///
  /// They are also taken out of every prop that takes other types too, and a
  /// group left with no component is dropped. The [root] stays, and so does a
  /// component that is the only type a remaining prop takes, with the
  /// components it needs in turn. The notes of the groups that remain, and
  /// the examples and rules, stay as they are.
  LibraryDefinition removing(Iterable<String> names) {
    var removed = {...names}..remove(root);
    while (true) {
      final needed = {
        for (final component in components)
          if (!removed.contains(component.name))
            for (final prop in component.props) ...prop.type.neededComponents(removed),
      };
      final next = removed.difference(needed);
      if (next.length == removed.length) break;
      removed = next;
    }
    return _copy(
      components: [
        for (final component in components)
          if (!removed.contains(component.name)) component.mappingPropTypes((type) => type.removingComponents(removed)),
      ],
      componentGroups: [
        for (final group in componentGroups)
          if (group.components.where((name) => !removed.contains(name)).toList() case final kept when kept.isNotEmpty)
            ComponentGroup(group.name, components: kept, notes: group.notes),
      ],
    );
  }

  /// A copy of this library with `components` added wherever its own content
  /// goes.
  ///
  /// They join every prop that takes a union with `TextContent` in it, or a
  /// list of one, such as the children of a chat `Card`; when no prop does,
  /// the prompt lists them but no prop takes them.
  ///
  /// The system prompt lists them under `group`, followed by `notes`. A
  /// component is left out when its name can't be called in a program (see
  /// [isCallableName]) or is already a component, function or action of the
  /// library or an earlier one of `components`; with none left, this library
  /// is returned.
  LibraryDefinition addingContent(
    Iterable<ComponentSchema> components, {
    String group = 'App components',
    List<String> notes = const [],
  }) {
    final claim = componentNameClaim();
    final added = [
      for (final component in components)
        if (claim(component.name)) component,
    ];
    if (added.isEmpty) return this;
    final names = [for (final component in added) component.name];
    return _copy(
      components: [
        for (final component in this.components)
          component.mappingPropTypes((type) => type.addingContentComponents(names)),
        ...added,
      ],
      componentGroups: [
        ...componentGroups,
        ComponentGroup(group, components: names, notes: notes),
      ],
    );
  }

  LibraryDefinition _copy({required List<ComponentSchema> components, required List<ComponentGroup> componentGroups}) {
    return LibraryDefinition(
      root: root,
      components: components,
      componentGroups: componentGroups,
      defaultPromptOptions: defaultPromptOptions,
      functions: functions,
      actions: actions,
    );
  }
}
