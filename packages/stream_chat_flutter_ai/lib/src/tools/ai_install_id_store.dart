import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_storage.dart';
// dart:io isn't available on the web, which keeps the id in localStorage
// instead of a file.
import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_storage_io.dart'
    if (dart.library.js_interop) 'package:stream_chat_flutter_ai/src/tools/ai_install_id_storage_web.dart';
import 'package:uuid/uuid.dart';

/// Keeps the id of this install of the app: reads it, or creates and stores it
/// on first use.
///
/// Internal to the package, and kept apart from `AIClientIdentity` so that
/// another Stream SDK can share it later.
@internal
abstract final class AIInstallIdStore {
  /// Where the id is kept: a file, or `localStorage` on the web. Only tests
  /// replace it.
  static AIInstallIdStorage debugStorage = createPlatformInstallIdStorage();

  // The lookup in flight, shared so that calls racing the first one don't
  // each create an id of their own.
  static Future<String>? _pending;

  /// The id of this install; see `AIClientIdentity.installId`.
  static Future<String> installId() {
    return _pending ??= _readOrCreate().whenComplete(() => _pending = null);
  }

  static Future<String> _readOrCreate() async {
    final storedId = await debugStorage.read();
    if (storedId != null && storedId.trim().isNotEmpty) return storedId;

    return debugStorage.create('flutter-${const Uuid().v4().toUpperCase()}');
  }
}
