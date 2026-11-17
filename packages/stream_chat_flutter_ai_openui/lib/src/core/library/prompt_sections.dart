/// The fixed text of a system prompt's sections.
///
/// Internal to the package.
@internal
library;

import 'package:meta/meta.dart';

/// The fixed text of a system prompt's sections, some with parts filled in.
abstract final class PromptSections {
  /// The section listing the built-in functions, `lines`, to use on `target`.
  static String builtinFunctions({required String target, required String lines}) {
    return '## Built-in Functions\n'
        '\n'
        'Data functions prefixed with `@` to distinguish from components. These are the ONLY functions '
        'available — do NOT invent new ones.\n'
        'Use @-prefixed built-in functions (@Count, @Sum, @Avg, @Min, @Max, @Round) on $target. Do '
        'NOT hardcode computed values.\n'
        '\n'
        '$lines\n'
        '\n'
        'Builtins compose — output of one is input to the next:\n'
        '`@Count(@Filter(data.rows, "field", "==", "val"))` for KPIs/chart values, '
        '`@Round(@Avg(data.rows.score), 1)`, `@Each(data.rows, "item", Comp(item.field))` for per-item '
        'rendering.\n'
        'Array pluck: `data.rows.field` extracts a field from every row → use with @Sum, @Avg, charts, '
        'tables.\n'
        '\n'
        'IMPORTANT @Each rule: The loop variable (e.g. "item") is ONLY available inside the @Each '
        'template expression. Always inline the template — do NOT extract it to a separate statement.\n'
        'CORRECT: `list = @Each(rows, "t", Comp(t.name))`\n'
        'WRONG: `item = Comp(t.name)` then `list = @Each(rows, "t", item)`, because t is undefined in '
        'item.';
  }

  /// The section on `Query()`.
  static const query =
      '## Query — Live Data Fetching\n'
      '\n'
      'Fetch data from available tools. Returns defaults instantly, swaps in real data when it '
      'arrives.\n'
      '\n'
      '```\n'
      r'metrics = Query("tool_name", {arg1: value, arg2: $binding}, {defaultField: 0, defaultData: []}, '
      'refreshInterval?)\n'
      '```\n'
      '\n'
      '- First arg: tool name (string)\n'
      '- Second arg: arguments object (may reference \$bindings — re-fetches automatically on change)\n'
      '- Third arg: default data (rendered immediately before fetch resolves)\n'
      '- Fourth arg (optional): refresh interval in seconds (e.g. 30 for auto-refresh every 30s)\n'
      '- Use dot access on results: metrics.totalEvents, metrics.data.day (array pluck)\n'
      r'- Query results must use regular identifiers: `metrics = Query(...)`, NOT `$metrics = '
      'Query(...)`\n'
      '- Manual refresh: `Button("Refresh", Action([@Run(query1), @Run(query2)]), "secondary")` — '
      're-fetches the listed queries\n'
      '- Refresh all queries: create Action with @Run for each query';

  /// The section on `Mutation()`.
  static const mutation =
      '## Mutation — Write Operations\n'
      '\n'
      'Execute state-changing tool calls (create, update, delete). Unlike Query (auto-fetches on '
      'render), Mutation fires only on button click via Action.\n'
      '\n'
      '```\n'
      'result = Mutation("tool_name", {arg1: \$binding, arg2: "value"})\n'
      '```\n'
      '\n'
      '- First arg: tool name (string)\n'
      '- Second arg: arguments object (evaluated with current \$binding values at click time)\n'
      '- result.status: "idle" | "loading" | "success" | "error"\n'
      '- result.data: tool response on success\n'
      '- result.error: error message on failure\n'
      '- Mutation results use regular identifiers: `result = Mutation(...)`, NOT `\$result`\n'
      '- Show loading state: `result.status == "loading" ? TextContent("Saving...") : null`';

  /// The action example that runs a mutation, refreshes a query and resets a
  /// binding.
  static const actionMutationExample =
      'Example — mutation + refresh + reset (PREFERRED pattern):\n'
      '```\n'
      '\$binding = "default"\n'
      'result = Mutation("tool_name", {field: \$binding})\n'
      'data = Query("tool_name", {}, {rows: []})\n'
      'onSubmit = Action([@Run(result), @Run(data), @Reset(\$binding)])\n'
      '```';

  /// The action example that opens a link.
  static const actionNavExample =
      'Example — simple nav:\n'
      '```\n'
      'viewBtn = Button("View", @OpenUrl("https://example.com"))\n'
      '```';

