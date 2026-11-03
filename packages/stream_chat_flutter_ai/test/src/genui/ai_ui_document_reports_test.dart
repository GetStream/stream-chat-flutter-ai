import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_document.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

import 'genui_fixtures.dart';

void main() {
  test('AIUIDocument.fromCustomData reports an ai_ui field that is not an object', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(const {'ai_ui': 'root = Card([])'});

    expect(reports.single, contains('`ai_ui` is not an object'));
  });

  test('AIUIDocument.fromCustomData reports a document without a format', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(_customData(const {'content': 'root = Card([])'}));

    expect(reports.single, contains('`ai_ui` has no `format`'));
  });

  test('AIUIDocument.fromCustomData reports a document without content', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(_customData(const {'format': 'openui'}));

    expect(reports.single, contains('`ai_ui` has no `content`'));
  });

  test('AIUIDocument.fromCustomData reports a format that is not a string, and the missing format it leaves', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(_customData(const {'format': 1, 'content': 'root = Card([])'}));

    expect(reports, [contains('ignored `format`'), contains('has no `format`')]);
  });

  test('AIUIDocument.fromCustomData reports a version that is not a string', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(_customData(const {'format': 'openui', 'version': 1, 'content': 'root = Card([])'}));

    expect(reports.single, contains('ignored `version`'));
  });

  test('AIUIDocument.fromCustomData reports a status that is not a string', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(_customData(const {'format': 'openui', 'status': true, 'content': 'root = Card([])'}));

    expect(reports.single, contains('ignored `status`'));
  });

  test('AIUIDocument.fromCustomData says nothing about a message without an ai_ui field', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(const {'generating': true});

    expect(reports, isEmpty);
  });

  test('AIUIDocument.fromCustomData says nothing about an ai_ui field newer than it reads', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(_customData(const {'v': 2, 'content': 'root = Card([])'}));

    expect(reports, isEmpty);
  });

  test('AIUIDocument.fromCustomData says nothing about a document it reads', () {
    final reports = _captureReports();

    AIUIDocument.fromCustomData(genuiFixture('document_openui_streaming.json'));

    expect(reports, isEmpty);
  });
}

// Captures what the package reports in debug builds, until the test ends.
List<String> _captureReports() {
  final reports = <String>[];
  debugPartIssueReporter = reports.add;
  addTearDown(() => debugPartIssueReporter = null);
  return reports;
}

Map<String, Object?> _customData(Map<String, Object?> document) => {AIUIDocument.customDataKey: document};
