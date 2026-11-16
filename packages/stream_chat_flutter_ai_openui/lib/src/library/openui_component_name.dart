// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai_openui/src/library/openui_library.dart';

/// The name of a component of OpenUI's chat and standard libraries, such as
/// [card], to replace or remove its builder with [OpenUILibrary.replacing] and
/// [OpenUILibrary.removing].
///
/// A name is a [String], so those methods take either one of these constants
/// or the name written out:
///
/// ```dart
/// final library = OpenUILibrary.chat.replacing(OpenUIComponentName.card, buildBrandCard);
/// ```
///
/// Each constant names a component of at least one of the two libraries; see
/// [OpenUILibrary.types] for those of one library.
extension type const OpenUIComponentName._(String value) implements String {
  /// `Accordion`.
  static const accordion = OpenUIComponentName._('Accordion');

  /// `AccordionItem`.
  static const accordionItem = OpenUIComponentName._('AccordionItem');

  /// `AreaChart`.
  static const areaChart = OpenUIComponentName._('AreaChart');

  /// `BarChart`.
  static const barChart = OpenUIComponentName._('BarChart');

  /// `BoldText`.
  static const boldText = OpenUIComponentName._('BoldText');

  /// `Button`.
  static const button = OpenUIComponentName._('Button');

  /// `Buttons`.
  static const buttons = OpenUIComponentName._('Buttons');

  /// `Callout`.
  static const callout = OpenUIComponentName._('Callout');

  /// `Card`.
  static const card = OpenUIComponentName._('Card');

  /// `CardHeader`.
  static const cardHeader = OpenUIComponentName._('CardHeader');

  /// `Carousel`.
  static const carousel = OpenUIComponentName._('Carousel');

  /// `CheckBoxGroup`.
  static const checkBoxGroup = OpenUIComponentName._('CheckBoxGroup');

  /// `CheckBoxItem`.
  static const checkBoxItem = OpenUIComponentName._('CheckBoxItem');

  /// `ChipItem`.
  static const chipItem = OpenUIComponentName._('ChipItem');

  /// `Chips`.
  static const chips = OpenUIComponentName._('Chips');

  /// `CodeBlock`.
  static const codeBlock = OpenUIComponentName._('CodeBlock');

  /// `Col`.
  static const col = OpenUIComponentName._('Col');

  /// `CompositeCardBlock`.
  static const compositeCardBlock = OpenUIComponentName._('CompositeCardBlock');

  /// `CompositeCardItem`.
  static const compositeCardItem = OpenUIComponentName._('CompositeCardItem');

  /// `ContextCardBlock`.
  static const contextCardBlock = OpenUIComponentName._('ContextCardBlock');

  /// `ContextCardItem`.
  static const contextCardItem = OpenUIComponentName._('ContextCardItem');

  /// `DatePicker`.
  static const datePicker = OpenUIComponentName._('DatePicker');

  /// `EditableTable`.
  static const editableTable = OpenUIComponentName._('EditableTable');

  /// `EntityList`.
  static const entityList = OpenUIComponentName._('EntityList');

  /// `FollowUpBlock`.
  static const followUpBlock = OpenUIComponentName._('FollowUpBlock');

  /// `FollowUpItem`.
  static const followUpItem = OpenUIComponentName._('FollowUpItem');

  /// `Form`.
  static const form = OpenUIComponentName._('Form');

  /// `FormControl`.
  static const formControl = OpenUIComponentName._('FormControl');

  /// `HorizontalBarChart`.
  static const horizontalBarChart = OpenUIComponentName._('HorizontalBarChart');

  /// `Icon`.
  static const icon = OpenUIComponentName._('Icon');

  /// `IconButton`.
  static const iconButton = OpenUIComponentName._('IconButton');

  /// `IconText`.
  static const iconText = OpenUIComponentName._('IconText');

  /// `Image`.
  static const image = OpenUIComponentName._('Image');

  /// `ImageBlock`.
  static const imageBlock = OpenUIComponentName._('ImageBlock');

  /// `ImageGallery`.
  static const imageGallery = OpenUIComponentName._('ImageGallery');

  /// `ImageText`.
  static const imageText = OpenUIComponentName._('ImageText');

  /// `ImageTextLarge`.
  static const imageTextLarge = OpenUIComponentName._('ImageTextLarge');

  /// `InlineHeader`.
  static const inlineHeader = OpenUIComponentName._('InlineHeader');

  /// `Input`.
  static const input = OpenUIComponentName._('Input');

  /// `Label`.
  static const label = OpenUIComponentName._('Label');

