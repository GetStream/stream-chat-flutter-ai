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
extension type const OpenUIComponentName(String value) implements String {
  /// `Accordion`.
  static const accordion = OpenUIComponentName('Accordion');

  /// `AccordionItem`.
  static const accordionItem = OpenUIComponentName('AccordionItem');

  /// `AreaChart`.
  static const areaChart = OpenUIComponentName('AreaChart');

  /// `BarChart`.
  static const barChart = OpenUIComponentName('BarChart');

  /// `BoldText`.
  static const boldText = OpenUIComponentName('BoldText');

  /// `Button`.
  static const button = OpenUIComponentName('Button');

  /// `Buttons`.
  static const buttons = OpenUIComponentName('Buttons');

  /// `Callout`.
  static const callout = OpenUIComponentName('Callout');

  /// `Card`.
  static const card = OpenUIComponentName('Card');

  /// `CardHeader`.
  static const cardHeader = OpenUIComponentName('CardHeader');

  /// `Carousel`.
  static const carousel = OpenUIComponentName('Carousel');

  /// `CheckBoxGroup`.
  static const checkBoxGroup = OpenUIComponentName('CheckBoxGroup');

  /// `CheckBoxItem`.
  static const checkBoxItem = OpenUIComponentName('CheckBoxItem');

  /// `ChipItem`.
  static const chipItem = OpenUIComponentName('ChipItem');

  /// `Chips`.
  static const chips = OpenUIComponentName('Chips');

  /// `CodeBlock`.
  static const codeBlock = OpenUIComponentName('CodeBlock');

  /// `Col`.
  static const col = OpenUIComponentName('Col');

  /// `CompositeCardBlock`.
  static const compositeCardBlock = OpenUIComponentName('CompositeCardBlock');

  /// `CompositeCardItem`.
  static const compositeCardItem = OpenUIComponentName('CompositeCardItem');

  /// `ContextCardBlock`.
  static const contextCardBlock = OpenUIComponentName('ContextCardBlock');

  /// `ContextCardItem`.
  static const contextCardItem = OpenUIComponentName('ContextCardItem');

  /// `DatePicker`.
  static const datePicker = OpenUIComponentName('DatePicker');

  /// `EditableTable`.
  static const editableTable = OpenUIComponentName('EditableTable');

  /// `EntityList`.
  static const entityList = OpenUIComponentName('EntityList');

  /// `FollowUpBlock`.
  static const followUpBlock = OpenUIComponentName('FollowUpBlock');

  /// `FollowUpItem`.
  static const followUpItem = OpenUIComponentName('FollowUpItem');

  /// `Form`.
  static const form = OpenUIComponentName('Form');

  /// `FormControl`.
  static const formControl = OpenUIComponentName('FormControl');

  /// `HorizontalBarChart`.
  static const horizontalBarChart = OpenUIComponentName('HorizontalBarChart');

  /// `Icon`.
  static const icon = OpenUIComponentName('Icon');

  /// `IconButton`.
  static const iconButton = OpenUIComponentName('IconButton');

  /// `IconText`.
  static const iconText = OpenUIComponentName('IconText');

  /// `Image`.
  static const image = OpenUIComponentName('Image');

  /// `ImageBlock`.
  static const imageBlock = OpenUIComponentName('ImageBlock');

  /// `ImageGallery`.
  static const imageGallery = OpenUIComponentName('ImageGallery');

  /// `ImageText`.
  static const imageText = OpenUIComponentName('ImageText');

  /// `ImageTextLarge`.
  static const imageTextLarge = OpenUIComponentName('ImageTextLarge');

  /// `InlineHeader`.
  static const inlineHeader = OpenUIComponentName('InlineHeader');

  /// `Input`.
  static const input = OpenUIComponentName('Input');

  /// `Label`.
  static const label = OpenUIComponentName('Label');

  /// `LineChart`.
  static const lineChart = OpenUIComponentName('LineChart');

  /// `ListBlock`.
  static const listBlock = OpenUIComponentName('ListBlock');

  /// `ListItem`.
  static const listItem = OpenUIComponentName('ListItem');

