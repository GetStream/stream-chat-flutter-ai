// ignore_for_file: no_adjacent_strings_in_list

part of 'built_in_libraries.dart';

/// The component a standard program's root is.
const String standardRoot = 'Stack';

/// The components of the standard library, in library order.
final List<ComponentSchema> standardComponents = [
  _standardCard,
  _cardHeader,
  _textContent,
  _markDownRenderer,
  _callout,
  _textCallout,
  _image,
  _imageBlock,
  _imageGallery,
  _codeBlock,
  _inlineHeader,
  _table,
  _col,
  _editableTable,
  _barChart,
  _lineChart,
  _areaChart,
  _radarChart,
  _horizontalBarChart,
  _series,
  _pieChart,
  _radialChart,
  _singleStackedBarChart,
  _slice,
  _scatterChart,
  _scatterSeries,
  _point,
  _form,
  _formControl,
  _label,
  _input,
  _textArea,
  _select,
  _selectItem,
  _datePicker,
  _slider,
  _checkBoxGroup,
  _checkBoxItem,
  _radioGroup,
  _radioItem,
  _switchGroup,
  _switchItem,
  _chipItem,
  _chips,
  _optionCard,
  _optionCards,
  _button,
  _buttons,
  _iconButton,
  _standardStack,
  _tabs,
  _standardTabItem,
  _accordion,
  _standardAccordionItem,
  _steps,
  _stepsItem,
  _standardCarousel,
  _separator,
  _tagBlock,
  _tag,
  _icon,
  _entityList,
  _listBlock,
  _listItem,
  _text,
  _boldText,
  _iconText,
  _imageText,
  _imageTextLarge,
  _metricIndicatorInline,
  _metricIndicatorWithStrikethrough,
  _snippetCardItem,
  _snippetCardBlock,
  _overviewCardItem,
  _overviewCardBlock,
  _contextCardItem,
  _contextCardBlock,
  _compositeCardItem,
  _compositeCardBlock,
  _visualCardItem,
  _visualCardBlock,
  _standardModal,
];

