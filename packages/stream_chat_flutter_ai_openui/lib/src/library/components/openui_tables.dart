import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_theme.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_actions.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_pickers.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_strings.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds a `Table`: its `columns`, each a `Col` with a `label` and its
/// cells (`data`), side by side, ten rows a page.
///
/// A column whose `type` is `number`, or whose cells are all numbers, is
/// aligned to the end. A cell that is a component is drawn, and a missing one
/// shows `—`. The table is as wide as the space it is given, and scrolls
/// sideways when it needs more. While a query loads and there are no rows yet,
/// it shows placeholder rows.
///
/// Internal to the package.
@internal
Widget buildOpenUITable(BuildContext context, OpenUIComponentScope scope) {
  final columns = [
    for (final node in scope.elements('columns'))
      if (scope.scopeOf(node) case final column)
        _Column(
          column.text('label') ?? '',
          switch (column.prop('data')) {
            OpenUIArray(:final items) => items,
            null => const [],
            final value => [value],
          },
          column,
          declaredNumeric: column.string('type') == 'number',
        ),
  ];
  if (columns.isEmpty) return const SizedBox.shrink();
  final runtime = OpenUIViewScope.of(context).runtime;
  return ValueListenableBuilder(
    valueListenable: runtime.isQueryLoading,
    builder: (context, loading, _) {
      final rows = columns.map((column) => column.data.length).fold(0, math.max);
      if (loading && rows == 0) return _TableSkeleton(columns: math.max(columns.length, 3));
      return _OpenUITable(columns: columns, rowCount: rows);
    },
  );
}

class _Column {
  _Column(this.label, this.data, this.scope, {required bool declaredNumeric})
    : isNumeric =
          declaredNumeric || (data.isNotEmpty && data.every((value) => value is OpenUINumber || value is OpenUINull));

  final String label;
  final List<OpenUIValue> data;
  final bool isNumeric;
  final OpenUIComponentScope scope;
}

class _OpenUITable extends StatefulWidget {
  const _OpenUITable({required this.columns, required this.rowCount});

  final List<_Column> columns;
  final int rowCount;

  @override
  State<_OpenUITable> createState() => _OpenUITableState();
}

