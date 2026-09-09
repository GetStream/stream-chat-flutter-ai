import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real monospace font files to try, in order, when registering the
/// `monospace` family for golden tests. Only consulted on macOS, where
/// `platformGoldensConfig` renders real (non-obscured) text — CI goldens
/// obscure all text regardless of font, so this doesn't matter there.
const _kSystemMonospaceFontPaths = [
  '/System/Library/Fonts/SFNSMono.ttf',
  '/System/Library/Fonts/Supplemental/Courier New.ttf',
];

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final isRunningInCi = Platform.environment.containsKey('CI') || Platform.environment.containsKey('GITHUB_ACTIONS');

  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isRunningInCi) await _loadSystemMonospaceFont();

  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      ciGoldensConfig: CiGoldensConfig(enabled: isRunningInCi),
      platformGoldensConfig: PlatformGoldensConfig(enabled: !isRunningInCi),
    ),
    run: testMain,
  );
}

/// Registers a real monospace font under the `monospace` family name, which is
/// first in `CodeBlockView`'s font stack.
///
/// `flutter test` performs no platform font fallback, so an unregistered family
/// renders as missing-glyph placeholder boxes. On-device the widget's own
/// `fontFamilyFallback` (`Menlo`, `Consolas`, `Roboto Mono`, …) covers the
/// platforms where `monospace` isn't a real family — which is all of them bar
/// Android and web — but that list can't help here, because the test
/// environment has none of those fonts either. Hence a system font, registered
/// under the name at the head of the stack.
Future<void> _loadSystemMonospaceFont() async {
  for (final path in _kSystemMonospaceFontPaths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final loader = FontLoader('monospace')..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    return;
  }
}
