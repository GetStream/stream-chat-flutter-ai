import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_client_identity.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_storage.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_store.dart';

void main() {
  test('installId creates an id around a random UUID', () async {
    _useStorage(_MemoryStorage());

    final id = await AIClientIdentity.installId();

    expect(id, contains(RegExp('[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}')));
  });

  test('installId returns the same id on later calls', () async {
    _useStorage(_MemoryStorage());

    final first = await AIClientIdentity.installId();
    final second = await AIClientIdentity.installId();

    expect(second, first);
  });

  test('installId returns the same id to calls racing the first one', () async {
    final storage = _MemoryStorage();
    _useStorage(storage);

    final ids = await Future.wait([AIClientIdentity.installId(), AIClientIdentity.installId()]);

    expect(ids[1], ids[0]);
    expect(storage.creates, 1);
  });

  test('installId returns the id kept by an earlier launch', () async {
    _useStorage(_MemoryStorage('flutter-0B8A1D5E-KEPT'));

    final id = await AIClientIdentity.installId();

    expect(id, 'flutter-0B8A1D5E-KEPT');
  });

  test('installId returns the id another engine stored first', () async {
    _useStorage(_MemoryStorage(null, 'ios-OTHER-ENGINE'));

    final id = await AIClientIdentity.installId();

    expect(id, 'ios-OTHER-ENGINE');
  });

  for (final blank in ['', '  ']) {
    test('installId replaces a blank stored id (${jsonEncode(blank)})', () async {
      _useStorage(_MemoryStorage(blank));

      final id = await AIClientIdentity.installId();

      expect(id.trim(), isNotEmpty);
      expect(await AIClientIdentity.installId(), id);
    });
  }

  test('installId completes with the error when the id cannot be read', () async {
    _useStorage(_MemoryStorage()..failReads = 1);

    await expectLater(AIClientIdentity.installId(), throwsA(isA<StateError>()));
  });

  test('installId completes with the error when the id cannot be stored', () async {
    _useStorage(_MemoryStorage()..failCreates = 1);

    await expectLater(AIClientIdentity.installId(), throwsA(isA<StateError>()));
  });

  test('installId tries again after a failed read', () async {
    _useStorage(_MemoryStorage()..failReads = 1);
    await expectLater(AIClientIdentity.installId(), throwsStateError);

    final id = await AIClientIdentity.installId();

    expect(await AIClientIdentity.installId(), id);
  });

  test('installId tries again after a failed write', () async {
    _useStorage(_MemoryStorage()..failCreates = 1);
    await expectLater(AIClientIdentity.installId(), throwsStateError);

    final id = await AIClientIdentity.installId();

    expect(await AIClientIdentity.installId(), id);
  });
}

void _useStorage(AIInstallIdStorage storage) {
  final original = AIInstallIdStore.debugStorage;
  AIInstallIdStore.debugStorage = storage;
  addTearDown(() => AIInstallIdStore.debugStorage = original);
}

// Keeps the id in memory. [_otherEngineId], if given, is what another engine
// stores between this one's read and create.
final class _MemoryStorage implements AIInstallIdStorage {
  _MemoryStorage([this._id, this._otherEngineId]);

  String? _id;
  final String? _otherEngineId;
  int failReads = 0;
  int failCreates = 0;
  int creates = 0;

  @override
  Future<String?> read() async {
    await Future<void>.delayed(Duration.zero);
    if (failReads > 0) {
      failReads--;
      throw StateError('storage unavailable');
    }
    return _id;
  }

  @override
  Future<String> create(String id) async {
    await Future<void>.delayed(Duration.zero);
    if (failCreates > 0) {
      failCreates--;
      throw StateError('storage unavailable');
    }
    creates++;
    return _id = _otherEngineId ?? id;
  }
}
