import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

void main() {
  testWidgets('AIMessageAttachmentView opens the URL of a tapped file in an external app', (tester) async {
    final launcher = _useLauncher(opens: true);
    await tester.pumpWidget(_wrap(AIMessageAttachmentView(attachment: _pdf)));

    await tester.tap(find.text('receipt.pdf'));
    await tester.pump();

    expect(launcher.launched, ['https://x.io/receipt.pdf']);
    expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
  });

  testWidgets('AIMessageAttachmentView opens a file: URL with the platform default', (tester) async {
    final launcher = _useLauncher(opens: true);
    await tester.pumpWidget(
      _wrap(
        AIMessageAttachmentView(
          attachment: AIMessageAttachment.file(Uri.parse('file:///tmp/notes.txt'), name: 'notes.txt'),
        ),
      ),
    );

    await tester.tap(find.text('notes.txt'));
    await tester.pump();

    expect(launcher.launched, ['file:///tmp/notes.txt']);
    expect(launcher.modes, [PreferredLaunchMode.platformDefault]);
  });

  testWidgets('AIMessageAttachmentView says no app can open the file when it is not opened', (tester) async {
    _useLauncher(opens: false);
    await tester.pumpWidget(_wrap(AIMessageAttachmentView(attachment: _pdf)));

    await tester.tap(find.text('receipt.pdf'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No app can open this file'), findsOneWidget);
  });

  testWidgets('AIMessageAttachmentView says no app can open the file when launching throws', (tester) async {
    _useLauncher(opens: true, throws: true);
    await tester.pumpWidget(_wrap(AIMessageAttachmentView(attachment: _pdf)));

    await tester.tap(find.text('receipt.pdf'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isA<PlatformException>());
    expect(find.text('No app can open this file'), findsOneWidget);
  });

  testWidgets('AIMessageAttachmentView does nothing when an image is tapped', (tester) async {
    final launcher = _useLauncher(opens: true);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        AIMessageAttachmentView(
          attachment: AIMessageAttachment.image(Uri.parse('https://x.io/photo.png'), name: 'photo'),
        ),
      ),
    );

    await tester.tap(find.byType(Image));
    await tester.pump();

    expect(launcher.launched, isEmpty);
    expect(
      tester.getSemantics(find.bySemanticsLabel('photo')).getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('AIMessageAttachmentView is not a button without a URL', (tester) async {
    _useLauncher(opens: true);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const AIMessageAttachmentView(attachment: _noUrl)));

    expect(_button(tester, 'File'), isNull);
    semantics.dispose();
  });

  testWidgets('AIMessageAttachmentView gives the tap to onTap, and launches nothing', (tester) async {
    final launcher = _useLauncher(opens: true);
    var taps = 0;
    await tester.pumpWidget(_wrap(AIMessageAttachmentView(attachment: _pdf, onTap: () => taps++)));

    await tester.tap(find.text('receipt.pdf'));
    await tester.pump();

    expect(taps, 1);
    expect(launcher.launched, isEmpty);
  });

  testWidgets('AIMessageAttachmentView gives the tap of a conversation to onAttachmentTap, and launches nothing', (
    tester,
  ) async {
    final launcher = _useLauncher(opens: true);
    final tapped = <AIMessageAttachment>[];
    await tester.pumpWidget(
      _wrap(AIUserMessageView(text: '', attachments: [_pdf], onAttachmentTap: tapped.add)),
    );

    await tester.tap(find.text('receipt.pdf'));
    await tester.pump();

    expect(tapped, [_pdf]);
    expect(launcher.launched, isEmpty);
  });

  testWidgets('AIMessageAttachmentView launches a file tapped in a message without onAttachmentTap', (tester) async {
    final launcher = _useLauncher(opens: true);
    await tester.pumpWidget(_wrap(AIUserMessageView(text: '', attachments: [_pdf])));

    await tester.tap(find.text('receipt.pdf'));
    await tester.pump();

    expect(launcher.launched, ['https://x.io/receipt.pdf']);
  });

  testWidgets('AIMessageAttachmentView is a button with the hint "Open" when it opens by default', (tester) async {
    _useLauncher(opens: true);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(AIMessageAttachmentView(attachment: _pdf)));

    final data = _button(tester, 'receipt.pdf');
    expect(data, isNotNull);
    expect(data!.customSemanticsActionIds, contains(_openHint));
    semantics.dispose();
  });

  testWidgets('AIMessageAttachmentView keeps no "Open" hint when onTap is set', (tester) async {
    _useLauncher(opens: true);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(AIMessageAttachmentView(attachment: _pdf, onTap: () {})));

    final data = _button(tester, 'receipt.pdf');
    expect(data, isNotNull);
    expect(data!.customSemanticsActionIds ?? const <int>[], isNot(contains(_openHint)));
    semantics.dispose();
  });
}

final _pdf = AIMessageAttachment.file(Uri.parse('https://x.io/receipt.pdf'), name: 'receipt.pdf');
const _noUrl = AIMessageAttachment(kind: AIMessageAttachmentKind.file);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(alignment: Alignment.topLeft, child: child),
  ),
);

final _openHint = CustomSemanticsAction.getIdentifier(
  const CustomSemanticsAction.overridingAction(hint: 'Open', action: SemanticsAction.tap),
);

// The semantics of the button around [label], or `null` if it is not in one.
SemanticsData? _button(WidgetTester tester, String label) {
  SemanticsNode? node = tester.getSemantics(find.text(label));
  while (node != null) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isButton) return data;
    node = node.parent;
  }
  return null;
}

_FakeUrlLauncher _useLauncher({required bool opens, bool throws = false}) {
  final launcher = _FakeUrlLauncher(opens: opens, throws: throws);
  final previous = UrlLauncherPlatform.instance;
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = previous);
  return launcher;
}

final class _FakeUrlLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  _FakeUrlLauncher({required this.opens, required this.throws});

  final bool opens;
  final bool throws;
  final launched = <String>[];
  final modes = <PreferredLaunchMode>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    modes.add(options.mode);
    if (throws) throw PlatformException(code: 'x');
    return opens;
  }
}