  /// The section on actions, with its `steps`, `examples` and `rules`.
  static String action({required String steps, required String examples, required String rules}) {
    return '## Action — Button Behavior\n'
        '\n'
        'An action wires a button click to operations. Pass one @-prefixed step bare, e.g. Button("Ask", '
        '@ToAssistant("Tell me more")). Put several steps in Action([...]), e.g. Button("Read", '
        'Action([@OpenUrl("https://example.com"), @ToAssistant("Summarize this page")])). Steps execute '
        'in order.\n'
        'Buttons without an action automatically send their label to the assistant (equivalent to '
        '@ToAssistant(label)).\n'
        '\n'
        'Available steps:\n'
        '$steps\n'
        '\n'
        '$examples\n'
        '\n'
        '$rules';
  }

  /// The sections on filters bound to queries, and on forms.
  static const interactiveFilters =
      '## Interactive Filters\n'
      '\n'
      'To let the user filter data with a dropdown:\n'
      '1. Declare a \$variable with a default: `\$dateRange = "14"`\n'
      '2. Create a Select with name, items, and binding: `Select("dateRange", [SelectItem("7", "Last 7 '
      'days"), ...], null, null, \$dateRange)`\n'
      '3. Wrap in FormControl for a label: `FormControl("Date Range", Select(...))`\n'
      '4. Pass \$dateRange in Query args: `Query("tool", {dateRange: \$dateRange}, {defaults})`\n'
      '5. When the user changes the Select, \$dateRange updates and the Query automatically re-fetches\n'
      '\n'
      r'FILTER WIRING RULE: If a $binding filter is visible in the UI, EVERY relevant Query MUST '
      r'reference that $binding in its args. Never show a filter dropdown while hardcoding the query '
      'args.\n'
      '\n'
      'Rules for \$variables:\n'
      '- \$variables hold simple values (strings or numbers), NOT arrays or objects\n'
      r'- $variables must be bound to a Select/Input component via the value argument (last positional '
      'arg) to be interactive\n'
      r'- Queries must use regular identifiers (NOT $variables): `metrics = Query(...)` not `$metrics = '
      'Query(...)`\n'
      r'- **Auto-declare**: You do NOT need to explicitly declare $variables. If you use `$foo` without '
      r'declaring it, the parser auto-creates `$foo = null`. You can still declare explicitly to set a '
      'default: `\$days = "14"`\n'
      '\n'
      '## Forms\n'
      '\n'
      r'Simple form — no $bindings needed. Field values are managed internally by the Form via the name '
      'prop:\n'
      '```\n'
      'contactForm = Form("contact", submitBtn, [nameField, emailField])\n'
      'nameField = FormControl("Name", Input("name", "Your name", "text", {required: true}))\n'
      'emailField = FormControl("Email", Input("email", "your@email.com", "email", {required: true, '
      'email: true}))\n'
      'submitBtn = Button("Submit")\n'
      '```\n'
      '\n'
      r'Use $bindings when you need to read field values elsewhere (in Action context, Query args, or '
      'conditionals). They are auto-declared:\n'
      '```\n'
      '\$role = "engineer"\n'
      'contactForm = Form("contact", submitBtn, [nameField, emailField, roleField])\n'
      'nameField = FormControl("Name", Input("name", "Enter your name", "text", {required: true}, '
      '\$name))\n'
      'emailField = FormControl("Email", Input("email", "Enter your email", "email", {required: true, '
      'email: true}, \$email))\n'
      'roleField = FormControl("Role", Select("role", [SelectItem("engineer", "Engineer"), '
      'SelectItem("designer", "Designer"), SelectItem("pm", "PM")], null, {required: true}, \$role))\n'
      'submitBtn = Button("Submit")\n'
      '```\n'
      '\n'
      'For form + mutation patterns (create, refresh, reset), see the Action section example above.\n'
      '\n'
      'IMPORTANT: Always add validation rules to form fields used with Mutations. Use OBJECT syntax: '
      '{required: true, email: true, minLength: 8}. The renderer shows error messages automatically '
      'and blocks submit when validation fails.';

  /// The section on answering with only the statements that change.
  static const editMode =
      '## Edit Mode\n'
      '\n'
      'The runtime merges by statement name: same name = replace, new name = append.\n'
      'Output ONLY statements that changed or are new. Everything else is kept automatically.\n'
      '\n'
      '### Delete\n'
      "To remove a component, re-declare its parent without that component in the parent's children "
      'array. The removed component and any statements only it referenced are automatically '
      'garbage-collected.\n'
      '\n'
      '### Patch size guide\n'
      '- Changing a title or label: 1 statement\n'
      '- Adding a component: 2-3 statements (the new component + parent update)\n'
      '- Removing a component: 1 statement (re-declare parent without the removed child)\n'
      '- Adding a filter + wiring to query: 3-5 statements\n'
      '- Restructuring into tabs: 5-10 statements\n'
      '\n'
      '### Rules\n'
      '- Reuse existing statement names exactly — do not rename\n'
      '- Do NOT re-emit unchanged statements — the runtime keeps them\n'
      '- A typical edit patch is 1-10 statements, not 20+\n'
      '- If the existing code already satisfies the request, output only the root statement\n'
      '- NEVER output the entire program as a patch. Only output what actually changes\n'
      '- If you are about to output more than 10 statements, reconsider — most edits need fewer';