  /// `LineChart`.
  static const lineChart = OpenUIComponentName._('LineChart');

  /// `ListBlock`.
  static const listBlock = OpenUIComponentName._('ListBlock');

  /// `ListItem`.
  static const listItem = OpenUIComponentName._('ListItem');

  /// `MarkDownRenderer`.
  static const markDownRenderer = OpenUIComponentName._('MarkDownRenderer');

  /// `MetricIndicatorInline`.
  static const metricIndicatorInline = OpenUIComponentName._('MetricIndicatorInline');

  /// `MetricIndicatorWithStrikethrough`.
  static const metricIndicatorWithStrikethrough = OpenUIComponentName._('MetricIndicatorWithStrikethrough');

  /// `Modal`.
  static const modal = OpenUIComponentName._('Modal');

  /// `OptionCard`.
  static const optionCard = OpenUIComponentName._('OptionCard');

  /// `OptionCards`.
  static const optionCards = OpenUIComponentName._('OptionCards');

  /// `OverviewCardBlock`.
  static const overviewCardBlock = OpenUIComponentName._('OverviewCardBlock');

  /// `OverviewCardItem`.
  static const overviewCardItem = OpenUIComponentName._('OverviewCardItem');

  /// `PieChart`.
  static const pieChart = OpenUIComponentName._('PieChart');

  /// `Point`.
  static const point = OpenUIComponentName._('Point');

  /// `RadarChart`.
  static const radarChart = OpenUIComponentName._('RadarChart');

  /// `RadialChart`.
  static const radialChart = OpenUIComponentName._('RadialChart');

  /// `RadioGroup`.
  static const radioGroup = OpenUIComponentName._('RadioGroup');

  /// `RadioItem`.
  static const radioItem = OpenUIComponentName._('RadioItem');

  /// `ScatterChart`.
  static const scatterChart = OpenUIComponentName._('ScatterChart');

  /// `ScatterSeries`.
  static const scatterSeries = OpenUIComponentName._('ScatterSeries');

  /// `SectionBlock`.
  static const sectionBlock = OpenUIComponentName._('SectionBlock');

  /// `SectionItem`.
  static const sectionItem = OpenUIComponentName._('SectionItem');

  /// `Select`.
  static const select = OpenUIComponentName._('Select');

  /// `SelectItem`.
  static const selectItem = OpenUIComponentName._('SelectItem');

  /// `Separator`.
  static const separator = OpenUIComponentName._('Separator');

  /// `Series`.
  static const series = OpenUIComponentName._('Series');

  /// `SingleStackedBarChart`.
  static const singleStackedBarChart = OpenUIComponentName._('SingleStackedBarChart');

  /// `Slice`.
  static const slice = OpenUIComponentName._('Slice');

  /// `Slider`.
  static const slider = OpenUIComponentName._('Slider');

  /// `SnippetCardBlock`.
  static const snippetCardBlock = OpenUIComponentName._('SnippetCardBlock');

  /// `SnippetCardItem`.
  static const snippetCardItem = OpenUIComponentName._('SnippetCardItem');

  /// `Stack`.
  static const stack = OpenUIComponentName._('Stack');

  /// `Steps`.
  static const steps = OpenUIComponentName._('Steps');

  /// `StepsItem`.
  static const stepsItem = OpenUIComponentName._('StepsItem');

  /// `SwitchGroup`.
  static const switchGroup = OpenUIComponentName._('SwitchGroup');

  /// `SwitchItem`.
  static const switchItem = OpenUIComponentName._('SwitchItem');

  /// `TabItem`.
  static const tabItem = OpenUIComponentName._('TabItem');

  /// `Table`.
  static const table = OpenUIComponentName._('Table');

  /// `Tabs`.
  static const tabs = OpenUIComponentName._('Tabs');

  /// `Tag`.
  static const tag = OpenUIComponentName._('Tag');

  /// `TagBlock`.
  static const tagBlock = OpenUIComponentName._('TagBlock');

  /// `Text`.
  static const text = OpenUIComponentName._('Text');

  /// `TextArea`.
  static const textArea = OpenUIComponentName._('TextArea');

  /// `TextCallout`.
  static const textCallout = OpenUIComponentName._('TextCallout');

  /// `TextContent`.
  static const textContent = OpenUIComponentName._('TextContent');

  /// `VisualCardBlock`.
  static const visualCardBlock = OpenUIComponentName._('VisualCardBlock');

  /// `VisualCardItem`.
  static const visualCardItem = OpenUIComponentName._('VisualCardItem');
}
