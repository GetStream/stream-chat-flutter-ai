import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

import 'tool_sign_in_fakes.dart';

const _notOpened = "The sign-in couldn't be opened. Try again.";
const _notSent = "Your answer couldn't be sent. Try again.";

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 360, child: child),
    ),
  ),
);

final _card = find.byType(AIToolAuthorizationCard);

void main() {
  group('AIToolAuthorizationCard', () {
    testWidgets('leaves a blank message out', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationCard(
            authorization: signIn.copyWith(message: '  '),
            onConnect: () {},
            onDecline: () {},
          ),
        ),
      );

      expect(
        find.byWidgetPredicate((widget) => widget is Text && (widget.data?.trim().isEmpty ?? false)),
        findsNothing,
      );
      expect(find.text('Connect Linear'), findsOneWidget);
    });

    testWidgets('with both failures, says the page could not be opened', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationCard(
            authorization: signIn,
            state: const AIToolAuthorizationState(connectFailed: true, declineFailed: true),
            onConnect: () {},
            onDecline: () {},
          ),
        ),
      );

      expect(find.text(_notOpened), findsOneWidget);
      expect(find.text(_notSent), findsNothing);
    });

    testWidgets('is styled by the approval theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AIToolAuthorizationCard(
            authorization: signIn,
            onConnect: () {},
            onDecline: () {},
            theme: const ToolApprovalThemeData(backgroundColor: Color(0xFF123456)),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(find.descendant(of: _card, matching: find.byType(DecoratedBox)).first);
      expect((box.decoration as BoxDecoration).color, const Color(0xFF123456));
    });

    group('goldens', () {
      Widget card(ThemeData theme, AIToolAuthorizationState state) => Theme(
        data: theme,
        child: Builder(
          builder: (context) => MediaQuery(
            // Deterministic: no spinner.
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ColoredBox(
              color: theme.colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: 320,
                  child: AIToolAuthorizationCard(
                    authorization: signIn,
                    state: state,
                    onConnect: () {},
                    onDecline: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      for (final (name, theme) in [
        ('light', ThemeData()),
        ('dark', ThemeData(brightness: Brightness.dark)),
      ]) {
        goldenTest(
          name,
          fileName: 'ai_tool_authorization_card_$name',
          builder: () => GoldenTestGroup(
            columns: 1,
            children: [
              GoldenTestScenario(name: 'idle', child: card(theme, const AIToolAuthorizationState())),
              GoldenTestScenario(
                name: 'connecting',
                child: card(theme, const AIToolAuthorizationState(isConnecting: true)),
              ),
              GoldenTestScenario(
                name: 'declining',
                child: card(theme, const AIToolAuthorizationState(isDeclining: true)),
              ),
              GoldenTestScenario(
                name: 'not opened',
                child: card(theme, const AIToolAuthorizationState(connectFailed: true)),
              ),
              GoldenTestScenario(
                name: 'not sent',
                child: card(theme, const AIToolAuthorizationState(declineFailed: true)),
              ),
              GoldenTestScenario(
                name: 'expired',
                child: card(theme, const AIToolAuthorizationState(isExpired: true)),
              ),
            ],
          ),
        );
      }
    });
  });
}
