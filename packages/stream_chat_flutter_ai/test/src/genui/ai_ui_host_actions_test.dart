import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'genui_test_doubles.dart';

void main() {
  test('AIUIHost.send gives what the person did to the app to send', () async {
    final sent = <AIUIAction>[];
    testHost(send: (action) async => sent.add(action)).send(_action('ask_about'));
    await pumpEventQueue();

    expect(sent, [_action('ask_about')]);
  });

  test('AIUIHost.send sends each action after the one before it is sent', () async {
    final events = <String>[];
    final finishFirst = Completer<void>();
    testHost(
        send: (action) async {
          events.add('start ${action.name}');
          if (action.name == 'first') await finishFirst.future;
          events.add('end ${action.name}');
        },
      )
      ..send(_action('first'))
      ..send(_action('second'));
    await pumpEventQueue();
    finishFirst.complete();
    await pumpEventQueue();

    expect(events, ['start first', 'end first', 'start second', 'end second']);
  });

  test('AIUIHost.send sends the actions after one that failed', () async {
    final sent = <String>[];
    _captureErrors();

    _failingFirst(sent)
      ..send(_action('first'))
      ..send(_action('second'));
    await pumpEventQueue();

    expect(sent, ['second']);
  });

  test('AIUIHost.send completes once the action is sent', () async {
    final sent = <AIUIAction>[];

    await testHost(send: (action) async => sent.add(action)).send(_action('ask_about'));

    expect(sent, [_action('ask_about')]);
  });

  test('AIUIHost.send completes with the error of a send that failed', () async {
    _captureErrors();

    await expectLater(_failingFirst(<String>[]).send(_action('first')), throwsStateError);
  });

  test('AIUIHost.send reports a send that failed', () async {
    final reported = _captureErrors();

    _failingFirst(<String>[]).send(_action('first'));
    await pumpEventQueue();

    expect(reported.single.exception, isA<StateError>());
  });

  test('AIUIHost.open opens links where the app says', () {
    final opened = <Uri>[];
    testHost(open: opened.add).open(Uri.parse('tel:+15550100'));

    expect(opened, [Uri.parse('tel:+15550100')]);
  });

  test('AIUIHost.open opens only web and email links by default', () async {
    final launcher = _installFakeLauncher();
    final host = testHost();
    final links = [
      'https://getstream.io',
      'HTTP://getstream.io',
      'mailto:a@b.co',
      'tel:+15550100',
      'sms:+15550100',
      'facetime:a@b.co',
      'otherapp://pay?to=x',
      'javascript:alert(1)',
      'intent://scan/#Intent;scheme=zxing;end',
      'file:///etc/hosts',
      'https:getstream.io',
      'https://',
      'https://user@',
    ];

    for (final link in links) {
      host.open(Uri.parse(link));
    }
    await pumpEventQueue();

    expect(launcher.launched, ['https://getstream.io', 'http://getstream.io', 'mailto:a@b.co']);
  });

  test('AIUIHost.open reports a link no app could open', () async {
    final reports = <String>[];
    _installFakeLauncher(opens: false, reports: reports);

    testHost().open(Uri.parse('https://getstream.io'));
    await pumpEventQueue();

    expect(reports.single, contains('No app could open https://getstream.io'));
  });

  test('AIUIHost.open opens a web link outside the app by default', () async {
    final launcher = _installFakeLauncher();

    testHost().open(Uri.parse('https://getstream.io'));
    await pumpEventQueue();

    expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
  });

  test("AIUIHost.runTool runs the app's tool on this device and completes with its output", () async {
    final tool = _ListEventsTool(
      AIClientToolResult.completed(const {
        'events': ['Dinner'],
      }),
    );
    final host = testHost(tools: [tool]);

    final output = await host.runTool('list_events', arguments: {'day': '2026-11-14'});

    expect(output, {
      'events': ['Dinner'],
    });
  });

  test('AIUIHost.runTool gives the tool a call this device runs', () async {
    final tool = _ListEventsTool(AIClientToolResult.completed(null));

    await testHost(tools: [tool]).runTool('list_events');

    expect(
      [tool.calls.single.executor, tool.calls.single.status],
      [AIToolExecutor.client, AIToolCallStatus.awaitingClient],
    );
  });

  test("AIUIHost.runTool gives the tool the UI's arguments", () async {
    final tool = _ListEventsTool(AIClientToolResult.completed(null));

    await testHost(tools: [tool]).runTool('list_events', arguments: {'day': '2026-11-14'});

    expect(tool.calls.single.arguments, {'day': '2026-11-14'});
  });

  test('AIUIHost.runTool runs the first of the tools that share a name', () async {
    final first = _ListEventsTool(AIClientToolResult.completed(null));
    final second = _ListEventsTool(AIClientToolResult.completed(null));

    await testHost(tools: [first, second]).runTool('list_events');

    expect([first.calls.length, second.calls.length], [1, 0]);
  });

  test('AIUIHost.runTool throws with the reason a tool failed', () async {
    final host = testHost(tools: [_ListEventsTool(const AIClientToolResult.failed('Calendar not shared'))]);

    await expectLater(
      host.runTool('list_events'),
      throwsA(isA<AIUIToolException>().having((error) => error.message, 'message', 'Calendar not shared')),
    );
  });

  test("AIUIHost.runTool refuses a tool that isn't read-only when the person didn't ask for it", () async {
    final host = testHost(tools: [_ListEventsTool(AIClientToolResult.completed(null), isReadOnly: false)]);

    await expectLater(host.runTool('list_events'), throwsA(isA<AIUIToolException>()));
  });

  test("AIUIHost.runTool doesn't run a tool that isn't read-only when the person didn't ask for it", () async {
    final tool = _ListEventsTool(AIClientToolResult.completed(null), isReadOnly: false);

    await expectLater(testHost(tools: [tool]).runTool('list_events'), throwsA(isA<AIUIToolException>()));

    expect(tool.calls, isEmpty);
  });

  test("AIUIHost.runTool runs a tool that isn't read-only when the person asked for it", () async {
    final tool = _ListEventsTool(AIClientToolResult.completed(null), isReadOnly: false);

    await testHost(tools: [tool]).runTool('list_events', userInitiated: true);

    expect(tool.calls, hasLength(1));
  });

  test('AIUIHost.runTool throws an AIUIToolException when the tool throws', () async {
    _captureErrors();
    final host = testHost(
      tools: [_ListEventsTool(AIClientToolResult.completed(null), throws: StateError('No calendar'))],
    );

    await expectLater(host.runTool('list_events'), throwsA(isA<AIUIToolException>()));
  });

  test('AIUIHost.runTool reports what a tool threw', () async {
    final reported = _captureErrors();
    final host = testHost(
      tools: [_ListEventsTool(AIClientToolResult.completed(null), throws: StateError('No calendar'))],
    );

    await expectLater(host.runTool('list_events'), throwsA(anything));

    expect(reported.single.exception, isA<StateError>());
  });

  test('AIUIHost.runTool throws once the host is disposed', () async {
    final tool = _ListEventsTool(AIClientToolResult.completed(null));
    final host = AIUIHost(renderers: [TestRenderer()], tools: [tool], send: (_) async {})..dispose();

    await expectLater(host.runTool('list_events'), throwsA(isA<AIUIToolException>()));
    expect(tool.calls, isEmpty);
  });

  test("AIUIHost.send doesn't send once the host is disposed", () async {
    final sent = <AIUIAction>[];
    AIUIHost(renderers: [TestRenderer()], send: (action) async => sent.add(action))
      ..dispose()
      ..send(_action('first'));
    await pumpEventQueue();

    expect(sent, isEmpty);
  });

  test('AIUIHost.runTool throws for a tool the app has not given it', () async {
    final host = testHost(tools: [_ListEventsTool(AIClientToolResult.completed(null))]);

    await expectLater(host.runTool('send_email'), throwsA(isA<AIUIToolException>()));
  });

  test("AIUIHost keeps the state a reply's UI was left in", () {
    final host = testHost()..setState('m1', {'pace': 'packed'});

    expect(host.state('m1'), {'pace': 'packed'});
  });

  test('AIUIHost.state is null for a reply whose UI kept none', () {
    final host = testHost()..setState('m1', {'pace': 'packed'});

    expect(host.state('m2'), isNull);
  });

  test("AIUIHost.setState with null forgets a reply's state", () {
    final host = testHost()
      ..setState('m1', {'pace': 'packed'})
      ..setState('m1', null);

    expect(host.state('m1'), isNull);
  });

  test("AIUIHosting.component finds the app's component by the name the agent places it by", () {
    final host = testHost(components: const [PlaceCardComponent()]);

    expect(host.component('place_card'), isA<PlaceCardComponent>());
  });

  test('AIUIHosting.component is null for a name no component has', () {
    final host = testHost(components: const [PlaceCardComponent()]);

    expect(host.component('trip_map'), isNull);
  });
}