  /// `MarkDownRenderer`.
  static const markDownRenderer = OpenUIComponentName('MarkDownRenderer');

  /// `MetricIndicatorInline`.
  static const metricIndicatorInline = OpenUIComponentName('MetricIndicatorInline');

  /// `MetricIndicatorWithStrikethrough`.
  static const metricIndicatorWithStrikethrough = OpenUIComponentName('MetricIndicatorWithStrikethrough');

  /// `Modal`.
  static const modal = OpenUIComponentName('Modal');

  /// `OptionCard`.
  static const optionCard = OpenUIComponentName('OptionCard');

  /// `OptionCards`.
  static const optionCards = OpenUIComponentName('OptionCards');

  /// `OverviewCardBlock`.
  static const overviewCardBlock = OpenUIComponentName('OverviewCardBlock');

  /// `OverviewCardItem`.
  static const overviewCardItem = OpenUIComponentName('OverviewCardItem');

  /// `PieChart`.
  static const pieChart = OpenUIComponentName('PieChart');

  /// `Point`.
  static const point = OpenUIComponentName('Point');

  /// `RadarChart`.
  static const radarChart = OpenUIComponentName('RadarChart');

  /// `RadialChart`.
  static const radialChart = OpenUIComponentName('RadialChart');

  /// `RadioGroup`.
  static const radioGroup = OpenUIComponentName('RadioGroup');

  /// `RadioItem`.
  static const radioItem = OpenUIComponentName('RadioItem');

  /// `ScatterChart`.
  static const scatterChart = OpenUIComponentName('ScatterChart');

  /// `ScatterSeries`.
  static const scatterSeries = OpenUIComponentName('ScatterSeries');

  /// `SectionBlock`.
  static const sectionBlock = OpenUIComponentName('SectionBlock');

  /// `SectionItem`.
  static const sectionItem = OpenUIComponentName('SectionItem');

  /// `Select`.
  static const select = OpenUIComponentName('Select');

  /// `SelectItem`.
  static const selectItem = OpenUIComponentName('SelectItem');

  /// `Separator`.
  static const separator = OpenUIComponentName('Separator');

  /// `Series`.
  static const series = OpenUIComponentName('Series');

  /// `SingleStackedBarChart`.
  static const singleStackedBarChart = OpenUIComponentName('SingleStackedBarChart');

  /// `Slice`.
  static const slice = OpenUIComponentName('Slice');

  /// `Slider`.
  static const slider = OpenUIComponentName('Slider');

  /// `SnippetCardBlock`.
  static const snippetCardBlock = OpenUIComponentName('SnippetCardBlock');

  /// `SnippetCardItem`.
  static const snippetCardItem = OpenUIComponentName('SnippetCardItem');

  /// `Stack`.
  static const stack = OpenUIComponentName('Stack');

  /// `Steps`.
  static const steps = OpenUIComponentName('Steps');

  /// `StepsItem`.
  static const stepsItem = OpenUIComponentName('StepsItem');

  /// `SwitchGroup`.
  static const switchGroup = OpenUIComponentName('SwitchGroup');

  /// `SwitchItem`.
  static const switchItem = OpenUIComponentName('SwitchItem');

  /// `TabItem`.
  static const tabItem = OpenUIComponentName('TabItem');

  /// `Table`.
  static const table = OpenUIComponentName('Table');

  /// `Tabs`.
  static const tabs = OpenUIComponentName('Tabs');

  /// `Tag`.
  static const tag = OpenUIComponentName('Tag');

  /// `TagBlock`.
  static const tagBlock = OpenUIComponentName('TagBlock');

  /// `Text`.
  static const text = OpenUIComponentName('Text');

  /// `TextArea`.
  static const textArea = OpenUIComponentName('TextArea');

  /// `TextCallout`.
  static const textCallout = OpenUIComponentName('TextCallout');

  /// `TextContent`.
  static const textContent = OpenUIComponentName('TextContent');

  /// `VisualCardBlock`.
  static const visualCardBlock = OpenUIComponentName('VisualCardBlock');

  /// `VisualCardItem`.
  static const visualCardItem = OpenUIComponentName('VisualCardItem');
}
