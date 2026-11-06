/// The libraries a model writes OpenUI Lang programs with, and the
/// instructions that teach it to.
///
/// One of the core's boundary files: code outside `lib/src/core/` may import
/// it.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/portable_component.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart';

export 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart' show ComponentSchema;
export 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart' show LibraryDefinition;
export 'package:stream_chat_flutter_ai_openui/src/core/library/prompt_options.dart' show HostTool;

/// The components of `definitions`, an app's component definitions as
/// `jsonDecode` gives them, that can join `library`, each with the index of
/// its definition.
///
/// A definition is left out when it can't be read (see
/// [portableComponentSchema]), when the name a program would call it by can't
/// be called (see [LibraryDefinition.isCallableName]), or when that name is
/// already a component, function or action of `library` or an earlier
/// definition's.
List<(int, ComponentSchema)> placeableComponents(LibraryDefinition library, List<Map<String, Object?>> definitions) {
  final taken = {
    ...library.componentNames,
    for (final function in library.functions) function.name,
    for (final action in library.actions) action.name,
  };
  final placeable = <(int, ComponentSchema)>[];
  for (final (index, definition) in definitions.indexed) {
    final ComponentSchema schema;
    try {
      schema = portableComponentSchema(definition);
    } on FormatException {
      continue;
    }
    if (LibraryDefinition.isCallableName(schema.name) && taken.add(schema.name)) placeable.add((index, schema));
  }
  return placeable;
}

/// The instructions a model needs to answer with programs written with
/// `library`.
///
/// They are `appInstructions`, when it isn't blank, a blank line, and the
/// system prompt of `library` with `components` added as content (see
/// [LibraryDefinition.addingContent]) and `tools` listed, each saying whether
/// a `Query()` may run it. The prompt has the library's own examples and
/// rules.
String openUIInstructions(
  LibraryDefinition library, {
  String? appInstructions,
  Iterable<ComponentSchema> components = const [],
  Iterable<HostTool> tools = const [],
}) {
  final options = library.defaultPromptOptions;
  final prompt = library
      .addingContent(components)
      .systemPrompt(options.copyWith(tools: [...options.tools, for (final tool in tools) tool.toToolSpec()]));
  if (appInstructions == null || appInstructions.trim().isEmpty) return prompt;
  return '$appInstructions\n\n$prompt';
}