AIUIAction _action(String name) =>
    AIUIAction(messageId: 'm1', format: AIUIFormat.openUI, name: name, label: 'Tell me more');

// A host whose send fails for the action named `first`, and adds the names of
// the others to [sent].
AIUIHost _failingFirst(List<String> sent) => testHost(
  send: (action) async {
    if (action.name == 'first') throw StateError('offline');
    sent.add(action.name);
  },
);

List<FlutterErrorDetails> _captureErrors() {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = previous);
  return reported;
}

// A tool called `list_events`, read-only unless [isReadOnly] says otherwise,
// that answers every call with [result].
class _ListEventsTool extends AIResultClientTool {
  _ListEventsTool(this.result, {this.isReadOnly = true, this.throws});

  final AIClientToolResult result;
  final bool isReadOnly;
  final Error? throws;
  final calls = <AIToolCallPart>[];

  @override
  AIToolDefinition get definition =>
      AIToolDefinition(name: 'list_events', description: 'Lists events.', isReadOnly: isReadOnly);

  @override
  Future<AIClientToolResult> run(AIToolCallPart call) async {
    calls.add(call);
    if (throws case final error?) throw error;
    return result;
  }
}

// A launcher that records the links it is asked to open, in place of the
// platform's until the test ends. Refused links are reported quietly.
_FakeUrlLauncher _installFakeLauncher({bool opens = true, List<String>? reports}) {
  final launcher = _FakeUrlLauncher(opens: opens);
  final previous = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = previous);
  debugPartIssueReporter = reports?.add ?? (_) {};
  addTearDown(() => debugPartIssueReporter = null);
  return launcher;
}

final class _FakeUrlLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  _FakeUrlLauncher({required this.opens});

  // Whether an app can open the links, as `launchUrl` answers.
  final bool opens;
  final launched = <String>[];
  final modes = <PreferredLaunchMode>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    return opens;
  }
}
