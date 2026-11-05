import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'genui_fixtures.dart';
import 'genui_test_doubles.dart';

void main() {
  testWidgets('AIUIComponent.view shows the component for arguments that fit its parameters', (tester) async {
    final view = const PlaceCardComponent().view(genuiFixture('arguments_place_card.json'), _context());

    await tester.pumpWidget(view!);

    expect(find.text('St. Naum'), findsOneWidget);
  });

  test('AIUIComponent.view is null while the arguments still streaming in do not fit', () {
    expect(const PlaceCardComponent().view({}, _context(isStreaming: true)), isNull);
  });

  test("AIUIComponent.view doesn't report arguments that don't fit while they stream in", () {
    final reports = _captureReports();

    const PlaceCardComponent().view({}, _context(isStreaming: true));

    expect(reports, isEmpty);
  });

  test("AIUIComponent.view reports arguments that still don't fit once the UI is written", () {
    final reports = _captureReports();

    const PlaceCardComponent().view({'title': 3}, _context());

    expect(reports.single, contains('"place_card"'));
  });

  test('AIUIComponent.view brings the component in as it shows', () {
    final view = const PlaceCardComponent().view({'title': 'Ohrid'}, _context());

    expect(view, isA<AIUIEntrance>());
  });

  test('AIUIComponent.name is the name of its definition', () {
    expect(const PlaceCardComponent().name, 'place_card');
  });

  test('AIUIComponentContext.emit gives its emitter the event and what the person did', () {
    final emitted = <(String, String)>[];

    _context(
      emit: (event, label, _) async => emitted.add((event, label)),
    ).emit('ask_about', label: 'Tell me more about Ohrid', payload: {'title': 'Ohrid'});

    expect(emitted, [('ask_about', 'Tell me more about Ohrid')]);
  });

  test("AIUIComponentContext.emit gives its emitter the event's payload", () {
    final payloads = <Map<String, Object?>>[];

    _context(
      emit: (_, _, payload) async => payloads.add(payload),
    ).emit('ask_about', label: 'Tell me more about Ohrid', payload: {'title': 'Ohrid'});

    expect(payloads, [
      {'title': 'Ohrid'},
    ]);
  });

  test('AIUIComponentContext.emit gives an empty payload when the component gives none', () {
    final payloads = <Map<String, Object?>>[];

    _context(emit: (_, _, payload) async => payloads.add(payload)).emit('ask_about', label: 'Tell me more about Ohrid');

    expect(payloads, [<String, Object?>{}]);
  });
}

AIUIComponentContext _context({bool isStreaming = false, AIUIEventEmitter? emit}) => AIUIComponentContext(
  messageId: 'm1',
  isStreaming: isStreaming,
  host: testHost(components: const [PlaceCardComponent()]),
  emit: emit ?? (_, _, _) async {},
);

List<String> _captureReports() {
  final reports = <String>[];
  debugPartIssueReporter = reports.add;
  addTearDown(() => debugPartIssueReporter = null);
  return reports;
}
