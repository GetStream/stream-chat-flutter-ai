part of 'built_in_libraries.dart';

// The components only the standard library has, or has in its own form.
final ComponentSchema _standardCard = ComponentSchema(
  'Card',
  description:
      'Styled container. variant: "card" (default, elevated) | "sunk" (recessed) | "clear" '
      '(transparent). Always full width. Accepts all Stack flex params (default: direction "column"). '
      'Cards flex to share space in row/wrap layouts.',
  props: [
    required(
      'children',
      array(
        components([
          ..._baseContent,
          'Tabs',
          'Carousel',
          'Stack',
        ]),
      ),
    ),
    optional(
      'variant',
      enumeration([
        'card',
        'sunk',
        'clear',
      ]),
    ),
    optional('direction', enumeration(['row', 'column'])),
    optional(
      'gap',
      enumeration([
        'none',
        'xs',
        's',
        'm',
        'l',
        'xl',
        '2xl',
      ]),
    ),
    optional(
      'align',
      enumeration([
        'start',
        'center',
        'end',
        'stretch',
        'baseline',
      ]),
    ),
    optional(
      'justify',
      enumeration([
        'start',
        'center',
        'end',
        'between',
        'around',
        'evenly',
      ]),
    ),
    optional('wrap', boolean),
  ],
);
final ComponentSchema _standardStack = ComponentSchema(
  'Stack',
  description:
      'Flex container. direction: "row"|"column" (default "column"). gap: '
      '"none"|"xs"|"s"|"m"|"l"|"xl"|"2xl" (default "m"). align: '
      '"start"|"center"|"end"|"stretch"|"baseline". justify: '
      '"start"|"center"|"end"|"between"|"around"|"evenly".',
  props: [
    required('children', array(any)),
    optional('direction', enumeration(['row', 'column'])),
    optional(
      'gap',
      enumeration([
        'none',
        'xs',
        's',
        'm',
        'l',
        'xl',
        '2xl',
      ]),
    ),
    optional(
      'align',
      enumeration([
        'start',
        'center',
        'end',
        'stretch',
        'baseline',
      ]),
    ),
    optional(
      'justify',
      enumeration([
        'start',
        'center',
        'end',
        'between',
        'around',
        'evenly',
      ]),
    ),
    optional('wrap', boolean),
  ],
);
final ComponentSchema _standardTabItem = ComponentSchema(
  'TabItem',
  description: 'value is unique id, trigger is tab label, content is array of components',
  props: [
    required('value', string),
    required('trigger', string),
    required('content', array(components(_baseContent))),
  ],
);
final ComponentSchema _standardAccordionItem = ComponentSchema(
  'AccordionItem',
  description: 'value is unique id, trigger is section title',
  props: [
    required('value', string),
    required('trigger', string),
    required('content', array(components(_baseContent))),
  ],
);
final ComponentSchema _standardCarousel = ComponentSchema(
  'Carousel',
  description: 'Horizontal scrollable carousel',
  props: [
    required('children', array(array(components(_baseContent)))),
    optional('variant', enumeration(['card', 'sunk'])),
  ],
);
final ComponentSchema _standardModal = ComponentSchema(
  'Modal',
  description:
      r'Modal dialog. open is a reactive $boolean binding — set to true to open, X/Escape/backdrop '
      'auto-closes. Put Form with buttons inside children.',
  props: [
    required('title', string),
    binding('open', boolean),
    required('children', array(components(_baseContent))),
    optional(
      'size',
      enumeration([
        'sm',
        'md',
        'lg',
      ]),
    ),
  ],
);
