import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_openui/stream_chat_flutter_ai_openui.dart';

import 'openui_test_app.dart';

// The example app's gallery shows these programs, so each must read without a
// problem and draw.
void main() {
  final files = Directory('example/assets/gallery').listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the gallery has examples, one with every chart type', () {
    expect(files, isNotEmpty);
    final charts = File('example/assets/gallery/06_charts.oui').readAsStringSync();
    for (final type in [
      'BarChart',
      'HorizontalBarChart',
      'LineChart',
      'AreaChart',
      'PieChart',
      'SingleStackedBarChart',
      'RadarChart',
      'RadialChart',
      'ScatterChart',
    ]) {
      expect(charts, contains('$type('));
    }
    expect(charts, contains('"semiCircular"'));
  });

  for (final file in files) {
    testWidgets('${file.uri.pathSegments.last} reads without a problem and draws', (tester) async {
      final errors = <OpenUIError>[];
      final host = AIUIHost(
        renderers: [OpenUIRenderer(onError: (error, _) => errors.add(error))],
        send: (_) async {},
      );
      addTearDown(host.dispose);
      final document = AIUIDocument(format: AIUIFormat.openUI, content: file.readAsStringSync());
      final message = _Reply(document);

      // The test font is wider than any real one, so a label that fits on a
      // device can overflow here; anything else reported is a problem.
      final problems = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed')) problems.add(details);
      };
      try {
        await tester.pumpWidget(testApp(AIConversationView(messages: [message], ui: host)));
        await tester.pump(const Duration(seconds: 1));
      } finally {
        FlutterError.onError = previous;
      }

      expect(problems, isEmpty);
      expect(errors, isEmpty);
      expect(find.byType(AIUIView), findsOneWidget);
      if (file.path.endsWith('06_charts.oui')) expect(find.byType(ChartView), findsNWidgets(10));
    });
  }
}

final class _Reply with AIMessage {
  _Reply(this.uiDocument);

  @override
  String get id => 'r1';

  @override
  AIMessageRole get role => AIMessageRole.assistant;

  @override
  String get text => '';

  @override
  final AIUIDocument uiDocument;
}
