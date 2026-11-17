import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';

import '../../../conformance/openui_conformance.dart';
import 'fake_timers.dart';
import 'fake_tools.dart';

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);

void main() {
  late FakeTools tools;
  late OpenUIRuntime runtime;

  setUp(() {
    tools = FakeTools();
    runtime = OpenUIRuntime(
      schema: conformanceLibraries()['spec']!,
      isBindable: conformanceBindables('spec'),
      tools: tools,
      timer: FakeTimers().call,
    );
  });

  tearDown(() => runtime.dispose());

  test('a link written in the program is allowed', () {
    runtime.update('root = Stack([Text(logo)])\nlogo = "https://cdn.example/logo.png"', isStreaming: false);

    expect(runtime.allowsImageLink('https://cdn.example/logo.png'), isTrue);
  });

  test(r'a link built from a $variable the person typed in is refused', () {
    runtime.update(
      r'$typed = ""'
      '\nroot = Stack([Input("q", "Q", \$typed), Text("https://cdn.example/p?q=" + \$typed)])',
      isStreaming: false,
    );
    ElementNode child(int index) {
      return ((runtime.root.value!.props['children']! as OpenUIArray).items[index] as OpenUIElement).node;
    }

    runtime.stateField('q', binding: child(0).props['value']).set(_v('hunter2'));
    final link = (child(1).props['text']! as OpenUIString).value;

    expect(link, 'https://cdn.example/p?q=hunter2');
    expect(runtime.allowsImageLink(link), isFalse);
  });

  test('a link a query gave is allowed', () async {
    tools.results['photos'] = _v({
      'items': [
        {'url': 'https://cdn.example/tool.png'},
      ],
    });
    runtime.update('root = Stack([Text("x")])\nq = Query("photos", {}, null)', isStreaming: false);
    expect(runtime.allowsImageLink('https://cdn.example/tool.png'), isFalse);
    await pumpMicrotasks();

    expect(runtime.allowsImageLink('https://cdn.example/tool.png'), isTrue);
    expect(runtime.allowsImageLink('https://cdn.example/other.png'), isFalse);
  });

  test("a link in a query's defaults, built from what the person typed, is refused", () async {
    runtime.update(
      r'$typed = ""'
      '\nroot = Stack([Input("q", "Q", \$typed), Text(p.src)])'
      '\np = Query("pics", {}, {src: "https://a.dev/x.png?q=" + \$typed})',
      isStreaming: false,
    );
    final input = (runtime.root.value!.props['children']! as OpenUIArray).items.first as OpenUIElement;
    runtime.stateField('q', binding: input.node.props['value']).set(_v('cat'));
    await pumpMicrotasks();

    expect(tools.calls.single.name, 'pics');
    expect(runtime.allowsImageLink('https://a.dev/x.png?q=cat'), isFalse);
  });

  test('a link a mutation gave is allowed', () async {
    tools.results['save'] = _v({'url': 'https://cdn.example/saved.png'});
    runtime.update(
      'root = Stack([Button("Save", Action([@Run(m)]))])\nm = Mutation("save", {})',
      isStreaming: false,
    );
    expect(runtime.allowsImageLink('https://cdn.example/saved.png'), isFalse);

    final button = (runtime.root.value!.props['children']! as OpenUIArray).items.single as OpenUIElement;
    await runtime.trigger(label: 'Save', action: button.node.props['action']);
    await pumpMicrotasks();

    expect(runtime.allowsImageLink('https://cdn.example/saved.png'), isTrue);
  });

  test('an empty link is refused', () {
    runtime.update('root = Stack([Text("")])', isStreaming: false);

    expect(runtime.allowsImageLink(''), isFalse);
  });
}
