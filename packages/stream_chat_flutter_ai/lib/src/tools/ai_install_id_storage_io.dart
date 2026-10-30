import 'dart:io';

import 'package:objective_c/objective_c.dart' as objc;
import 'package:path_provider/path_provider.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_storage.dart';

/// The install id storage for this platform.
///
/// The id is kept in a file, out of backups on Android, iOS and macOS.
AIInstallIdStorage createPlatformInstallIdStorage() {
  return AIFileInstallIdStorage(
    directory: Platform.isAndroid ? _androidNoBackupDirectory : getApplicationSupportDirectory,
    excludeFromBackup: Platform.isIOS || Platform.isMacOS ? _excludeFromAppleBackup : null,
  );
}

// Android's `noBackupFilesDir`, which backups and device transfers skip.
Future<Directory> _androidNoBackupDirectory() async {
  return androidNoBackupDirectory(await getApplicationSupportDirectory());
}

/// The `no_backup` directory next to [applicationSupportDirectory].
///
/// On Android the application support directory is `filesDir`, and
/// `noBackupFilesDir` is its sibling: `<dataDir>/no_backup`. path_provider has
/// no getter for the latter.
Directory androidNoBackupDirectory(Directory applicationSupportDirectory) {
  return Directory('${applicationSupportDirectory.parent.path}/no_backup');
}

// Marks the file excluded from iCloud and computer backups, and so from
// restoring onto a new device.
Future<void> _excludeFromAppleBackup(File file) async {
  // The value of `NSURLIsExcludedFromBackupKey` is its own name.
  final url = objc.NSURL.fileURLWithPath(objc.NSString(file.path));
  final key = objc.NSString('NSURLIsExcludedFromBackupKey');
  url.setResourceValue(objc.NSNumberCreation.numberWithBool(true), forKey: key);
}

// Gives another engine time to write the id to the file it has created.
Future<void> _waitForOtherWrite() => Future<void>.delayed(const Duration(milliseconds: 20));

/// Keeps the install id in a file named [AIInstallIdStorage.key].
final class AIFileInstallIdStorage implements AIInstallIdStorage {
  /// Creates an [AIFileInstallIdStorage] in [directory].
  ///
  /// The directory is created if it's missing.
  AIFileInstallIdStorage({
    required this.directory,
    this.excludeFromBackup,
    this.waitForOtherWrite = _waitForOtherWrite,
    this.otherWriteChecks = 10,
  });

  /// The directory the file is in.
  final Future<Directory> Function() directory;

  /// Keeps the file out of the platform's backups, if given.
  ///
  /// It runs after the id is written and again on every read, so a launch
  /// that stopped in between is repaired by the next one.
  final Future<void> Function(File file)? excludeFromBackup;

  /// Waits between two reads of a file that another engine has created but
  /// not yet written the id to.
  final Future<void> Function() waitForOtherWrite;

  /// How many times [create] reads such a file before writing its own id.
  final int otherWriteChecks;

  @override
  Future<String?> read() async {
    final file = await _file();
    final String storedId;
    try {
      storedId = await file.readAsString();
    } on PathNotFoundException {
      return null;
    }
    if (storedId.trim().isNotEmpty) await excludeFromBackup?.call(file);
    return storedId;
  }

  @override
  Future<String> create(String id) async {
    final file = await _file();
    try {
      // Only one engine in this process can create the file.
      await file.create(exclusive: true);
    } on PathExistsException {
      final storedId = await _readOnceWritten(file);
      if (storedId != null) return storedId;
      // Still empty: whoever created it stopped before writing the id.
    }
    await file.writeAsString(id, flush: true);
    await excludeFromBackup?.call(file);
    return id;
  }

  Future<File> _file() async {
    final directory = await this.directory();
    await directory.create(recursive: true);
    return File('${directory.path}/${AIInstallIdStorage.key}');
  }

  Future<String?> _readOnceWritten(File file) async {
    for (var check = 0; check < otherWriteChecks; check++) {
      if (check > 0) await waitForOtherWrite();
      final storedId = await file.readAsString();
      if (storedId.trim().isNotEmpty) return storedId;
    }
    return null;
  }
}
