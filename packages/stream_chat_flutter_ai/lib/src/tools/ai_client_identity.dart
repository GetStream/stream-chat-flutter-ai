import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_approver.dart';
// Not doc-only: the matchers below call into it.
import 'package:stream_chat_flutter_ai/src/parts/ai_tool_call_part.dart';
// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai/src/tools/ai_client_tool_runner.dart';
import 'package:stream_chat_flutter_ai/src/tools/ai_install_id_preferences.dart'
    if (dart.library.js_interop) 'package:stream_chat_flutter_ai/src/tools/ai_install_id_preferences_web.dart';
import 'package:uuid/uuid.dart';

/// Who is signed in on this device, and which install this is — what a tool
/// call's `target_user_id` and `target_client_id` are matched against.
///
/// The host supplies both: [userId] from its chat client's signed-in user, and
/// [clientId] from an id kept per install, such as the one [installId] creates
/// and keeps.
///
/// ```dart
/// final identity = AIClientIdentity(
///   userId: currentUser.id,
///   clientId: await AIClientIdentity.installId(),
/// );
/// ```
///
/// Two matchers say what this device may do with a call, and they treat a
/// missing `target_client_id` differently:
///
///  * [canApprove] — answering a call's question. A call that names no
///    install can be answered from any of the person's devices.
///  * [canRun] — running a client tool. The call must name exactly this
///    install, so a call without `target_client_id`, or an identity without a
///    [clientId], never runs here: two devices must never both run it.
///
/// See [AIToolApprover] and [AIClientToolRunner].
@immutable
class AIClientIdentity {
  /// Creates an [AIClientIdentity]. [userId] must not be empty.
  const AIClientIdentity({required this.userId, this.clientId}) : assert(userId != '', 'userId must not be empty');

  /// The person signed in, matched against a call's `target_user_id`.
  final String userId;

  /// This install, matched against a call's `target_client_id`. `null` when
  /// the host keeps no install id: calls naming an install then never match.
  final String? clientId;

  /// An id for this install of the app, to pass as [clientId].
  ///
  /// The first call creates it, `flutter-` followed by an uppercase UUID, and
  /// keeps it in shared preferences under `io.getstream.ai.client-id`; later
  /// calls, in this launch and the next, complete with the same id. Calls made
  /// while the first one is still in flight complete with that same id too.
  /// The id is gone once the app is uninstalled or its data is cleared, and
  /// the next call creates a new one.
  ///
  /// On Android the id is kept in a preferences file of its own,
  /// `io.getstream.ai.client-id.xml`, which Android backs up and copies to a
  /// new device like the rest of the app's data unless the app's backup rules
  /// exclude it. Exclude it: a restored id makes two devices the same install,
  /// so both would run a call meant for one. The package README has the rules.
  ///
  /// If the id can't be read or stored, the returned future completes with
  /// that error, and the next call tries again.
  static Future<String> installId() {
    return _pendingInstallId ??= _readOrCreateInstallId().whenComplete(() => _pendingInstallId = null);
  }

  static const _installIdKey = 'io.getstream.ai.client-id';

  // The lookup in flight, shared so that calls racing the first one don't
  // each create an id of their own.
  static Future<String>? _pendingInstallId;

  static Future<String> _readOrCreateInstallId() async {
    final preferences = SharedPreferencesAsync(options: kAIInstallIdPreferencesOptions);
    final storedId = await preferences.getString(_installIdKey);
    if (storedId != null) return storedId;

    final newId = 'flutter-${const Uuid().v4().toUpperCase()}';
    await preferences.setString(_installIdKey, newId);
    return newId;
  }

  /// Whether [call] waits for this person to answer its question, on this
  /// device. See [AIToolCallPart.isAwaitingApproval].
  bool canApprove(AIToolCallPart call) => call.isAwaitingApproval(userId: userId, clientId: clientId);

  /// Whether [call] is a client tool waiting for this install to run it:
  /// targeted at [userId] and exactly at [clientId]. Always `false` without a
  /// [clientId]. See [AIToolCallPart.isAwaiting].
  bool canRun(AIToolCallPart call) {
    final clientId = this.clientId;
    return clientId != null && call.isAwaiting(userId: userId, clientId: clientId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIClientIdentity && other.userId == userId && other.clientId == clientId;

  @override
  int get hashCode => Object.hash(userId, clientId);

  @override
  String toString() => 'AIClientIdentity(userId: $userId, clientId: $clientId)';
}
