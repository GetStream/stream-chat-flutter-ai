/// Stream Chat AI Flutter components.
library stream_chat_flutter_ai;

// Exported from `cross_file`, where `XFile` is actually defined, rather than
// from `image_picker`, which merely re-exports it — this package's use of the
// type doesn't depend on the picker it happens to arrive from.
export 'package:cross_file/cross_file.dart' show XFile;
export 'package:flutter_markdown_plus/flutter_markdown_plus.dart' show MarkdownStyleSheet;
// `SpeechToTextConfig.onError` hands one of these back, so a host that wants to
// react to a dictation failure would otherwise have to depend on
// `speech_to_text` directly just to name the parameter's type.
export 'package:speech_to_text/speech_recognition_error.dart' show SpeechRecognitionError;

export 'src/ai_markdown_body.dart';
export 'src/ai_typing_indicator_view.dart';
export 'src/chart/chart_semantics.dart';
export 'src/chart/chart_view.dart';
export 'src/chart/heatmap_chart_view.dart';
export 'src/chart/uspec.dart';
export 'src/code_block_view.dart';
export 'src/composer/chat_composer.dart';
export 'src/composer/chat_composer_controller.dart';
export 'src/composer/chat_composer_factory.dart';
export 'src/composer/chat_option.dart';
export 'src/composer/composer_action_button.dart';
export 'src/composer/composer_attachment_sheet.dart';
export 'src/composer/speech_to_text_button.dart';
export 'src/composer/speech_to_text_controller.dart';
export 'src/composer/suggestions_view.dart';
export 'src/localization/ai_translations.dart';
export 'src/markdown/math_syntax.dart';
export 'src/streaming_message_view.dart';
export 'src/theme/ai_theme.dart';
export 'src/theme/components/chart_theme.dart';
export 'src/typewriter_builder.dart';
