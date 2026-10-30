import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_storage.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_storage_io.dart';

void main() {
  test('read completes with null before any id is stored', () async {
    final directory = _tempDirectory();

    final storage = AIFileInstallIdStorage(directory: () async => directory);

    expect(await storage.read(), isNull);
  });

  test('create completes with the id it was given', () async {
    final directory = _tempDirectory();
    final storage = AIFileInstallIdStorage(directory: () async => directory);

    expect(await storage.create('flutter-NEW'), 'flutter-NEW');
  });

  test('create writes the bare id to a file named like native Android', () async {
    final directory = _tempDirectory();
    final storage = AIFileInstallIdStorage(directory: () async => directory);

    await storage.create('flutter-NEW');

    expect(File('${directory.path}/io.getstream.ai.client-id').readAsStringSync(), 'flutter-NEW');
  });

  test('read completes with the stored id', () async {
    final directory = _tempDirectory();
    _idFile(directory).writeAsStringSync('flutter-KEPT');

    final storage = AIFileInstallIdStorage(directory: () async => directory);

    expect(await storage.read(), 'flutter-KEPT');
  });

  test('create excludes the file from backups once the id is in it', () async {
    final directory = _tempDirectory();
    final excludedContents = <String>[];
    final storage = AIFileInstallIdStorage(
      directory: () async => directory,
      excludeFromBackup: (file) async => excludedContents.add(file.readAsStringSync()),
    );

    await storage.create('flutter-NEW');

    expect(excludedContents, ['flutter-NEW']);
  });

  test('read excludes the file from backups again', () async {
    final directory = _tempDirectory();
    _idFile(directory).writeAsStringSync('flutter-KEPT');
    final excluded = <String>[];
    final storage = AIFileInstallIdStorage(
      directory: () async => directory,
      excludeFromBackup: (file) async => excluded.add(file.path),
    );

    await storage.read();

    expect(excluded, [_idFile(directory).path]);
  });

  test('read completes with the stored id when the backup exclusion fails', () async {
    final directory = _tempDirectory();
    _idFile(directory).writeAsStringSync('flutter-KEPT');
    final storage = AIFileInstallIdStorage(
      directory: () async => directory,
      excludeFromBackup: (_) async => throw const FileSystemException('exclusion failed'),
    );

    expect(await storage.read(), 'flutter-KEPT');
  });

  test('create completes with the stored id when the backup exclusion fails', () async {
    final directory = _tempDirectory();
    final storage = AIFileInstallIdStorage(
      directory: () async => directory,
      excludeFromBackup: (_) async => throw const FileSystemException('exclusion failed'),
    );

    expect(await storage.create('flutter-NEW'), 'flutter-NEW');
    expect(_idFile(directory).readAsStringSync(), 'flutter-NEW');
  });

  test('create keeps the id another engine stored first', () async {
    final directory = _tempDirectory();
    _idFile(directory).writeAsStringSync('flutter-FIRST');
    final storage = AIFileInstallIdStorage(directory: () async => directory);

    expect(await storage.create('flutter-SECOND'), 'flutter-FIRST');
  });

  test('two engines creating at once end up with one id', () async {
    final directory = _tempDirectory();
    AIFileInstallIdStorage storage() => AIFileInstallIdStorage(directory: () async => directory);

    final ids = await Future.wait([storage().create('flutter-A'), storage().create('flutter-B')]);

    expect(ids[1], ids[0]);
  });

  test('create waits for the id that another engine is still writing', () async {
    final directory = _tempDirectory();
    final file = _idFile(directory)..createSync();
    final storage = AIFileInstallIdStorage(
      directory: () async => directory,
      waitForOtherWrite: () async => file.writeAsStringSync('flutter-FIRST'),
    );

    expect(await storage.create('flutter-SECOND'), 'flutter-FIRST');
  });

  test('create replaces a file left empty by an earlier launch', () async {
    final directory = _tempDirectory();
    final file = _idFile(directory)..createSync();
    final storage = AIFileInstallIdStorage(directory: () async => directory, waitForOtherWrite: () async {});

    await storage.create('flutter-NEW');

    expect(file.readAsStringSync(), 'flutter-NEW');
  });

  test(
    'create fails with the reason the file cannot be created',
    () async {
      final directory = _tempDirectory()..createSync();
      Process.runSync('chmod', ['500', directory.path]);
      addTearDown(() => Process.runSync('chmod', ['700', directory.path]));
      final storage = AIFileInstallIdStorage(directory: () async => directory);

      await expectLater(storage.create('flutter-NEW'), throwsA(isA<PathAccessException>()));
    },
    skip: Platform.isWindows ? 'chmod has no effect on Windows.' : false,
  );

  test('on Android the id is kept in no_backup, next to filesDir', () {
    final noBackup = androidNoBackupDirectory(Directory('/data/user/0/com.example.app/files'));

    expect(noBackup.path, '/data/user/0/com.example.app/no_backup');
  });

  test('the platform storage keeps the id under the application support directory', () async {
    final directory = _tempDirectory();
    _usePathProvider(_FakePathProvider(directory.path));

    await createPlatformInstallIdStorage().create('flutter-NEW');

    expect(_idFile(directory).readAsStringSync(), 'flutter-NEW');
  });

  test(
    'on macOS the file is excluded from backups',
    () async {
      final directory = _tempDirectory();
      _usePathProvider(_FakePathProvider(directory.path));

      await createPlatformInstallIdStorage().create('flutter-NEW');

      final attributes = Process.runSync('xattr', [_idFile(directory).path]).stdout as String;
      expect(attributes, contains('com.apple.metadata:com_apple_backup_excludeItem'));
    },
    skip: Platform.isMacOS ? false : 'Needs macOS: the exclusion uses Foundation and xattr.',
  );
}

// A directory that doesn't exist yet, inside a temporary one removed after
// the test.
Directory _tempDirectory() {
  final root = Directory.systemTemp.createTempSync('install_id_');
  addTearDown(() => root.deleteSync(recursive: true));
  return Directory('${root.path}/support');
}

File _idFile(Directory directory) {
  directory.createSync(recursive: true);
  return File('${directory.path}/${AIInstallIdStorage.key}');
}

void _usePathProvider(PathProviderPlatform pathProvider) {
  final original = PathProviderPlatform.instance;
  PathProviderPlatform.instance = pathProvider;
  addTearDown(() => PathProviderPlatform.instance = original);
}

final class _FakePathProvider extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  _FakePathProvider(this.applicationSupportPath);

  final String applicationSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => applicationSupportPath;
}
