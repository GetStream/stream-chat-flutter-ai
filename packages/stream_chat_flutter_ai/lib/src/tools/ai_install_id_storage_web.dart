import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_storage.dart';
import 'package:web/web.dart' as web;

/// The install id storage for the web: `localStorage`.
AIInstallIdStorage createPlatformInstallIdStorage() => const AILocalStorageInstallIdStorage();

/// Keeps the install id in the browser's `localStorage`.
///
/// Clearing the site's data removes it.
final class AILocalStorageInstallIdStorage implements AIInstallIdStorage {
  /// Creates an [AILocalStorageInstallIdStorage].
  const AILocalStorageInstallIdStorage();

  @override
  Future<String?> read() async => web.window.localStorage.getItem(AIInstallIdStorage.key);

  @override
  Future<String> create(String id) async {
    // Another tab may have stored one since this one read.
    final storedId = web.window.localStorage.getItem(AIInstallIdStorage.key);
    if (storedId != null && storedId.trim().isNotEmpty) return storedId;

    web.window.localStorage.setItem(AIInstallIdStorage.key, id);
    return id;
  }
}