/// How the system prompt groups the standard library's components.
final List<ComponentGroup> standardComponentGroups = [
  const ComponentGroup(
    'Layout',
    components: [
      'Stack',
      'Tabs',
      'TabItem',
      'Accordion',
      'AccordionItem',
      'Steps',
      'StepsItem',
      'Carousel',
      'Separator',
      'Modal',
    ],
    notes: [
      '- For grid-like layouts, use Stack with direction "row" and wrap set to true.',
      '- Prefer justify "start" (or omit justify) with wrap=true for stable columns instead of uneven '
          'gutters.',
      '- Use nested Stacks when you need explicit rows/sections.',
      r'- Show/hide sections: $editId != "" ? Card([editForm]) : null',
      r'- Modal: Modal("Title", $showModal, [content]) — $showModal is boolean, X/Escape auto-closes. '
          'Put Form with its own buttons inside children.',
      r'- Use Tabs for alternative views (chart types, data sections) — no $variable needed',
      r'- Shared filter across Tabs: same $days binding in Query args works across all TabItems',
    ],
  ),
  const ComponentGroup(
    'Content',
    components: [
      'Card',
      'CardHeader',
      'TextContent',
      'MarkDownRenderer',
      'Callout',
      'TextCallout',
      'Image',
      'ImageBlock',
      'ImageGallery',
      'CodeBlock',
      'InlineHeader',
    ],
    notes: [
      '- InlineHeader is a compact heading + description pair for labelling a block (lighter than '
          'CardHeader).',
      '- Use Cards to group related KPIs or sections. Stack with direction "row" for side-by-side '
          'layouts.',
      r'- Success toast: Callout("success", "Saved", "Done.", $showSuccess) — use @Set($showSuccess, '
          'true) in save action, auto-dismisses after 3s. For errors: result.status == "error" ? '
          'Callout("error", "Failed", result.error) : null',
      '- KPI card: Card([TextContent("Label", "small"), TextContent("" + @Count(@Filter(data.rows, '
          '"field", "==", "value")), "large-heavy")])',
    ],
  ),
  const ComponentGroup(
    'Tables',
    components: [
      'Table',
      'Col',
      'EditableTable',
    ],
    notes: [
      '- EditableTable lets the user edit cells inline. Give it a unique name, columns of { type, key, '
          'header } with type one of text | number | date-single | select | url (select also needs '
          'options: [{ value, label }]).',
      '- data is an array of { id, values } rows where values are ordered positionally to match '
          'columns. Edited data is submitted when the user clicks Save Changes.',
      '- Table is COLUMN-oriented: Table([Col("Label", dataArray), Col("Count", countArray, '
          '"number")]). Use array pluck for data: data.rows.fieldName',
      '- Col data can be component arrays for styled cells: Col("Status", @Each(data.rows, "item", '
          'Tag(item.status, null, "sm", item.status == "open" ? "success" : "danger")))',
      r'- Row actions: Col("Actions", @Each(data.rows, "t", Button("Edit", Action([@Set($showEdit, '
          r'true), @Set($editId, t.id)]))))',
      r'- Sortable: sorted = @Sort(data.rows, $sortField, "desc"). Bind $sortField to Select. Use '
          'sorted.fieldName for Col data',
      r'- Searchable: filtered = @Filter(data.rows, "title", "contains", $search). Bind $search to Input',
      '- Chain sort + filter: filtered = @Filter(...) then sorted = @Sort(filtered, ...) — use sorted '
          'for both Table and Charts',
      '- Empty state: @Count(data.rows) > 0 ? Table([...]) : TextContent("No data yet")',
    ],
  ),
  const ComponentGroup(
    'Charts (2D)',
    components: [
      'BarChart',
      'LineChart',
      'AreaChart',
      'RadarChart',
      'HorizontalBarChart',
      'Series',
    ],
    notes: [
      '- Charts accept column arrays: LineChart(labels, [Series("Name", values)]). Use array pluck: '
          'LineChart(data.rows.day, [Series("Views", data.rows.views)])',
      '- Use Cards to wrap charts with CardHeader for titled sections',
      '- Chart + Table from same source: use @Sort or @Filter result for both LineChart and Table Col '
          'data',
      '- Multiple chart views: use Tabs — Tabs([TabItem("line", "Line", [LineChart(...)]), '
          'TabItem("bar", "Bar", [BarChart(...)])])',
    ],
  ),
  const ComponentGroup(
    'Charts (1D)',
    components: [
      'PieChart',
      'RadialChart',
      'SingleStackedBarChart',
      'Slice',
    ],
    notes: [
      '- PieChart and BarChart need NUMBERS, not objects. For list data, use @Count(@Filter(...)) to '
          'aggregate:',
      '- PieChart from list: `PieChart(["Low", "Med", "High"], [@Count(@Filter(data.rows, "priority", '
          '"==", "low")), @Count(@Filter(data.rows, "priority", "==", "medium")), '
          '@Count(@Filter(data.rows, "priority", "==", "high"))], "donut")`',
      '- KPI from count: `TextContent("" + @Count(@Filter(data.rows, "status", "==", "open")), '
          '"large-heavy")`',
    ],
  ),
  const ComponentGroup(
    'Charts (Scatter)',
    components: [
      'ScatterChart',
      'ScatterSeries',
      'Point',
    ],
  ),
  const ComponentGroup(
    'Forms',
    components: [
      'Form',
      'FormControl',
      'Label',
      'Input',
      'TextArea',
      'Select',
      'SelectItem',
      'DatePicker',
      'Slider',
      'CheckBoxGroup',
      'CheckBoxItem',
      'RadioGroup',
      'RadioItem',
      'SwitchGroup',
      'SwitchItem',
      'Chips',
      'ChipItem',
      'OptionCards',
      'OptionCard',
    ],
    notes: [
      '- Chips: compact single/multiple selection pills. Use ChipItem references for each option.',
      '- OptionCards: larger selectable cards with title, subtitle and an optional Icon or Image on '
          'top. Use OptionCard references for each option.',
      '- For Form fields, define EACH FormControl as its own reference — do NOT inline all controls in '
          'one array. This allows progressive field-by-field streaming.',
      '- NEVER nest Form inside Form — each Form should be a standalone container.',
      '- Form requires explicit buttons. Always pass a Buttons(...) reference as the third Form '
          'argument.',
      '- rules is an optional object: {required: true, email: true, minLength: 8, maxLength: 100}',
      '- Available rules: required, email, min, max, minLength, maxLength, pattern, url, numeric',
      '- The renderer shows error messages automatically — do NOT generate error text in the UI',
      r'- Conditional fields: $country == "US" ? stateField : $country == "UK" ? postcodeField : '
          'addressField',
      r'- Edit form in Modal: Modal("Edit", $showEdit, [Form("edit", Buttons([saveBtn, cancelBtn]), '
          r'[fields...])]). Save button should include @Set($showEdit, false) to close modal.',
    ],
  ),
  const ComponentGroup(
    'Buttons',
    components: [
      'Button',
      'Buttons',
      'IconButton',
    ],
    notes: [
      '- Icon renders a lucide icon by kebab-case name; it is also used as the icon of IconButton, '
          'IconText and OptionCard.',
      '- Toggle in @Each: @Each(rows, "t", Button(t.status == "open" ? "Close" : "Reopen", '
          'Action([...])))',
    ],
  ),
  const ComponentGroup(
    'Data Display',
    components: [
      'TagBlock',
      'Tag',
      'Icon',
      'EntityList',
      'ListBlock',
      'ListItem',
    ],
    notes: [
      '- Color-mapped Tag: Tag(value, null, "sm", value == "high" ? "danger" : value == "medium" ? '
          '"warning" : "neutral")',
      '- EntityList is a compact two-column list of { left, right } rows (e.g. name / value). '
          "size='default' also supports a header and footer row; size='small' does not.",
      '- ListBlock is a numbered or image list of ListItem references. An action on ListItem is '
          'optional.',
    ],
  ),
  const ComponentGroup(
    'Cards',
    components: [
      'SnippetCardBlock',
      'SnippetCardItem',
      'OverviewCardBlock',
      'OverviewCardItem',
      'ContextCardBlock',
      'ContextCardItem',
      'CompositeCardBlock',
      'CompositeCardItem',
      'VisualCardBlock',
      'VisualCardItem',
      'Text',
      'BoldText',
      'IconText',
      'ImageText',
      'ImageTextLarge',
      'MetricIndicatorInline',
      'MetricIndicatorWithStrikethrough',
    ],
    notes: [
      '- Card blocks lay out 2+ items in a responsive grid (or carousel where supported). Every item '
          'in a block must have the same structure.',
      '- SnippetCardItem: small card with lhs (IconText | ImageText) and optional rhs (Text | '
          'BoldText) — good for key/value facts.',
      '- OverviewCardItem: small card with top (IconText | ImageText | Text) and optional bottom '
          'MetricIndicatorInline — good for KPIs.',
      '- ContextCardItem: medium card with a title (string or Tag), body text and optional background '
          'image — good for summaries.',
      '- CompositeCardItem: rich card with header, body array (Text, BoldText, MetricIndicatorInline, '
          'IconText, Image, charts, ListBlock, TagBlock, EntityList) and footer (price + Button) — good '
          'for products/offers.',
      '- VisualCardItem: image-first card with a BoldText body and optional Tag.',
      '- Text / BoldText / IconText / ImageText / ImageTextLarge / MetricIndicator* are the inline '
          'building blocks used INSIDE card items; do not place them directly in the root Card.',
    ],
  ),
];

