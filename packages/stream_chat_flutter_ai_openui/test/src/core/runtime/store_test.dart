import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/store.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';

OpenUIValue _v(Object? json) => OpenUIValue.fromJson(json);

void main() {
  test('a default never replaces a value the user set', () {
    final store = OpenUIStore()
      ..initialize(defaults: {r'$a': _v(1)})
      ..set(r'$a', _v(2))
      ..initialize(defaults: {r'$a': _v(3)});

    expect(store.get(r'$a'), _v(2));
  });

  test('a key still holding its default follows its declaration', () {
    final store = OpenUIStore()
      ..initialize(defaults: {r'$a': _v(1)})
      ..initialize(defaults: {r'$a': _v(5)});

    expect(store.get(r'$a'), _v(5));
  });

  test('reading again without a declaration keeps the key', () {
    final store = OpenUIStore()
      ..initialize(defaults: {r'$a': _v(1)})
      ..initialize(defaults: const {});

    expect(store.get(r'$a'), _v(1));
  });

  test('restored values win over defaults', () {
    final store = OpenUIStore()..initialize(defaults: {r'$a': _v(1)}, persisted: {r'$a': _v(9)});

    expect(store.get(r'$a'), _v(9));
    store.initialize(defaults: {r'$a': _v(2)});
    expect(store.get(r'$a'), _v(9));
  });

  test('a pristine value follows its declaration again', () {
    final store = OpenUIStore()
      ..initialize(defaults: {r'$a': _v(1)})
      ..set(r'$a', _v(2))
      ..set(r'$a', _v(1), pristine: true)
      ..initialize(defaults: {r'$a': _v(3)});

    expect(store.get(r'$a'), _v(3));
  });

  test('reports each changed key, and nothing for an equal value', () {
    final changed = <String>[];
    OpenUIStore(onChange: changed.add)
      ..set(r'$a', _v(1))
      ..set(r'$a', _v(1))
      ..initialize(defaults: {r'$a': _v(1), r'$b': _v(2)});

    expect(changed, [r'$a', r'$b']);
  });

  test('withoutSecrets drops secret fields at any depth', () {
    final value = _v({
      'login': {
        'user': {'value': 'ada', 'componentType': 'input'},
        'password': {'value': 'x', 'componentType': 'input', 'secret': true},
        'list': [
          {'value': 'y', 'secret': true},
          1,
        ],
      },
    });

    expect(
      OpenUIStore.withoutSecrets(value),
      _v({
        'login': {
          'user': {'value': 'ada', 'componentType': 'input'},
          'list': [1],
        },
      }),
    );
  });
}
