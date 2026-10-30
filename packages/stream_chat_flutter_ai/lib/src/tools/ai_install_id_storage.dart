import 'package:flutter/foundation.dart';

/// Where `AIInstallIdStore` keeps the install id.
///
/// Internal to the package.
@internal
abstract interface class AIInstallIdStorage {
  /// The name the install id is kept under.
  ///
  /// This is its file name on Android, iOS, macOS, Windows and Linux, and its
  /// `localStorage` key on the web. Native Android keeps its id in a file of
  /// this name in the same directory, so an app that embeds both SDKs gets one
  /// id. Renaming it splits that id.
  static const key = 'io.getstream.ai.client-id';

  /// The stored id, or `null` if none has been stored yet.
  Future<String?> read();

  /// Stores [id] and completes with the id that ends up stored.
  ///
  /// That is [id], or the id that another engine or tab stored first. An id
  /// that another engine is slow to write after creating the file, or that
  /// another tab stores between this one's check and write, can be replaced.
  Future<String> create(String id);
}