/// The example programs the standard library's system prompt shows.
final List<String> standardExamples = [
  'Example 1 — Table (column-oriented):\n'
      '\n'
      'root = Stack([title, tbl])\n'
      'title = TextContent("Top Languages", "large-heavy")\n'
      'tbl = Table([Col("Language", langs), Col("Users (M)", users), Col("Year", years)])\n'
      'langs = ["Python", "JavaScript", "Java", "TypeScript", "Go"]\n'
      'users = [15.7, 14.2, 12.1, 8.5, 5.2]\n'
      'years = [1991, 1995, 1995, 2012, 2009]',
  'Example 2 — Bar chart:\n'
      '\n'
      'root = Stack([title, chart])\n'
      'title = TextContent("Q4 Revenue", "large-heavy")\n'
      'chart = BarChart(labels, [s1, s2], "grouped")\n'
      'labels = ["Oct", "Nov", "Dec"]\n'
      's1 = Series("Product A", [120, 150, 180])\n'
      's2 = Series("Product B", [90, 110, 140])',
  'Example 3 — Form with validation:\n'
      '\n'
      'root = Stack([title, form])\n'
      'title = TextContent("Contact Us", "large-heavy")\n'
      'form = Form("contact", btns, [nameField, emailField, countryField, msgField])\n'
      'nameField = FormControl("Name", Input("name", "Your name", "text", { required: true, minLength: '
      '2 }))\n'
      'emailField = FormControl("Email", Input("email", "you@example.com", "email", { required: true, '
      'email: true }))\n'
      'countryField = FormControl("Country", Select("country", countryOpts, "Select...", { required: '
      'true }))\n'
      'msgField = FormControl("Message", TextArea("message", "Tell us more...", 4, { required: true, '
      'minLength: 10 }))\n'
      'countryOpts = [SelectItem("us", "United States"), SelectItem("uk", "United Kingdom"), '
      'SelectItem("de", "Germany")]\n'
      'btns = Buttons([Button("Submit", @ToAssistant("Submit"), "primary"), Button("Cancel", '
      '@ToAssistant("Cancel"), "secondary")])',
  'Example 4 — Tabs with mixed content:\n'
      '\n'
      'root = Stack([title, tabs])\n'
      'title = TextContent("React vs Vue", "large-heavy")\n'
      'tabs = Tabs([tabReact, tabVue])\n'
      'tabReact = TabItem("react", "React", reactContent)\n'
      'tabVue = TabItem("vue", "Vue", vueContent)\n'
      'reactContent = [TextContent("React is a library by Meta for building UIs."), Callout("info", '
      '"Note", "React uses JSX syntax.")]\n'
      'vueContent = [TextContent("Vue is a progressive framework by Evan You."), Callout("success", '
      '"Tip", "Vue has a gentle learning curve.")]',
  'Example 5 — KPI and product cards:\n'
      '\n'
      'root = Stack([kpiHeader, kpiBlock, productsHeader, productCards])\n'
      'kpiHeader = InlineHeader("This Month", "Key account metrics")\n'
      'kpiBlock = SnippetCardBlock([kpi1, kpi2, kpi3])\n'
      'kpi1 = SnippetCardItem("revenue", kpi1lhs, kpi1rhs)\n'
      'kpi1lhs = IconText(kpi1icon, "neutral", "m", "Revenue", "Month to date", false, "horizontal")\n'
      'kpi1icon = Icon("circle-dollar-sign", "finance")\n'
      'kpi1rhs = BoldText("number", "\$48,200", "+8.1%", "metric")\n'
      'kpi2 = SnippetCardItem("active-users", kpi2lhs, kpi2rhs)\n'
      'kpi2lhs = IconText(kpi2icon, "neutral", "m", "Active Users", "This month", false, "horizontal")\n'
      'kpi2icon = Icon("users", "people")\n'
      'kpi2rhs = BoldText("number", "1,204", "+3.4%", "metric")\n'
      'kpi3 = SnippetCardItem("churn", kpi3lhs, kpi3rhs)\n'
      'kpi3lhs = IconText(kpi3icon, "neutral", "m", "Churn", "This month", false, "horizontal")\n'
      'kpi3icon = Icon("user-minus", "people")\n'
      'kpi3rhs = BoldText("number", "1.8%", "-0.3%", "metric")\n'
      'productsHeader = InlineHeader("Top Products", "By units sold")\n'
      'productCards = CompositeCardBlock([p1, p2])\n'
      'p1 = CompositeCardItem("widget-pro", p1header, [p1body], p1footer)\n'
      'p1header = IconText(p1icon, "neutral", "m", "Widget Pro", "Best seller", true, "horizontal")\n'
      'p1icon = Icon("package", "shopping")\n'
      'p1body = MetricIndicatorInline("2,410 units", "Sold this month", { direction: "up", value: 12 '
      '})\n'
      'p1footer = { price: BoldText("text", "\$29.00"), button: p1btn }\n'
      'p1btn = Button("View Details", @ToAssistant("Show details for Widget Pro"), "secondary")\n'
      'p2 = CompositeCardItem("widget-mini", p2header, [p2body], p2footer)\n'
      'p2header = IconText(p2icon, "neutral", "m", "Widget Mini", "New arrival", true, "horizontal")\n'
      'p2icon = Icon("box", "shopping")\n'
      'p2body = MetricIndicatorInline("980 units", "Sold this month", { direction: "up", value: 4 })\n'
      'p2footer = { price: BoldText("text", "\$14.00"), button: p2btn }\n'
      'p2btn = Button("View Details", @ToAssistant("Show details for Widget Mini"), "secondary")',
  'Example 6 — Editable table and a selection form:\n'
      '\n'
      'root = Stack([tableHeader, editTable, formHeader, prefsForm])\n'
      'tableHeader = InlineHeader("Team Roster", "Click a cell to edit")\n'
      'editTable = EditableTable("roster", [colName, colRole, colStart], [row1, row2])\n'
      'colName = { type: "text", key: "name", header: "Name" }\n'
      'colRole = { type: "select", key: "role", header: "Role", options: [roleEng, roleDesign] }\n'
      'roleEng = { value: "eng", label: "Engineering" }\n'
      'roleDesign = { value: "design", label: "Design" }\n'
      'colStart = { type: "date-single", key: "start", header: "Start Date" }\n'
      'row1 = { id: "1", values: ["Alex Kim", "eng", "2024-01-15"] }\n'
      'row2 = { id: "2", values: ["Jamie Lee", "design", "2024-03-02"] }\n'
      'formHeader = InlineHeader("Preferences", "Tell us how you like to work")\n'
      'prefsForm = Form("prefs", formButtons, [fc1, fc2])\n'
      'fc1 = FormControl("Working Style", styleCards, "Pick the one that fits best")\n'
      'styleCards = OptionCards("style", "single", [style1, style2])\n'
      'style1 = OptionCard("focused", "Deep Focus", "Long uninterrupted blocks", style1icon)\n'
      'style1icon = Icon("target", "tools")\n'
      'style2 = OptionCard("collab", "Collaborative", "Frequent pairing and syncs", style2icon)\n'
      'style2icon = Icon("users", "people")\n'
      'fc2 = FormControl("Tools", toolChips, "Select all that apply")\n'
      'toolChips = Chips("tools", "multiple", [tool1, tool2, tool3])\n'
      'tool1 = ChipItem("figma", "Figma", tool1icon)\n'
      'tool1icon = Icon("figma", "design")\n'
      'tool2 = ChipItem("slack", "Slack", tool2icon)\n'
      'tool2icon = Icon("message-square", "communication")\n'
      'tool3 = ChipItem("notion", "Notion", tool3icon)\n'
      'tool3icon = Icon("notebook", "text")\n'
      'formButtons = Buttons([Button("Save", @ToAssistant("Save preferences"), "primary")])',
];

