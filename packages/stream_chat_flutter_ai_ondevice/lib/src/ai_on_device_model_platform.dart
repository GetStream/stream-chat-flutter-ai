// Platform-interface boilerplate (token, default instance, and the
// UnimplementedError stubs that platform implementations override).
// coverage:ignore-file
import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_download.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_info.dart';
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model_method_channel.dart';

/// The interface that platform-specific implementations of the on-device
/// model must implement.
///
/// Internal to the package.
@internal
abstract class AIOnDeviceModelPlatform extends PlatformInterface {
  /// Constructs an [AIOnDeviceModelPlatform].
  AIOnDeviceModelPlatform() : super(token: _token);

  static final _token = Object();

  static AIOnDeviceModelPlatform _instance = MethodChannelAIOnDeviceModel();

  /// The default instance of [AIOnDeviceModelPlatform] to use.
  ///
  /// Defaults to [MethodChannelAIOnDeviceModel].
  static AIOnDeviceModelPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AIOnDeviceModelPlatform] when they
  /// register themselves.
  static set instance(AIOnDeviceModelPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Where the model is, and the context and answer length it takes.
  Future<AIOnDeviceModelInfo> modelInfo() {
    throw UnimplementedError('modelInfo() has not been implemented.');
  }

  /// Streams the answer to the last of [turns], which are already fitted to
  /// the model's context and end with the person's question.
  ///
  /// Each event is the whole answer so far. Cancelling the subscription stops
  /// the model. Failures arrive as an [AILocalModelException] error event.
  Stream<String> reply({
    required String instructions,
    required List<AIConversationTurn> turns,
    required int maximumResponseTokens,
  }) {
    throw UnimplementedError('reply() has not been implemented.');
  }

  /// Downloads the model. Listening starts the download and cancelling stops
  /// it; the stream closes after a completed or failed event.
  Stream<AIOnDeviceDownload> download() {
    throw UnimplementedError('download() has not been implemented.');
  }
}
