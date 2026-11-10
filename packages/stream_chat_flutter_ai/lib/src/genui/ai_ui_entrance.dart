import 'package:flutter/widgets.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_component.dart';
import 'package:stream_chat_flutter_ai/src/genui/ai_ui_stage.dart';

/// Animates a part of generated UI, such as a card or a button, into view when
/// it first appears.
///
/// The part fades in while sliding up slightly, growing to full size, and
/// coming into focus. When several parts appear at the same time, they animate
/// one after another, a short moment apart.
///
/// A part doesn't animate on its own when it appears together with the UI
/// around it: it animates as part of that UI instead. So a reply loaded from
/// history, which appears all at once, shows without any animation.
///
/// With animations disabled ([MediaQueryData.disableAnimations]), a part only
/// fades in. Outside generated UI, the part shows immediately.
///
/// Renderers should wrap each part they place in one. [AIUIComponent.view]
/// already does it for components.
class AIUIEntrance extends StatelessWidget {
  /// Creates an [AIUIEntrance].
  const AIUIEntrance({super.key, required this.child});

  /// The part to animate in.
  final Widget child;

  @override
  Widget build(BuildContext context) => AIUIEntering(isStage: false, child: child);
}
