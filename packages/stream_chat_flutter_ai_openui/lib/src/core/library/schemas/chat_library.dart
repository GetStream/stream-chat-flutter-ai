// ignore_for_file: no_adjacent_strings_in_list

part of 'built_in_libraries.dart';

/// The component a chat program's root is.
const String chatRoot = 'Card';

/// The components of the chat library, in library order.
final List<ComponentSchema> chatComponents = [
  _chatCard,
  _cardHeader,
  _textContent,
  _markDownRenderer,
  _callout,
  _textCallout,
  _image,
  _imageBlock,
  _imageGallery,
  _codeBlock,
  _separator,
  _table,
  _col,
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
  _button,
  _buttons,
  _listBlock,
  _listItem,
  _chatFollowUpBlock,
  _chatFollowUpItem,
  _chatSectionBlock,
  _chatSectionItem,
  _tabs,
  _chatTabItem,
  _accordion,
  _chatAccordionItem,
  _steps,
  _stepsItem,
  _chatCarousel,
  _tagBlock,
  _tag,
  _entityList,
  _inlineHeader,
  _icon,
  _iconButton,
  _editableTable,
  _chipItem,
  _chips,
  _optionCard,
  _optionCards,
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
];

/// How the system prompt groups the chat library's components.
final List<ComponentGroup> chatComponentGroups = [
  const ComponentGroup(
    'Content',
    components: [
      'CardHeader',
      'TextContent',
      'MarkDownRenderer',
      'Callout',
      'TextCallout',
      'Image',
      'ImageBlock',
      'ImageGallery',
      'CodeBlock',
      'Separator',
      'InlineHeader',
    ],
    notes: [
      '- InlineHeader is a compact heading + description pair for labelling a block inside the '
          'response (lighter than CardHeader).',
      '- Pass sources on Card ([{ title, sourceName, url }]) when the answer relies on references, and '
          'cite them inline in TextContent as [1], [2] (1-based index into sources). A Sources strip '
          'renders at the bottom of the card.',
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
  ),
  const ComponentGroup(
    'Charts (1D)',
    components: [
      'PieChart',
      'RadialChart',
      'SingleStackedBarChart',
      'Slice',
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
      '- Define EACH FormControl as its own reference — do NOT inline all controls in one array.',
      '- NEVER nest Form inside Form.',
      '- Form requires explicit buttons. Always pass a Buttons(...) reference as the second Form '
          'argument: Form(name, buttons, fields).',
      '- rules is an optional object: { required: true, email: true, min: 8, maxLength: 100 }',
      '- The renderer shows error messages automatically — do NOT generate error text in the UI',
    ],
  ),
  const ComponentGroup(
    'Buttons',
    components: [
      'Button',
      'Buttons',
      'Icon',
      'IconButton',
    ],
    notes: [
      '- Icon renders a lucide icon by kebab-case name; it is also used as the icon of IconButton, '
          'IconText and OptionCard.',
    ],
  ),
  const ComponentGroup(
    'Lists & Follow-ups',
    components: [
      'ListBlock',
      'ListItem',
      'FollowUpBlock',
      'FollowUpItem',
    ],
    notes: [
      '- Use ListBlock with ListItem references for numbered lists.',
      '- Use FollowUpBlock with FollowUpItem references at the end of a response to suggest next '
          'actions.',
      '- A ListItem is clickable ONLY when given an action (5th argument); without one it is plain '
          'text.',
      '- Clicking a FollowUpItem, or a ListItem with a @ToAssistant action, sends text to the LLM as a '
          'user message.',
      '- Example: list = ListBlock([item1, item2])  item1 = ListItem("Option A", "Details about A", '
          'null, null, @ToAssistant("Option A"))',
    ],
  ),
  const ComponentGroup(
    'Sections',
    components: ['SectionBlock', 'SectionItem'],
    notes: [
      '- SectionBlock renders collapsible accordion sections that auto-open as they stream.',
      '- Each section needs a unique `value` id, a `trigger` label, and a `content` array.',
      '- Example: sections = SectionBlock([s1, s2])  s1 = SectionItem("intro", "Introduction", '
          '[content1])',
      '- Set isFoldable=false to render sections as flat headers instead of accordion.',
    ],
  ),
  const ComponentGroup(
    'Layout',
    components: [
      'Tabs',
      'TabItem',
      'Accordion',
      'AccordionItem',
      'Steps',
      'StepsItem',
      'Carousel',
    ],
    notes: [
      '- Use Tabs to present alternative views — each TabItem has a value id, trigger label, and '
          'content array.',
      '- Carousel takes an array of slides, where each slide is an array of content: carousel = '
          'Carousel([[t1, img1], [t2, img2]])',
      '- IMPORTANT: Every slide in a Carousel must have the same structure — same component types in '
          'the same order.',
      '- For image carousels use: [[title, image, description, tags], ...] — every slide must follow '
          'this exact pattern.',
      '- Use real, publicly accessible image URLs (e.g. https://picsum.photos/seed/KEYWORD/800/500). '
          'Never hallucinate image URLs.',
    ],
  ),
  const ComponentGroup(
    'Data Display',
    components: [
      'TagBlock',
      'Tag',
      'EntityList',
    ],
    notes: [
      '- EntityList is a compact two-column list of { left, right } rows (e.g. name / value). '
          "size='default' also supports a header and footer row; size='small' does not.",
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

/// The example programs the chat library's system prompt shows.
final List<String> chatExamples = [
  'Example 1 — Informational response (the shape for "tell me about X" / explainer asks):\n'
      '\n'
      'root = Card([header, intro, highlights, statsHeader, statsCards, sectionsBlock, actionBtns], '
      '[src1, src2])\n'
      'header = CardHeader("Paris", "The City of Light · France\'s Eternal Capital")\n'
      'intro = TextContent("Paris is one of the world\'s most visited cities — a timeless blend of '
      'iconic landmarks, world-class cuisine, art, and romance [1]. In 2026 the city is buzzing with '
      'new energy: the **Grand Palais** has reopened after a €466M renovation, and you can now **swim '
      'in the Seine** for the first time in over a century [2].")\n'
      'highlights = ContextCardBlock([h1, h2, h3], "grid", true, @ToAssistant("Tell me more about this '
      'aspect of Paris"))\n'
      'h1 = ContextCardItem("art-museums", "Art & Museums", "143 museums including the Louvre & newly '
      'reopened Grand Palais.", "gray", '
      '"https://cdn.britannica.com/03/121003-050-2544BD4E/Interior-Louvre-Museum-Paris.jpg")\n'
      'h2 = ContextCardItem("gastronomy", "Gastronomy", "9,000+ restaurants, 130+ Michelin stars, and '
      'the world\'s best baguettes.", "gray")\n'
      'h3 = ContextCardItem("fashion-capital", "Fashion Capital", "Home to Chanel, Dior, Louis Vuitton '
      '& Hermès — the global luxury hub.", "gray", '
      '"https://thumbs.dreamstime.com/z/dior-storefront-facade-chanel-store-lvmh-s-french-designer-modeh'
      'ouse-christian-adjacent-to-luxury-fashion-beauty-brand-327161553.jpg")\n'
      'statsHeader = InlineHeader("Paris by the Numbers", "Key visitor statistics")\n'
      'statsCards = OverviewCardBlock([ov1, ov2, ov3], "grid", true)\n'
      'ov1 = OverviewCardItem("annual-visitors", ov1top, ov1metric)\n'
      'ov1top = IconText(ov1icon, "neutral", "m", "Annual Visitors", "2024 arrivals", false, '
      '"vertical")\n'
      'ov1icon = Icon("users", "people")\n'
      'ov1metric = MetricIndicatorInline("48.7M", "tourists", { direction: "up", value: 2.5 })\n'
      'ov2 = OverviewCardItem("museums-monuments", ov2top, ov2metric)\n'
      'ov2top = IconText(ov2icon, "neutral", "m", "Museums & Monuments", "Cultural sites", false, '
      '"vertical")\n'
      'ov2icon = Icon("landmark", "buildings")\n'
      'ov2metric = MetricIndicatorInline("2,370+", "across the city")\n'
      'ov3 = OverviewCardItem("tourism-revenue", ov3top, ov3metric)\n'
      'ov3top = IconText(ov3icon, "neutral", "m", "Tourism Revenue", "2024 estimate", false, '
      '"vertical")\n'
      'ov3icon = Icon("circle-dollar-sign", "finance")\n'
      'ov3metric = MetricIndicatorInline("€23.4B", "generated")\n'
      'sectionsBlock = SectionBlock([secLandmarks, secFood, secWhen], false)\n'
      'secLandmarks = SectionItem("landmarks", "Iconic Landmarks", [landmarksCarousel])\n'
      'landmarksCarousel = VisualCardBlock([lm1, lm2, lm3, lm4], "carousel", true, @ToAssistant("Tell '
      'me more about this Paris landmark"))\n'
      'lm1 = VisualCardItem(lm1body, "eiffel-tower", '
      '"https://c8.alamy.com/comp/RYEB13/aerial-view-of-the-eiffel-tower-with-the-park-champ-de-mars-and'
      '-the-river-seine-paris-france-RYEB13.jpg", lm1tag, "Aerial view of the Eiffel Tower")\n'
      'lm1body = BoldText("text", "Eiffel Tower", "Open daily 9am–midnight")\n'
      'lm1tag = Tag("Must-See", lm1tagIcon, "sm", "info")\n'
      'lm1tagIcon = Icon("star", "shapes")\n'
      'lm2 = VisualCardItem(lm2body, "the-louvre", '
      '"https://images.fineartamerica.com/images/artworkimages/mediumlarge/3/1-exterior-of-musee-du-louv'
      're-museum-paris-france-bernard-jaubert.jpg", lm2tag, "Exterior of the Louvre museum")\n'
      'lm2body = BoldText("text", "The Louvre", "World\'s largest art museum")\n'
      'lm2tag = Tag("8.9M visits/yr", lm2tagIcon, "sm", "success")\n'
      'lm2tagIcon = Icon("trending-up", "charts")\n'
      'lm3 = VisualCardItem(lm3body, "notre-dame", '
      '"https://cdn.britannica.com/29/255529-050-63A22A3C/notre-dame-de-paris-cathedral-paris-france.jpg'
      '", lm3tag, "Notre-Dame cathedral facade")\n'
      'lm3body = BoldText("text", "Notre-Dame", "Fully restored cathedral")\n'
      'lm3tag = Tag("Reopened 2024", lm3tagIcon, "sm", "warning")\n'
      'lm3tagIcon = Icon("hammer", "tools")\n'
      'lm4 = VisualCardItem(lm4body, "versailles", '
      '"https://cdn.britannica.com/76/130076-050-31128A3D/Latona-Fountain-Balthazard-Marsy-Gaspard-Andre'
      '-Le.jpg", lm4tag, "Latona Fountain at Versailles")\n'
      'lm4body = BoldText("text", "Palace of Versailles", "Royal gardens & grand halls")\n'
      'lm4tag = Tag("Day Trip", lm4tagIcon, "sm", "neutral")\n'
      'lm4tagIcon = Icon("train-front", "travel")\n'
      'secFood = SectionItem("food", "Food & Drink", [foodCards])\n'
      'foodCards = ContextCardBlock([f1, f2, f3], "grid", true, @ToAssistant("Tell me more about '
      'eating and drinking in Paris"))\n'
      'f1 = ContextCardItem("bistros", "Bistros", "Classic French fare — try Les Arlots for confit '
      'beef cheeks.", "gray", '
      '"https://everydayparisian.com/wp-content/uploads/2023/01/IMG_0221-768x1024.webp")\n'
      'f2 = ContextCardItem("fine-dining", "Fine Dining", "Septime leads a new wave of creative '
      'Michelin-starred cuisine.", "gray", '
      '"https://production-data.worldofmouth.app/images/72b2e6db-97ea-49c4-aa5d-3b7c8121c812.jpg")\n'
      'f3 = ContextCardItem("bakeries", "Bakeries", "Shinya Pain for sourdough. Grand Prix-winning '
      'baguettes citywide.", "gray", '
      '"https://www.davidlebovitz.com/wp-content/uploads/2018/09/Le-petit-grain-paris-bakery-boulangerie'
      '-patisserie-pastry-shop-8-640x895.jpg")\n'
      'secWhen = SectionItem("when", "Best Time to Visit", [whenTabs])\n'
      'whenTabs = Tabs([tabSpring, tabSummer])\n'
      'tabSpring = TabItem("spring", "Spring", [springList])\n'
      'springList = ListBlock([sp1, sp2, sp3], "number")\n'
      'sp1 = ListItem("Cherry blossoms at Parc de Sceaux", "March – May", null, null, '
      '@ToAssistant("Tell me about cherry blossom season in Paris"))\n'
      'sp2 = ListItem("Picnics along the Seine & in city parks", "Warm, lively atmosphere", null, '
      'null, @ToAssistant("Where are the best picnic spots in Paris?"))\n'
      'sp3 = ListItem("Fewer crowds than summer", "Ideal for sightseeing", null, null, '
      '@ToAssistant("How busy is Paris in spring?"))\n'
      'tabSummer = TabItem("summer", "Summer", [summerList])\n'
      'summerList = ListBlock([su1, su2, su3], "number")\n'
      'su1 = ListItem("Swim in the Seine — open July & August 2026", "First time in 102 years", null, '
      'null, @ToAssistant("Tell me about swimming in the Seine"))\n'
      'su2 = ListItem("Open-air cinema at Parc de la Villette", "Free films under the stars", null, '
      'null, @ToAssistant("Tell me about the open-air cinema at Parc de la Villette"))\n'
      'su3 = ListItem("Bastille Day celebrations on July 14", "Fireworks at the Eiffel Tower", null, '
      'null, @ToAssistant("What happens in Paris on Bastille Day?"))\n'
      'actionBtns = Buttons([btn1, btn2, btn3], "row")\n'
      'btn1 = Button("Plan a Trip to Paris", @ToAssistant("Help me plan a trip to Paris"), "primary")\n'
      'btn2 = Button("Best Hotels in Paris", @ToAssistant("Show me the best hotels in Paris"), '
      '"secondary")\n'
      'btn3 = Button("Build a Paris Itinerary", @ToAssistant("Build a 5-day Paris itinerary for me"), '
      '"secondary")\n'
      'src1 = { title: "Paris Travel Guide 2025", sourceName: "Travel and Tour World", url: '
      '"https://www.travelandtourworld.com/news/article/from-iconic-landmarks-to-hidden-gems-the-ultimat'
      'e-paris-travel-guide-for-2025-you-need-to-read-now/" }\n'
      'src2 = { title: "Best Things to Do in Paris 2026", sourceName: "Time Out Paris", url: '
      '"http://www.timeout.fr/paris/en/for-tourists" }',
  'Example 2 — Data and analytics response (quantitative asks lead with KPIs and charts):\n'
      '\n'
      'root = Card([pageHeader, kpiBlock, sections, deepDiveHeader, compositeCards, actionButtons])\n'
      'pageHeader = CardHeader("Analytics Dashboard", "April 2026 · Business Performance Overview")\n'
      'kpiBlock = SnippetCardBlock([kpi1, kpi2, kpi3, kpi4], "grid", true)\n'
      'kpi1 = SnippetCardItem("total-revenue", kpi1lhs, kpi1rhs)\n'
      'kpi1lhs = IconText(kpi1icon, "neutral", "m", "Total Revenue", "Month to date", false, '
      '"horizontal")\n'
      'kpi1icon = Icon("circle-dollar-sign", "finance")\n'
      'kpi1rhs = BoldText("number", "\$284,500", "+12.4%", "metric")\n'
      'kpi2 = SnippetCardItem("active-users", kpi2lhs, kpi2rhs)\n'
      'kpi2lhs = IconText(kpi2icon, "neutral", "m", "Active Users", "Monthly active users", false, '
      '"horizontal")\n'
      'kpi2icon = Icon("users", "people")\n'
      'kpi2rhs = BoldText("number", "47,320", "+6.8%", "metric")\n'
      'kpi3 = SnippetCardItem("conversion-rate", kpi3lhs, kpi3rhs)\n'
      'kpi3lhs = IconText(kpi3icon, "neutral", "m", "Conversion Rate", "Avg. this month", false, '
      '"horizontal")\n'
      'kpi3icon = Icon("trending-up", "charts")\n'
      'kpi3rhs = BoldText("number", "5.7%", "+0.9%", "metric")\n'
      'kpi4 = SnippetCardItem("churn-rate", kpi4lhs, kpi4rhs)\n'
      'kpi4lhs = IconText(kpi4icon, "neutral", "m", "Churn Rate", "Monthly customer churn", false, '
      '"horizontal")\n'
      'kpi4icon = Icon("user-minus", "people")\n'
      'kpi4rhs = BoldText("number", "2.1%", "-0.4%", "metric")\n'
      'sections = SectionBlock([secUsers, secChannels], false)\n'
      'secUsers = SectionItem("users", "User Activity", [userTabs])\n'
      'userTabs = Tabs([tabGrowth, tabRetention])\n'
      'tabGrowth = TabItem("growth", "User Growth", [growthChart])\n'
      'growthChart = LineChart(months, [dauSeries, mauSeries], "natural", "Month", "Users (k)")\n'
      'months = ["May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr"]\n'
      'dauSeries = Series("DAU", [5.1, 5.4, 5.8, 6.2, 6.7, 7.1, 7.6, 8.0, 8.4, 8.9, 9.3, 9.8])\n'
      'mauSeries = Series("MAU", [28.4, 30.1, 31.8, 33.5, 35.2, 37.1, 38.8, 40.4, 42.1, 43.9, 45.6, '
      '47.3])\n'
      'tabRetention = TabItem("retention", "Cohort Retention", [retentionChart])\n'
      'retentionChart = LineChart(cohortMonths, [cohortJan, cohortFeb, cohortMar], "natural", "Month '
      'Since Signup", "Retention (%)")\n'
      'cohortMonths = ["Month 0", "Month 1", "Month 2", "Month 3", "Month 4", "Month 5", "Month 6"]\n'
      'cohortJan = Series("Jan Cohort", [100, 80, 70, 62, 56, 51, 47])\n'
      'cohortFeb = Series("Feb Cohort", [100, 83, 73, 65, 59, 54, 50])\n'
      'cohortMar = Series("Mar Cohort", [100, 86, 76, 68, 62, 0, 0])\n'
      'secChannels = SectionItem("channels", "Acquisition Channels", [channelTabs])\n'
      'channelTabs = Tabs([tabChannelBar, tabChannelTable])\n'
      'tabChannelBar = TabItem("channel-bar", "Revenue by Channel", [channelBarChart])\n'
      r'channelBarChart = HorizontalBarChart(channels, [channelSeries], "grouped", "Revenue ($k)", '
      '"Channel")\n'
      'channels = ["Organic Search", "Paid Ads", "Referral Program", "Partner Network", "Direct / '
      'Brand", "Email Campaigns"]\n'
      'channelSeries = Series("Revenue (\$k)", [82.4, 68.1, 54.6, 38.2, 26.8, 14.4])\n'
      'tabChannelTable = TabItem("channel-table", "Full Breakdown", [channelTable])\n'
      'channelTable = Table([colChannel, colLeads, colConv, colCac, colRevenue, colStatus])\n'
      'colChannel = Col("Channel", channels, "string")\n'
      'colLeads = Col("Leads", [4210, 3180, 2050, 1120, 1290, 820], "number")\n'
      'colConv = Col("Conv. Rate", ["6.4%", "5.1%", "9.4%", "11.8%", "5.8%", "8.1%"], "string")\n'
      'colCac = Col("CAC (\$)", [188, 395, 132, 109, 218, 154], "number")\n'
      'colRevenue = Col("Revenue (\$k)", [82.4, 68.1, 54.6, 38.2, 26.8, 14.4], "number")\n'
      'colStatus = Col("Status", ["Scaling", "Optimizing", "Scaling", "Growing", "Stable", "Stable"], '
      '"string")\n'
      'deepDiveHeader = InlineHeader("Support Health & Marketing ROI", "Click a card to explore deeper '
      'insights")\n'
      'compositeCards = CompositeCardBlock([cardSupport, cardMarketing], "grid", true, '
      '@ToAssistant("Explore this deep-dive area in more detail"))\n'
      'cardSupport = CompositeCardItem("support-health", supportHeader, [supportMetric, supportChart, '
      'supportList])\n'
      'supportHeader = IconText(supportIcon, "neutral", "m", "Support Health", "Ticket volume & '
      'resolution trends", false, "horizontal")\n'
      'supportIcon = Icon("headphones", "communication")\n'
      'supportMetric = MetricIndicatorInline("94.2% CSAT", "Customer Satisfaction Score", { direction: '
      '"up", value: 2.1 })\n'
      'supportChart = BarChart(["Jan", "Feb", "Mar", "Apr"], [openSeries, resolvedSeries], "grouped", '
      '"Month", "Tickets")\n'
      'openSeries = Series("Opened", [341, 327, 308, 289])\n'
      'resolvedSeries = Series("Resolved", [319, 318, 301, 283])\n'
      'supportList = EntityList([sup1, sup2, sup3], "small")\n'
      'sup1 = { left: "Avg. Resolution Time", right: "4h 12m", rightVariant: "text" }\n'
      'sup2 = { left: "First Contact Resolution", right: "78.4%", rightVariant: "number" }\n'
      'sup3 = { left: "Escalation Rate", right: "6.2%", rightVariant: "number" }\n'
      'cardMarketing = CompositeCardItem("marketing-roi", marketingHeader, [marketingMetric, '
      'marketingChart, marketingList])\n'
      'marketingHeader = IconText(marketingIcon, "neutral", "m", "Marketing ROI", "Spend vs. pipeline '
      'generated", false, "horizontal")\n'
      'marketingIcon = Icon("megaphone", "communication")\n'
      'marketingMetric = MetricIndicatorInline("3.8x Blended ROI", "Return on Ad Spend", { direction: '
      '"up", value: 0.4 })\n'
      'marketingChart = AreaChart(["Jan", "Feb", "Mar", "Apr"], [spendSeries, pipelineSeries], '
      '"natural", "Month", "Value (\$k)")\n'
      'spendSeries = Series("Ad Spend", [44.0, 46.8, 49.2, 51.6])\n'
      'pipelineSeries = Series("Pipeline Generated", [158.2, 171.5, 184.9, 196.1])\n'
      'marketingList = EntityList([mkt1, mkt2, mkt3], "small")\n'
      'mkt1 = { left: "Total Ad Spend (Apr)", right: "\$51,600", rightVariant: "number" }\n'
      'mkt2 = { left: "Cost per Lead", right: "\$48.20", rightVariant: "number" }\n'
      'mkt3 = { left: "Top Channel", right: "Organic Search", rightVariant: "text" }\n'
      'actionButtons = Buttons([btnChannels, btnForecast], "row")\n'
      'btnChannels = Button("Break Down by Channel", @ToAssistant("Break down this month\'s revenue by '
      'acquisition channel"), "primary")\n'
      'btnForecast = Button("Forecast Next Quarter", @ToAssistant("Forecast revenue and active users '
      'for next quarter"), "secondary")',
  'Example 3 — Form response (help-me-choose/plan asks: inspiration cards FIRST, then a compact '
      'form). The inspiration-card images below came from an image tool call — include such cards ONLY '
      'when you have real URLs; with no real URLs, start directly with the form:\n'
      '\n'
      'root = Card([header, intro, inspoCards, form])\n'
      'header = CardHeader("Plan Your Trip", "A few ideas to spark inspiration — then tell me your '
      'preferences")\n'
      'intro = TextContent("Tap a style to jump straight in, or fill the quick form below for a '
      'tailored plan.")\n'
      'inspoCards = VisualCardBlock([insp1, insp2], "grid", true, @ToAssistant("Plan me a trip in this '
      'style with destinations, itinerary, and costs"))\n'
      'insp1 = VisualCardItem(insp1body, "inspo-beach", '
      '"https://www.travelandleisure.com/thmb/cuAB7XMQ6s_Gji-no956KNopT7M=/1500x0/filters:no_upscale():m'
      'ax_bytes(150000):strip_icc()/TAL-maldives-TROPVACAY0325-1b5047d5931d4850b47d082966f9f563.jpg", '
      'insp1tag, "Maldives overwater villas")\n'
      'insp1body = BoldText("text", "Tropical Beach Escape", "Overwater villas & snorkeling")\n'
      'insp1tag = Tag("Relaxation", insp1icon, "sm", "info")\n'
      'insp1icon = Icon("umbrella", "travel")\n'
      'insp2 = VisualCardItem(insp2body, "inspo-mountain", '
      '"https://www.salkantaytrekmachu.com/img/adventure-travel-peru-032.jpg", insp2tag, "Trekking in '
      'the Peruvian Andes")\n'
      'insp2body = BoldText("text", "Mountain Adventure", "Trekking & epic views")\n'
      'insp2tag = Tag("Active", insp2icon, "sm", "warning")\n'
      'insp2icon = Icon("mountain", "nature")\n'
      'form = Form("trip-planner", formButtons, [fcDestination, fcDates, fcTravellers, fcTripType, '
      'fcBudget, fcStay, fcNotes])\n'
      'formButtons = Buttons([btnSubmit, btnSkip], "row")\n'
      'btnSubmit = Button("Plan My Trip", @ToAssistant("Help me plan a trip based on my form '
      'submission"), "primary")\n'
      'btnSkip = Button("Just Surprise Me", @ToAssistant("Skip the form and surprise me with a '
      'destination and itinerary"), "secondary")\n'
      'fcDestination = FormControl("Destination", destinationInput, "Leave blank if you\'d like '
      'suggestions")\n'
      'destinationInput = Input("destination", "e.g. Tokyo, Japan — or leave blank", "text")\n'
      'fcDates = FormControl("Travel Dates", datesPicker, "Select your start and end dates")\n'
      'datesPicker = DatePicker("travel-dates", "range", { required: true })\n'
      'fcTravellers = FormControl("Number of Travellers", travellersSelect, "How many people are '
      'travelling?")\n'
      'travellersSelect = Select("num-travellers", [tr1, tr2, tr3, tr4], "Select number of '
      'travellers", { required: true })\n'
      'tr1 = SelectItem("1", "1 — Solo")\n'
      'tr2 = SelectItem("2", "2 — Couple")\n'
      'tr3 = SelectItem("3-4", "3–4 People")\n'
      'tr4 = SelectItem("5+", "5+ People")\n'
      'fcTripType = FormControl("Trip Type", tripTypeCards, "What kind of trip are you planning?")\n'
      'tripTypeCards = OptionCards("trip-type", "single", [oc1, oc2, oc3, oc4], { required: true })\n'
      'oc1 = OptionCard("adventure", "Adventure", "Hiking, trekking & outdoor activities", oc1icon)\n'
      'oc1icon = Icon("mountain", "nature")\n'
      'oc2 = OptionCard("beach", "Beach & Relaxation", "Sun, sand & leisure", oc2icon)\n'
      'oc2icon = Icon("waves", "nature")\n'
      'oc3 = OptionCard("cultural", "Cultural & Historical", "Museums, heritage & local experiences", '
      'oc3icon)\n'
      'oc3icon = Icon("landmark", "buildings")\n'
      'oc4 = OptionCard("city", "City Break", "Urban exploration & nightlife", oc4icon)\n'
      'oc4icon = Icon("building-2", "buildings")\n'
      'fcBudget = FormControl("Estimated Budget (per person)", budgetSlider, "Drag to set your '
      'per-person budget in USD")\n'
      'budgetSlider = Slider("budget", "discrete", 500, 10000, 500, [2500], "Budget (USD)")\n'
      'fcStay = FormControl("Accommodation Preference", stayChips, "Select all that apply")\n'
      'stayChips = Chips("accommodation", "multiple", [ch1, ch2, ch3, ch4], {}, ["hotel"])\n'
      'ch1 = ChipItem("hotel", "Hotel", ch1icon)\n'
      'ch1icon = Icon("building", "buildings")\n'
      'ch2 = ChipItem("resort", "Resort", ch2icon)\n'
      'ch2icon = Icon("umbrella", "travel")\n'
      'ch3 = ChipItem("airbnb", "Vacation Rental", ch3icon)\n'
      'ch3icon = Icon("home", "home")\n'
      'ch4 = ChipItem("camping", "Camping / Glamping", ch4icon)\n'
      'ch4icon = Icon("tent", "nature")\n'
      'fcNotes = FormControl("Special Requests or Notes", notesArea, "Any dietary needs, accessibility '
      'requirements, or specific interests?")\n'
      'notesArea = TextArea("special-requests", "e.g. vegetarian meals, wheelchair access, honeymoon '
      'surprise...", 4)',
  'Example 4 — Recommendations with images and links (same pattern for products, movies, '
      'restaurants, articles):\n'
      '\n'
      'root = Card([header, intro, posters, linksHeader, trackCards], [src1, src2])\n'
      'header = CardHeader("Retro-Energetic Indian Tracks", "New Hindi releases with 80s/90s dance '
      'DNA")\n'
      'intro = TextContent("These recent tracks channel retro synths and 90s party percussion [1][2]. '
      'Tap a poster to explore a track, or use its button to watch the exact official video.")\n'
      'posters = VisualCardBlock([v1, v2], "grid", true, @ToAssistant("Tell me more about this track '
      'and its retro influences"))\n'
      'v1 = VisualCardItem(v1body, "tamma", "https://i.ytimg.com/vi/PQHeOb0Q9oo/hq720.jpg", v1tag, '
      '"Tamma Tamma video poster")\n'
      'v1body = BoldText("text", "Tamma Tamma", "Dhurandhar · Ranveer Singh")\n'
      'v1tag = Tag("80s Electro-Disco", v1icon, "sm", "success")\n'
      'v1icon = Icon("disc-3", "multimedia")\n'
      'v2 = VisualCardItem(v2body, "sajan", "https://i.ytimg.com/vi/mLz-qBiRnl8/hq720.jpg", v2tag, '
      '"Sajan Re video poster")\n'
      'v2body = BoldText("text", "Sajan Re", "Nora Fatehi · Badshah")\n'
      'v2tag = Tag("Synthwave Electro", v2icon, "sm", "info")\n'
      'v2icon = Icon("music", "multimedia")\n'
      'linksHeader = InlineHeader("Watch the Exact Videos", "Each button opens that track\'s official '
      'video")\n'
      'trackCards = CompositeCardBlock([t1, t2], "grid", true)\n'
      't1 = CompositeCardItem("t-tamma", t1h, [t1body, t1tags], { button: t1btn })\n'
      't1h = IconText(t1icon, "neutral", "m", "Tamma Tamma", "Bappi Lahiri classic, electro-funk '
      'rework", true, "horizontal")\n'
      't1icon = Icon("disc-3", "multimedia")\n'
      't1body = Text("text", "Heavy analog synths and brass over a fast disco groove.", "Retro '
      'Electro-Disco")\n'
      't1tags = TagBlock(["2026 Film Hit", "Peak Party"])\n'
      't1btn = Button("Watch on YouTube", @OpenUrl("https://www.youtube.com/watch?v=PQHeOb0Q9oo"), '
      '"primary")\n'
      't2 = CompositeCardItem("t-sajan", t2h, [t2body, t2tags], { button: t2btn })\n'
      't2h = IconText(t2icon, "neutral", "m", "Sajan Re", "Nora Fatehi · Badshah · Sanjoy", true, '
      '"horizontal")\n'
      't2icon = Icon("music", "multimedia")\n'
      't2body = Text("text", "Synthwave melody hooks over a modern club beat.", "Retro-Fusion '
      'Electro")\n'
      't2tags = TagBlock(["Club Anthem", "Nora x Badshah"])\n'
      't2btn = Button("Watch on YouTube", @OpenUrl("https://www.youtube.com/watch?v=COUSCnFazzc"), '
      '"primary")\n'
      'src1 = { title: "Tamma Tamma (Full Video) - Dhurandhar", sourceName: "YouTube (T-Series)", url: '
      '"https://www.youtube.com/watch?v=PQHeOb0Q9oo" }\n'
      'src2 = { title: "Sajan Re (Official Music Video)", sourceName: "YouTube (T-Series)", url: '
      '"https://www.youtube.com/watch?v=COUSCnFazzc" }',
  'Example 5 — Table with follow-ups:\n'
      '\n'
      'root = Card([title, tbl, followUps])\n'
      'title = TextContent("Top Languages", "large-heavy")\n'
      'tbl = Table([Col("Language", langs), Col("Users (M)", users), Col("Year", years)])\n'
      'langs = ["Python", "JavaScript", "Java"]\n'
      'users = [15.7, 14.2, 12.1]\n'
      'years = [1991, 1995, 1995]\n'
      'followUps = FollowUpBlock([fu1, fu2])\n'
      'fu1 = FollowUpItem("Tell me more about Python")\n'
      'fu2 = FollowUpItem("Show me a JavaScript comparison")',
];

/// The rules the chat library's system prompt ends with.
final List<String> chatAdditionalRules = [
  'When asked about data, generate realistic/plausible data',
  'Every response is a single Card(children) — children stack vertically automatically. No layout '
      'params are needed on Card.',
  'Card is the only layout container. Do NOT use Stack. Use Tabs to switch between sections, '
      'Carousel for horizontal scroll.',
  'Use FollowUpBlock at the END of a Card to suggest what the user can do or ask next.',
  'Use ListBlock when presenting a set of options or steps; give each ListItem an action (5th '
      'argument) to make it clickable — without one the item is plain text.',
  'Use SectionBlock to group long responses into collapsible sections — good for reports, FAQs, '
      'and structured content.',
  'Use SectionItem inside SectionBlock: each item needs a unique value id, a trigger (header '
      'label), and a content array.',
  'Carousel takes an array of slides, where each slide is an array of content: carousel = '
      'Carousel([[t1, img1], [t2, img2]])',
  'IMPORTANT: Every slide in a Carousel must use the same component structure in the same order — '
      'e.g. all slides: [title, image, description, tags].',
  'For forms, define one FormControl reference per field so controls can stream progressively.',
  'For forms, always provide the second Form argument with Buttons(...) actions: Form(name, '
      'buttons, fields).',
  'Never nest Form inside Form.',
  'CardHeader is the page-level heading — place it as the first child of Card; InlineHeader is a '
      'lighter subsection label for a block inside the response, and is redundant when the following '
      'component already has a heading.',
  'Never use Callout or TextCallout to justify why you did what you did or for any '
      'meta-information.',
  'Every image slot (Image, ImageBlock, ImageGallery, VisualCardItem/ContextCardItem bgImageSrc, '
      'ImageText, ImageTextLarge, ListItem image) requires a REAL URL from a tool result, the '
      'conversation, or the user — NEVER invent, guess, or template a URL.',
  'If no image URL is in context, compose without image components — icons, gray ContextCardItems, '
      'and charts still make rich layouts.',
  'Argument-order trap: Image takes alt FIRST, while ImageBlock, ImageText, and ImageTextLarge '
      'take src FIRST — alt text in a src slot ships a broken image.',
  'Card blocks (SnippetCardBlock, OverviewCardBlock, ContextCardBlock, CompositeCardBlock, '
      'VisualCardBlock) need at least 2 items, all with the same structure; use layout "grid" for '
      'primary side-by-side comparison and "carousel" for secondary browsing.',
  "The card-block action is BLOCK-LEVEL: one action shared by every card, with the clicked card's "
      'details attached automatically — keep the @ToAssistant message generic (e.g. "Tell me more '
      'about this destination"), and never use a block-level @OpenUrl since it would send every card '
      'to the same URL.',
  'Card items have NO per-item action: to give each item its own external link, use '
      'CompositeCardItem with footer { button: Button(label, @OpenUrl(url)) } — never claim a card '
      'opens a link it cannot.',
  'Text, BoldText, IconText, ImageText, ImageTextLarge and MetricIndicator* are inline building '
      'blocks used INSIDE card items — do not place them directly in the root Card.',
  'EntityList size "small" is reserved for CompositeCardItem body content (no header/footer); use '
      'size "default" elsewhere.',
  'Tag variant must be semantically correct (success=positive, danger=negative, '
      'warning=cautionary, info=informational, neutral=label); Tag takes an optional Icon second, so '
      'use Tag(text, icon, size, variant) when a variant is needed.',
  'TagBlock takes plain strings — keep it to at most 3 tags.',
  'ListBlock variant "number" is for ordered sequences and rankings, "image" for products/profiles '
      'with a real image; Steps is for ordered sequential processes only.',
  'Use SectionBlock to divide a long response into independent, equally prominent topics; use Tabs '
      'when the items are alternative views of the same thing; set isFoldable=false unless a section '
      'has 4+ distinct blocks; never make SectionBlock the first Card child.',
  'Accordion is for supplementary or FAQ content only — never primary information, 3-5 items max, '
      'and always the last component in its section or card.',
  'Charts: LineChart/AreaChart variant "natural" for smooth trends and "linear" for precise '
      'point-to-point data; BarChart "grouped" for side-by-side comparison and "stacked" for '
      'part-to-whole; prefer HorizontalBarChart when category labels are long or numerous.',
  'For large chart values, scale the data and put the unit in the axis label (e.g. yLabel "Revenue '
      r'($k)") instead of passing raw thousands or millions.',
  'Quantitative asks get a chart (plus KPI cards where useful) in the FIRST response — do not '
      'answer numbers with prose or a table alone.',
  'Table is column-oriented: each Col holds its own data array of plain strings or numbers (never '
      "components), and every column's array must have the same length.",
  'Use EditableTable ONLY when the user or app explicitly asks for an editable table; default to '
      'Table for read-only data.',
  'Every Form MUST have EXACTLY ONE submit Button with variant "primary" — that button validates '
      'the form; other buttons (secondary/tertiary escape hatches like "Just Surprise Me") skip '
      'validation, and there is never a reset button.',
  'Prefer structured inputs (Select, Chips, OptionCards, DatePicker, Slider) over free-text Input, '
      'give every FormControl a clear label (and a hint where it prevents mistakes), and keep each '
      'field name unique within the response.',
  'Validation rules ({ required: true, email: true, minLength: 8, ... }) are enforced with inline '
      'errors — use them for genuinely essential fields, but never require a free-text field where '
      'leaving it blank is meaningful.',
  'Form inputs work ONLY inside a FormControl within a Form; for tappable suggestion choices '
      'OUTSIDE a form, use Buttons whose Button actions are @ToAssistant, never a bare OptionCards or '
      'Chips.',
  'Only add Buttons for real actions: form submit, @OpenUrl with a URL from a tool or the user '
      '(never fabricated), or a @ToAssistant follow-up. Never add a button for an app action (open, '
      'download, export, edit) you cannot perform.',
  'Every Button label must accurately describe what clicking it does; use "primary" for the main '
      'action and "secondary"/"tertiary" only for lower-emphasis supporting actions.',
  'Icon: always include the category argument — it enables fallback matching when the exact lucide '
      'name is unavailable.',
  'Pass sources on Card ONLY when the answer relies on real references you actually have, and cite '
      'them inline in TextContent as [1], [2] (1-based index into sources).',
];
