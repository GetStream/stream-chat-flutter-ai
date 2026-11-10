import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/statement_merger.dart';

// The cases of iOS's and Android's own merge tests, and of what the merge's
// doc says; the specification's editing fixtures run in the conformance suite.
const _original = '''
root = Stack([header, tbl])
header = CardHeader("Tickets")
tickets = Query("list_tickets", {}, {rows: []})
tbl = Table([Col("Title", tickets.rows.title), Col("Status", tickets.rows.status)])''';

void main() {
  test('a patch replaces the statement of the same name and adds new ones at the end', () {
    const patch = '''
root = Stack([header, chart, tbl])
chart = PieChart(["Open", "Closed"], [@Count(@Filter(tickets.rows, "status", "==", "open")), @Count(@Filter(tickets.rows, "status", "==", "closed"))], "donut")''';

    final lines = StatementMerger.merge(_original, patch).split('\n');

    expect(lines, hasLength(5));
    expect(lines[0], 'root = Stack([header, chart, tbl])');
    expect(lines[1], 'header = CardHeader("Tickets")');
    expect(lines[4], startsWith('chart = PieChart('));
  });

  test('a replaced statement keeps its place', () {
    final merged = StatementMerger.merge('root = Stack([a, b])\na = 1\nb = 2', 'a = 3');

    expect(merged, 'root = Stack([a, b])\na = 3\nb = 2');
  });

  test('statements the root no longer reaches are dropped, and state variables are kept', () {
    final merged = StatementMerger.merge(
      '$_original\n\$filter = "open"',
      '```openui-lang\nroot = Stack([header])\n```',
    );

    expect(merged, 'root = Stack([header])\nheader = CardHeader("Tickets")\n\$filter = "open"');
  });

  test('a statement reached only through a query or mutation reference is kept', () {
    final merged = StatementMerger.merge(
      'root = Stack([Button("Go", Action([@Run(save)]))])\nsave = Mutation("save", {})\nunused = 1',
      'root = Stack([Button("Go", Action([@Run(save)]))])\nextra = 2',
    );

    expect(merged, 'root = Stack([Button("Go", Action([@Run(save)]))])\nsave = Mutation("save", {})');
  });

  test('name = null deletes a statement, and one that was not there changes nothing', () {
    expect(StatementMerger.merge('root = Stack([a, b])\na = 1\nb = 2', 'b = null'), 'root = Stack([a, b])\na = 1');
    expect(StatementMerger.merge('root = Stack([a])\na = 1', 'zzz = null'), 'root = Stack([a])\na = 1');
  });

  test('without a root statement nothing is dropped', () {
    expect(StatementMerger.merge('page = Stack([a])\na = 1\nx = 2', 'x = 3'), 'page = Stack([a])\na = 1\nx = 3');
  });

  test('another root name is measured from', () {
    expect(
      StatementMerger.merge('page = Stack([a])\na = 1\nx = 2', 'a = 4', rootId: 'page'),
      'page = Stack([a])\na = 4',
    );
  });

  test('only the fenced part of a reply is merged', () {
    const patch = 'Sure!\n```openui\na = Text("A2")\n```\nAnything else?';

    expect(StatementMerger.merge('root = Stack([a])\na = Text("A")', patch), 'root = Stack([a])\na = Text("A2")');
  });

  test('a statement over several lines, or with a line break in a string, stays one statement', () {
    final merged = StatementMerger.merge(
      'root = Stack([a])\na = Text("x")',
      'a = Text(\n  "one\ntwo"\n)',
    );

    expect(merged, 'root = Stack([a])\na = Text(\n  "one\ntwo"\n)');
  });

  test('a name defined twice is written once, as its last definition, where it first appears', () {
    // The specification: "The merged program has each name once: the last definition wins".
    expect(
      StatementMerger.merge('root = Stack([a])\na = 1\nb = 5\na = 2', 'root = Stack([a, b])'),
      'root = Stack([a, b])\na = 2\nb = 5',
    );
  });

  test('an empty program gives the patch, and an empty patch the program', () {
    expect(StatementMerger.merge('', 'root = Stack([])'), 'root = Stack([])');
    expect(StatementMerger.merge(_original, '   '), _original);
  });
}
