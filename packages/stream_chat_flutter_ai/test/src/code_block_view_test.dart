import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/code_block_view.dart';

void main() {
  group('CodeBlockView', () {
    /// Captures what the widget writes to the clipboard, since the real platform
    /// channel isn't available under `flutter test`.
    List<String> mockClipboard() {
      final written = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            written.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return written;
    }

    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('shows the language label, omitting it when absent', (tester) async {
      await tester.pumpWidget(wrap(const CodeBlockView(code: 'x', language: 'dart')));
      expect(find.text('dart'), findsOneWidget);

      await tester.pumpWidget(wrap(const CodeBlockView(code: 'x')));
      expect(find.text('dart'), findsNothing);
    });

    testWidgets('copies the code and confirms, then reverts', (tester) async {
      final written = mockClipboard();

      await tester.pumpWidget(wrap(const CodeBlockView(code: 'var x = 1;', language: 'dart')));

      expect(find.byIcon(Icons.content_copy), findsOneWidget);

      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();

      expect(written, ['var x = 1;']);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('a second tap extends the confirmation instead of racing it', (tester) async {
      // Regression test: the reset used to be a `Future.delayed` per tap, so the
      // first tap's delay resolved mid-way through the second tap's window and
      // cleared the check mark early.
      mockClipboard();

      await tester.pumpWidget(wrap(const CodeBlockView(code: 'x', language: 'dart')));

      await tester.tap(find.byIcon(Icons.content_copy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();

      // 1s past the *first* tap's deadline, but only 1s into the second's.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('disposal mid-copy does not throw', (tester) async {
      // Regression test: `setState` ran unguarded right after the clipboard
      // round-trip, so a block scrolled away (or a replaced message) between tap
      // and completion tore down the state object first.
      //
      // The write has to still be in flight at disposal for this to bite, so the
      // mock handler is held open on a gate rather than resolving immediately.
      final gate = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') await gate.future;
          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(wrap(const CodeBlockView(code: 'x', language: 'dart')));

      await tester.tap(find.byIcon(Icons.content_copy));
      // Tear the block down while the clipboard write is still pending.
      await tester.pumpWidget(wrap(const SizedBox()));
      gate.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