/// The rules the standard library's system prompt ends with.
final List<String> standardAdditionalRules = [
  'When asked about data, generate realistic/plausible data',
  'For grid-like layouts, use Stack with direction "row" and wrap=true. Avoid justify="between" '
      'unless you specifically want large gutters.',
  'For forms, define one FormControl reference per field so controls can stream progressively.',
  'For forms, always provide the second Form argument with Buttons(...) actions: Form(name, '
      'buttons, fields).',
  'Never nest Form inside Form.',
  r'Use @Reset($var1, $var2) after form submit to restore defaults — not @Set($var, "")',
  'Multi-query refresh: Action([@Run(mutation), @Run(query1), @Run(query2), @Reset(...)])',
  r'$variables are reactive: changing via Select or @Set re-evaluates all Queries and expressions '
      'referencing them',
  'Use existing components (Tabs, Accordion, Modal) before inventing ternary show/hide patterns',
  'Card blocks (SnippetCardBlock, OverviewCardBlock, ContextCardBlock, CompositeCardBlock, '
      'VisualCardBlock) need at least 2 items; every item in a block must have the same structure.',
  'Text / BoldText / IconText / ImageText / ImageTextLarge / MetricIndicatorInline / '
      'MetricIndicatorWithStrikethrough are inline building blocks used INSIDE card items — do not '
      'place them directly in a Stack or Card.',
  "EntityList size='small' (no header/footer) is only for use inside a CompositeCardItem body; use "
      "size='default' everywhere else.",
  'Image URLs must be real (from a tool result or the user) — never invent or template an image '
      'URL.',
  'Always pass a category to Icon — it enables a topical fallback when the exact icon name is '
      'unavailable.',
  'EditableTable requires the consuming app to persist edits — use it only when the user or app '
      'explicitly asks for an editable table; default to Table for read-only data.',
];
