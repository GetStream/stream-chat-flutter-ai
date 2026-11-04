import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/chart/chart_view.dart';
import 'package:stream_chat_flutter_ai/src/chart/uspec.dart';

// Hosts such as a chat bubble sized with `IntrinsicWidth`, or a `Table`, ask
// their children for an intrinsic size before laying them out.
void main() {
  for (final MapEntry(key: name, value: spec) in _cases.entries) {
    testWidgets('$name sits in an IntrinsicWidth without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: IntrinsicWidth(child: ChartView(spec: spec)),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }
}

const _parts = [
  USeries(
    name: 'Share',
    points: [
      UPoint(x: 'A', y: 3),
      UPoint(x: 'B', y: 2),
      UPoint(x: 'C', y: 1),
    ],
  ),
];

const _cases = {
  'a pie': USpec(kind: USpecKind.pie, series: _parts),
  'a donut': USpec(kind: USpecKind.pie, donut: true, series: _parts),
  'a semicircle': USpec(kind: USpecKind.pie, semicircle: true, series: _parts),
  'a radar': USpec(kind: USpecKind.radar, series: _parts),
  'a radial chart': USpec(kind: USpecKind.radial, series: _parts),
  'a single stacked bar': USpec(kind: USpecKind.singleStackedBar, series: _parts),
};
