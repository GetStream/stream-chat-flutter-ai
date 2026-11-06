part of 'built_in_libraries.dart';

// The components only the chat library has, or has in its own form.
final ComponentSchema _chatCard = ComponentSchema(
  'Card',
  description:
      'Vertical container for all content in a chat response. Children stack top to bottom '
      'automatically. Optional sources ([{ title, sourceName, url }]) render as a Sources strip at the '
      'bottom and back inline [n] citations in TextContent.',
  props: [
    required(
      'children',
      array(
        components([
          ..._chatNestedContent,
          'SectionBlock',
          'Tabs',
          'Carousel',
        ]),
      ),
    ),
    optional(
      'sources',
      array(
        object([
          optional('url', string),
          required('title', string),
          required('sourceName', string),
        ]),
      ),
    ),
  ],
);
final ComponentSchema _chatFollowUpBlock = ComponentSchema(
  'FollowUpBlock',
  description: 'List of clickable follow-up suggestions placed at the end of a response',
  props: [required('items', array(component('FollowUpItem')))],
);
final ComponentSchema _chatFollowUpItem = ComponentSchema(
  'FollowUpItem',
  description: 'Clickable follow-up suggestion — when clicked, sends text as user message',
  props: [required('text', string)],
);
final ComponentSchema _chatSectionBlock = ComponentSchema(
  'SectionBlock',
  description:
      'Collapsible accordion sections. Auto-opens sections as they stream in. Use SectionItem for each '
      'section.',
  props: [required('sections', array(component('SectionItem'))), optional('isFoldable', boolean)],
);
final ComponentSchema _chatSectionItem = ComponentSchema(
  'SectionItem',
  description: 'Section with a label and collapsible content — used inside SectionBlock',
  props: [
    required('value', string),
    required('trigger', string),
    required(
      'content',
      array(
        components([
          ..._chatNestedContent,
          'Tabs',
          'Accordion',
        ]),
      ),
    ),
  ],
);
final ComponentSchema _chatTabItem = ComponentSchema(
  'TabItem',
  description: 'value is unique id, trigger is tab label, content is array of components',
  props: [
    required('value', string),
    required('trigger', string),
    required('content', array(components([..._chatNestedContent, 'Accordion']))),
  ],
);
final ComponentSchema _chatAccordionItem = ComponentSchema(
  'AccordionItem',
  description: 'value is unique id, trigger is section title',
  props: [
    required('value', string),
    required('trigger', string),
    required('content', array(components(_chatNestedContent))),
  ],
);
final ComponentSchema _chatCarousel = ComponentSchema(
  'Carousel',
  description: 'Horizontal scrollable carousel',
  props: [
    required('children', array(array(components(_chatNestedContent)))),
    optional('variant', enumeration(['card', 'sunk'])),
  ],
);
