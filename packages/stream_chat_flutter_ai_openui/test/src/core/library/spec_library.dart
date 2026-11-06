import 'package:stream_chat_flutter_ai_openui/src/core/library/component_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/library/library_definition.dart';
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
