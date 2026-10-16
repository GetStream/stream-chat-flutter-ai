// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/local_model/ai_local_model.dart';

/// Why an [AILocalModel] couldn't answer, so a caller can tell what to do
/// next.
enum AILocalModelErrorReason {
  /// The model can't answer on this device now: it is missing, still
  /// downloading, switched off, or busy. Tell the person, and try again later.
  unavailable,

  /// The conversation given to [AILocalModel.reply] can't be answered: it is
  /// empty, or doesn't end with the person's question. A bug in the caller.
  invalidConversation,

  /// The model started but failed, for example it ran out of memory or
  /// refused the content. Show a message; trying again may work.
  failed,
}

/// The error an [AILocalModel.reply] stream emits when the model can't
/// answer.
class AILocalModelException implements Exception {
  /// An error for [reason], described by [message], caused by [cause] if
  /// there was an underlying error.
  const AILocalModelException(this.reason, this.message, {this.cause});

  /// Why the model couldn't answer.
  final AILocalModelErrorReason reason;

  /// A description for logs; not meant to be shown to the person as is.
  final String message;

  /// The underlying error, such as the platform's, if any.
  final Object? cause;

  @override
  String toString() => 'AILocalModelException(${reason.name}): $message${cause == null ? '' : ' (caused by: $cause)'}';
}