  /// The section on statement order while streaming, with its `steps`, for a
  /// root of `rootName`.
  static String streaming({required String steps, required String rootName}) {
    return '## Hoisting & Streaming (CRITICAL)\n'
        '\n'
        'openui-lang supports hoisting: a reference can be used BEFORE it is defined. The parser '
        'resolves all references after the full input is parsed.\n'
        '\n'
        'During streaming, the output is re-parsed on every chunk. Undefined references are temporarily '
        'unresolved and appear once their definitions stream in. This creates a progressive top-down '
        'reveal — structure first, then data fills in.\n'
        '\n'
        '**Recommended statement order for optimal streaming:**\n'
        '$steps\n'
        '\n'
        'Always write the root = $rootName(...) statement first so the UI shell appears immediately, '
        'even before child data has streamed in.';
  }

  /// The section on answering in text with fenced programs.
  static const inlineMode =
      '## Inline Mode\n'
      '\n'
      'You are in inline mode. You can respond in two ways:\n'
      '\n'
      '### 1. Code response (when the user wants to CREATE or CHANGE the UI)\n'
      'Wrap openui-lang code in triple-backtick fences. You can include explanatory text before/after:\n'
      '\n'
      "Here's your dashboard:\n"
      '\n'
      '```openui-lang\n'
      'root = RootComp([header, content])\n'
      'header = SomeHeader("Title")\n'
      'content = SomeContent("Hello world")\n'
      '```\n'
      '\n'
      'I created a simple layout with a header.\n'
      '\n'
      '### 2. Text-only response (when the user asks a QUESTION)\n'
      'If the user asks "what is this?", "explain the chart", "how does this work", etc. — respond '
      'with plain text. Do NOT output any openui-lang code. The existing dashboard stays unchanged.\n'
      '\n'
      '### Rules\n'
      '- When the user asks for changes, output ONLY the changed/new statements in a fenced block\n'
      '- When the user asks a question, respond with text only — NO code. The dashboard stays '
      'unchanged.\n'
      '- The parser extracts code from fences automatically. Text outside fences is shown as chat.';

  /// The section on using tools instead of writing their results out.
  static const toolWorkflow =
      '## Data Workflow\n'
      '\n'
      'When tools are available, follow this workflow:\n'
      '1. FIRST: Call the most relevant tool to inspect the real data shape before generating code\n'
      '2. Use Query() for READ operations (data that should stay live) — NEVER hardcode tool results '
      'as literal arrays or objects\n'
      '3. Use Mutation() for WRITE operations (create, update, delete) — triggered by button clicks '
      'via @Run(mutationRef)\n'
      '4. Use the real data from step 1 as condensed Query defaults (3-5 rows) so the UI renders '
      'immediately\n'
      '5. Use @-prefixed builtins (@Count, @Filter, @Sort, @Sum) on Query results for KPIs and '
      'aggregations — the runtime evaluates these live on every refresh\n'
      '6. Hardcoded arrays are ONLY for static display data (labels, options) where no tool exists\n'
      '\n'
      'WRONG — you called a tool and got data back, but you inlined the results:\n'
      '```\n'
      'openCount = 2\n'
      'item1 = SomeComp("first item title")\n'
      'item2 = SomeComp("second item title")\n'
      'list = SomeList([item1, item2])\n'
      'chart = SomeChart(["A", "B"], [12, 8])\n'
      '```\n'
      "This is static — it shows stale data and won't update. Creating item1, item2, item3... manually "
      'is ALWAYS wrong when a tool exists.\n'
      '\n'
      'RIGHT — use Query() for live data, Mutation() for writes, @builtins to derive values:\n'
      '```\n'
      'data = Query("tool_name", {}, {rows: []})\n'
      'openCount = @Count(@Filter(data.rows, "field", "==", "value"))\n'
      'list = @Each(data.rows, "item", SomeComp(item.title, item.field))\n'
      'createResult = Mutation("create_tool", {title: \$title})\n'
      'submitBtn = Button("Create", Action([@Run(createResult), @Run(data), @Reset(\$title)]))\n'
      '```\n'
      'Everything derives from the Query — when data refreshes, the entire dashboard updates '
      'automatically.';

  /// The closing rules, with the checks of `verifyLines`.
  static String importantRules({required String verifyLines}) {
    return '## Important Rules\n'
        '- Choose components that best represent the content (tables for comparisons, charts for trends, '
        'forms for input, etc.)\n'
        '\n'
        '## Final Verification\n'
        'Before finishing, walk your output and verify:\n'
        '$verifyLines';
  }
}
