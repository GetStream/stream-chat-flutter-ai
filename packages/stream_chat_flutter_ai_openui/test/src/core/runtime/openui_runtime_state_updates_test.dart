import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_runtime.dart';

import 'spec_runtime.dart';

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);

const _program =
    r'$name = "X"'
    '\nroot = Stack([Input("n", "N", \$name)])';

OpenUIRuntime _runtime({Map<String, Object?>? initialState}) => OpenUIRuntime(
  schema: specSchema,
  isBindable: specBindable,
  initialState: initialState,
);

OpenUIValue? _input(OpenUIRuntime runtime) {
  final children = runtime.root.value!.props['children']! as OpenUIArray;
  return (children.items.first as OpenUIElement).node.props['value'];
}

void main() {
  test('declared defaults are no update, while the reply streams or once it ends', () {
    final runtime = _runtime();
    final updates = <Map<String, OpenUIValue>>[];
    runtime.stateUpdates.listen(updates.add);
    runtime
      ..update(r'$name = "X', isStreaming: true)
      ..update(_program, isStreaming: true)
      ..update(_program.replaceFirst('"X"', '"Y"'), isStreaming: false);

    expect(runtime.state.value, {r'$name': _v('Y')});
    expect(updates, isEmpty);
    runtime.dispose();
  });

  test('kept state applied by the constructor or restore is no update', () {
    final runtime = _runtime(initialState: {r'$name': 'A'});
    final updates = <Map<String, OpenUIValue>>[];
    runtime.stateUpdates.listen(updates.add);
    runtime
      ..update(_program, isStreaming: false)
      ..restore({r'$name': 'B'});

    expect(runtime.state.value, {r'$name': _v('B')});
    expect(updates, isEmpty);
    runtime.dispose();
  });

  test('what the person enters is an update with the whole state', () {
    final runtime = _runtime()..update('\$other = 1\n$_program', isStreaming: false);
    final updates = <Map<String, OpenUIValue>>[];
    runtime.stateUpdates.listen(updates.add);
    runtime.stateField('n', binding: _input(runtime)).set(_v('typed'));

    expect(updates, [
      {r'$other': _v(1), r'$name': _v('typed')},
    ]);
    runtime.dispose();
  });
}