class _OpenUITableState extends State<_OpenUITable> {
  static const _pageSize = 10;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    final styles = theme.textStyles!;
    final spacing = theme.spacing!;
    final pages = math.max(1, (widget.rowCount / _pageSize).ceil());
    final page = math.min(_page, pages - 1);
    final first = page * _pageSize;
    final last = math.min(widget.rowCount, first + _pageSize);
    final cellPadding = EdgeInsets.symmetric(horizontal: spacing.m!, vertical: spacing.s! + 2);
    Widget cell(_Column column, int row) {
      final value = row < column.data.length ? column.data[row] : null;
      final align = column.isNumeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart;
      final content = switch (value) {
        OpenUIElement(:final node) => column.scope.buildNode(node),
        OpenUIArray(:final items) => Wrap(
          spacing: spacing.xs!,
          runSpacing: spacing.xs!,
          children: [
            for (final item in items)
              if (item case OpenUIElement(:final node)) column.scope.buildNode(node),
          ],
        ),
        null || OpenUINull() => Text('—', style: styles.bodySmall!.copyWith(color: colors.textTertiary)),
        _ => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            JS.stringOf(value),
            textAlign: column.isNumeric ? TextAlign.end : TextAlign.start,
            style: styles.bodySmall!.copyWith(
              color: colors.textPrimary,
              fontFeatures: column.isNumeric ? const [FontFeature.tabularFigures()] : null,
            ),
          ),
        ),
      };
      return Padding(
        padding: cellPadding,
        child: Align(alignment: align, widthFactor: 1, child: content),
      );
    }

    final table = Table(
      defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: colors.subtleFill),
          children: [
            for (final column in widget.columns)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.m!, vertical: spacing.s!),
                child: Semantics(
                  header: true,
                  child: Text(
                    column.label.toUpperCase(),
                    textAlign: column.isNumeric ? TextAlign.end : TextAlign.start,
                    style: styles.caption!.copyWith(fontWeight: FontWeight.w600, color: colors.textSecondary),
                  ),
                ),
              ),
          ],
        ),
        for (var row = first; row < last; row++)
          TableRow(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border!, width: 0.5)),
            ),
            children: [for (final column in widget.columns) cell(column, row)],
          ),
      ],
    );
    final radius = BorderRadius.circular(theme.radius!.small!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: spacing.s!,
      children: [
        // As wide as the space it is given, and scrolling when it needs more.
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth.isFinite ? constraints.maxWidth : 0),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: colors.border!, width: 0.5),
                ),
                child: ClipRRect(borderRadius: radius, child: table),
              ),
            ),
          ),
        ),
        if (pages > 1)
          _Pager(
            page: page,
            pages: pages,
            onPage: (next) => setState(() => _page = next),
          ),
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.pages, required this.onPage});

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget button(IconData icon, String label, int? target) {
      return MergeSemantics(
        child: Semantics(
          label: label,
          child: StreamButton.icon(
            icon: Icon(icon),
            size: StreamButtonSize.small,
            style: StreamButtonStyle.secondary,
            type: StreamButtonType.outline,
            onPressed: target == null ? null : () => onPage(target),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: theme.spacing!.s!,
      children: [
        button(
          rtl ? context.streamIcons.chevronRight : context.streamIcons.chevronLeft,
          OpenUIStrings.previousPage,
          page > 0 ? page - 1 : null,
        ),
        Semantics(
          container: true,
          label: OpenUIStrings.pagePositionLabel(page + 1, pages),
          excludeSemantics: true,
          child: Text(
            OpenUIStrings.pagePosition(page + 1, pages),
            style: theme.textStyles!.caption!.copyWith(
              color: theme.colors!.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        button(
          rtl ? context.streamIcons.chevronLeft : context.streamIcons.chevronRight,
          OpenUIStrings.nextPage,
          page < pages - 1 ? page + 1 : null,
        ),
      ],
    );
  }
}

class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    return Semantics(
      label: OpenUIStrings.loading,
      child: Column(
        spacing: theme.spacing!.s!,
        children: [
          for (var row = 0; row < 5; row++)
            Row(
              spacing: theme.spacing!.m!,
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: theme.colors!.sunkenSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Builds an `EditableTable`: its `data` rows, each an `id` and its `values`,
/// in cells the person can edit, under the `header` of each of its `columns`.
///
/// A column's `type` picks its editor: `text` (the default), `number`, `url`,
/// `select` (one of its `options`) or `date-single` (a day, written
/// `yyyy-MM-dd`); its `width` (48 to 600, 150 by default) sets its width,
/// and each row's `values` fill the columns in order. Once the reply has ended, the edits are counted
/// against the rows as they were: they can be reset, or saved, which keeps
/// the rows under the table's `name` and runs the action labelled
/// `Save Changes` in the form of that name. The table shows the rows saved
/// last, when there are any. It can't be edited while the reply streams.
///
/// Internal to the package.
@internal
Widget buildOpenUIEditableTable(BuildContext context, OpenUIComponentScope scope) => _OpenUIEditableTable(scope: scope);

class _EditableColumn {
  const _EditableColumn(this.type, this.key, this.header, this.width, this.options);

  final String type;
  final String key;
  final String header;
  final double width;
  final List<(String, String)> options;

  static List<_EditableColumn> of(OpenUIComponentScope scope) {
    return [
      for (final (index, column) in openUIJsonList(scope.value('columns')).whereType<Map<String, Object?>>().indexed)
        _EditableColumn(
          column['type'] is String ? column['type']! as String : 'text',
          // A row's cells are kept by column, whatever their `key`, so two
          // columns with the same key, or none, stay apart.
          '$index',
          column['header'] is String ? column['header']! as String : '',
          switch (column['width']) {
            final num width when width.isFinite => width.toDouble().clamp(48, 600),
            _ => 150,
          },
          [
            for (final option in openUIJsonList(column['options']))
              if (option case {'value': final String value})
                (value, option['label'] is String ? option['label']! as String : value),
          ],
        ),
    ];
  }
}

class _OpenUIEditableTable extends StatefulWidget {
  const _OpenUIEditableTable({required this.scope});

  final OpenUIComponentScope scope;

  @override
  State<_OpenUIEditableTable> createState() => _OpenUIEditableTableState();
}

class _OpenUIEditableTableState extends State<_OpenUIEditableTable> {
  List<Map<String, OpenUIValue>> _rows = const [];
  List<Map<String, OpenUIValue>>? _baseline;
  OpenUIValue? _source;
  List<String> _keys = const [];

  String get _name => widget.scope.text('name') ?? '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(_OpenUIEditableTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  // Reads the rows saved last, or the table's own, when they changed; the
  // edits are counted from the rows as they are once the reply ends.
  void _load() {
    final runtime = OpenUIViewScope.of(context).runtime;
    final keys = [for (final column in _EditableColumn.of(widget.scope)) column.key];
    final stored = runtime.fieldValue(_name, _name);
    final source = JS.isNullish(stored) ? widget.scope.prop('data') : stored;
    if (source != _source || !listEquals(keys, _keys)) {
      _source = source;
      _keys = keys;
      _rows = _rowsOf(source, keys);
    }
    if (_baseline == null && !widget.scope.isStreaming) {
      _baseline = [
        for (final row in _rows) {...row},
      ];
    }
  }

  static List<Map<String, OpenUIValue>> _rowsOf(OpenUIValue? source, List<String> keys) {
    return [
      for (final row in source is OpenUIArray ? source.items : const <OpenUIValue>[])
        if (row case OpenUIObject(:final fields))
          {
            'id': fields['id'] ?? const OpenUIString(''),
            for (final (index, key) in keys.indexed)
              key: switch (fields['values']) {
                OpenUIArray(:final items) when index < items.length => items[index],
                _ => const OpenUIString(''),
              },
          },
    ];
  }

  int get _changes {
    final baseline = _baseline;
    if (baseline == null) return 0;
    var count = 0;
    for (final (index, row) in _rows.indexed) {
      if (index >= baseline.length) break;
      for (final key in _keys) {
        if (row[key] != baseline[index][key]) count++;
      }
    }
    return count;
  }

  void _edit(int row, String key, OpenUIValue value) {
    setState(() {
      _rows = [
        for (final (index, each) in _rows.indexed)
          if (index == row) {...each, key: value} else each,
      ];
    });
  }

  void _save() {
    final runtime = OpenUIViewScope.of(context).runtime;
    final data = OpenUIArray([
      for (final row in _rows)
        OpenUIObject({
          'id': row['id'] ?? const OpenUIString(''),
          'values': OpenUIArray([for (final key in _keys) row[key] ?? const OpenUIString('')]),
        }),
    ]);
    runtime.setFieldValue(_name, _name, data, componentType: 'EditableTable');
    unawaited(runtime.trigger(label: OpenUIStrings.saveChanges, formName: _name));
    setState(() {
      _source = runtime.fieldValue(_name, _name);
      _baseline = [
        for (final row in _rows) {...row},
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    final styles = theme.textStyles!;
    final spacing = theme.spacing!;
    final columns = _EditableColumn.of(widget.scope);
    final enabled = !widget.scope.isStreaming;
    final changes = _changes;
    final radius = BorderRadius.circular(theme.radius!.small!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: spacing.s!,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: colors.border!, width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ColoredBox(
                    color: colors.subtleFill!,
                    child: Row(
                      children: [
                        for (final column in columns)
                          Container(
                            width: column.width,
                            padding: EdgeInsets.all(spacing.s!),
                            child: Semantics(
                              header: true,
                              child: Text(
                                column.header,
                                style: styles.caption!.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final (index, row) in _rows.indexed)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: colors.border!, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          for (final column in columns)
                            Container(
                              width: column.width,
                              padding: EdgeInsets.symmetric(horizontal: spacing.s!, vertical: spacing.xs!),
                              child: _CellEditor(
                                key: ValueKey((index, column.key)),
                                column: column,
                                value: row[column.key],
                                enabled: enabled,
                                onChanged: (value) => _edit(index, column.key, value),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (changes > 0)
          Row(
            spacing: spacing.s!,
            children: [
              Expanded(
                child: Text(
                  OpenUIStrings.changes(changes),
                  style: styles.caption!.copyWith(color: colors.textSecondary),
                ),
              ),
              StreamButton(
                size: StreamButtonSize.small,
                style: StreamButtonStyle.secondary,
                type: StreamButtonType.outline,
                onPressed: enabled
                    ? () => setState(
                        () => _rows = [
                          for (final row in _baseline!) {...row},
                        ],
                      )
                    : null,
                child: const Text(OpenUIStrings.reset),
              ),
              StreamButton(
                size: StreamButtonSize.small,
                onPressed: enabled ? _save : null,
                child: const Text(OpenUIStrings.saveChanges),
              ),
            ],
          ),
      ],
    );
  }
}

// The editor of one cell of an editable table.
class _CellEditor extends StatefulWidget {
  const _CellEditor({
    super.key,
    required this.column,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final _EditableColumn column;
  final OpenUIValue? value;
  final bool enabled;
  final ValueChanged<OpenUIValue> onChanged;

  @override
  State<_CellEditor> createState() => _CellEditorState();
}

class _CellEditorState extends State<_CellEditor> {
  late final _controller = TextEditingController(text: _text);

  String get _text => JS.isNullish(widget.value) ? '' : JS.stringOf(widget.value);

  @override
  void didUpdateWidget(_CellEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A reset or a new row puts its text back; what the person typed stays.
    if (_valueOf(_controller.text) != (widget.value ?? const OpenUIString(''))) _controller.text = _text;
  }

  // What [text] is kept as: a number in a number column when it reads as one.
  OpenUIValue _valueOf(String text) {
    if (widget.column.type != 'number') return OpenUIString(text);
    final number = JS.stringToNumber(text);
    return text.isEmpty || number.isNaN ? OpenUIString(text) : OpenUINumber(number);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = OpenUITheme.of(context);
    final colors = theme.colors!;
    final style = theme.textStyles!.bodySmall!.copyWith(color: colors.textPrimary);
    final column = widget.column;
    Widget picker(String shown, Future<void> Function() pick) {
      return OpenUIPressable(
        label: column.header,
        onTap: widget.enabled ? pick : null,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: theme.spacing!.s!),
          child: Text(shown, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    switch (column.type) {
      case 'select':
        final label = column.options.where((option) => option.$1 == _text).firstOrNull?.$2 ?? _text;
        return picker(label, () async {
          final value = await pickOpenUIOption(context, options: column.options, selected: _text);
          if (value != null && mounted) widget.onChanged(OpenUIString(value));
        });
      case 'date-single':
        return picker(_text, () async {
          final date = await pickOpenUIDate(context, initial: openUIParseDate(_text));
          if (date != null && mounted) widget.onChanged(OpenUIString(openUIDateString(date)));
        });
    }
    return StreamTextInput(
      controller: _controller,
      enabled: widget.enabled,
      hintText: column.header,
      keyboardType: switch (column.type) {
        'number' => const TextInputType.numberWithOptions(decimal: true, signed: true),
        'url' => TextInputType.url,
        _ => TextInputType.text,
      },
      onChanged: (text) => widget.onChanged(_valueOf(text)),
    );
  }
}
