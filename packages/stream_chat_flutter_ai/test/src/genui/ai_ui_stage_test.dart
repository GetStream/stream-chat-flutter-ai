import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_stage.dart';

void main() {
  test('AIUIStage carries what a part holds while the part first shows', () {
    final stage = AIUIStage.root(AIUICascade())..carries = false;

    expect(stage.child().isCarried, isTrue);
  });

  test('AIUIStage lets what a part that has shown holds come in on its own', () {
    final stage = AIUIStage.root(AIUICascade())..carries = false;

    expect((stage.child()..carries = false).isCarried, isFalse);
  });

  test('AIUIStage carries what a carried part holds too', () {
    final stage = AIUIStage.root(AIUICascade());

    expect((stage.child()..carries = false).isCarried, isTrue);
  });
}
