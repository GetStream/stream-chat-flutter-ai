import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/stream_chat_flutter_ai_a2ui.dart';

import '../a2ui_test_app.dart';

// A builder the app gives the catalog: the theme it draws with, and what
// happens when it throws.
void main() {
  testWidgets("a builder reads the surface's theme", (tester) async {
    final theme = lightTheme().copyWith(cornerRadius: 3);
    A2UITheme? read;
    await pumpSurface(
      tester,
      components: [_card],
      theme: theme,
      catalog: A2UICatalog.basic.replacing('Card', (context, scope) {
        read = A2UITheme.of(context);
        return const SizedBox();
      }),
    );

    expect(read, theme);
  });

  testWidgets('a builder that throws is reported through onError with the component it builds', (tester) async {
    final errors = <A2UIError>[];
    await pumpSurface(tester, components: [_card], errors: errors, catalog: _throwing);
    tester.takeException();
    await tester.pump();

    expect(errors.map((error) => (error.code, error.surfaceId, error.message.contains("'root'"))), [
      (A2UIErrorCode.executionError, 's', true),
    ]);
  });

  testWidgets('a builder that throws is reported to Flutter', (tester) async {
    await pumpSurface(tester, components: [_card], catalog: _throwing);

    expect(tester.takeException(), isStateError);
  });

  testWidgets('a builder that throws draws nothing', (tester) async {
    await pumpSurface(tester, components: [_card], catalog: _throwing);
    tester.takeException();

    expect(find.byType(ErrorWidget), findsNothing);
  });
}

const _card = {'id': 'root', 'component': 'Card', 'child': 'missing'};

final _throwing = A2UICatalog.basic.replacing('Card', (context, scope) => throw StateError('no card'));
