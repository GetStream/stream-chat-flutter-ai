import 'dart:convert';
import 'dart:io';

/// Reads a JSON fixture from `test/fixtures/genui/`.
///
/// The fixtures hold generative UI wire data written the way every platform
/// and the agent's backend write it, so a change to what this package reads or
/// writes shows up as a failing fixture.
Map<String, Object?> genuiFixture(String name) =>
    jsonDecode(File('${_packageDirectory.path}/test/fixtures/genui/$name').readAsStringSync()) as Map<String, Object?>;

/// [json] as it reaches another platform: encoded to text and decoded again.
Object? overTheWire(Object? json) => jsonDecode(jsonEncode(json));

// The package's directory, which tests usually run in, but an IDE may run them
// in `test/`.
Directory get _packageDirectory {
  final directory = Directory.current;
  return directory.path.endsWith('${Platform.pathSeparator}test') ? directory.parent : directory;
}
