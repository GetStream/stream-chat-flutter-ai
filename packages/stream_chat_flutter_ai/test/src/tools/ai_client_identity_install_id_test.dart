import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_identity.dart';

void main() {
  test('installId creates an id around a random UUID', () async {
    _usePreferences(InMemorySharedPreferencesAsync.empty());

    final id = await AIClientIdentity.installId();

    expect(id, contains(RegExp('[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}')));
  });

  test('installId returns the same id on later calls', () async {
    _usePreferences(InMemorySharedPreferencesAsync.empty());

    final first = await AIClientIdentity.installId();
    final second = await AIClientIdentity.installId();

    expect(second, first);
  });

  test('installId returns the same id to calls racing the first one', () async {
    _usePreferences(InMemorySharedPreferencesAsync.empty());

    final ids = await Future.wait([AIClientIdentity.installId(), AIClientIdentity.installId()]);

    expect(ids[1], ids[0]);
  });

  test('installId returns the id kept by an earlier launch', () async {
    _usePreferences(
      InMemorySharedPreferencesAsync.withData({'io.getstream.ai.client-id': 'flutter-0B8A1D5E-KEPT'}),
    );

    final id = await AIClientIdentity.installId();

    expect(id, 'flutter-0B8A1D5E-KEPT');
  });

  for (final blank in ['', '  ']) {
    test('installId replaces a blank stored id (${jsonEncode(blank)})', () async {
      _usePreferences(InMemorySharedPreferencesAsync.withData({'io.getstream.ai.client-id': blank}));

      final id = await AIClientIdentity.installId();

      expect(id.trim(), isNotEmpty);
      expect(await AIClientIdentity.installId(), id);
    });
  }

  test('installId keeps the id in its own Android preferences file', () async {
    final preferences = _RecordingPreferences();
    _usePreferences(preferences);

    await AIClientIdentity.installId();

    expect(
      preferences.options,
      everyElement(
        isA<SharedPreferencesAsyncAndroidOptions>()
            .having((it) => it.backend, 'backend', SharedPreferencesAndroidBackendLibrary.SharedPreferences)
            .having(
              (it) => it.originalSharedPreferencesOptions?.fileName,
              'fileName',
              'io.getstream.ai.client-id',
            ),
      ),
    );
  });

  test('installId completes with the error when the id cannot be read', () async {
    _usePreferences(_FailingReadOncePreferences());

    await expectLater(AIClientIdentity.installId(), throwsA(isA<StateError>()));
  });

  test('installId completes with the error when the id cannot be stored', () async {
    _usePreferences(_FailingWriteOncePreferences());

    await expectLater(AIClientIdentity.installId(), throwsA(isA<StateError>()));
  });

  test('installId tries again after a failed read', () async {
    _usePreferences(_FailingReadOncePreferences());
    await expectLater(AIClientIdentity.installId(), throwsStateError);

    final id = await AIClientIdentity.installId();

    expect(await AIClientIdentity.installId(), id);
  });

  test('installId tries again after a failed write', () async {
    _usePreferences(_FailingWriteOncePreferences());
    await expectLater(AIClientIdentity.installId(), throwsStateError);

    final id = await AIClientIdentity.installId();

    expect(await AIClientIdentity.installId(), id);
  });
}

void _usePreferences(SharedPreferencesAsyncPlatform preferences) {
  final original = SharedPreferencesAsyncPlatform.instance;
  SharedPreferencesAsyncPlatform.instance = preferences;
  addTearDown(() => SharedPreferencesAsyncPlatform.instance = original);
}

// Records the options of every read and write, to check where the id lands.
final class _RecordingPreferences extends InMemorySharedPreferencesAsync {
  _RecordingPreferences() : super.empty();

  final options = <SharedPreferencesOptions>[];

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) {
    this.options.add(options);
    return super.getString(key, options);
  }

  @override
  Future<bool> setString(String key, String value, SharedPreferencesOptions options) {
    this.options.add(options);
    return super.setString(key, value, options);
  }
}

// Fails the first read, as a platform error would, then behaves normally.
final class _FailingReadOncePreferences extends InMemorySharedPreferencesAsync {
  _FailingReadOncePreferences() : super.empty();

  var _failed = false;

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) async {
    if (!_failed) {
      _failed = true;
      throw StateError('storage unavailable');
    }
    return super.getString(key, options);
  }
}

// Fails the first write, as a platform error would, then behaves normally.
final class _FailingWriteOncePreferences extends InMemorySharedPreferencesAsync {
  _FailingWriteOncePreferences() : super.empty();

  var _failed = false;

  @override
  Future<bool> setString(String key, String value, SharedPreferencesOptions options) async {
    if (!_failed) {
      _failed = true;
      throw StateError('storage unavailable');
    }
    return super.setString(key, value, options);
  }
}
