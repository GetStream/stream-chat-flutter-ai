// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model.dart';

/// Where the on-device model is on this device, as [AIOnDeviceModel.status]
/// reports it.
enum AIOnDeviceStatus {
  /// This device can't run the model: it isn't supported, the system's AI is
  /// switched off, or the platform has no on-device model.
  unavailable,

  /// The device can run the model once it is downloaded; see
  /// [AIOnDeviceModel.download].
  downloadable,

  /// The model is downloading. This can take hours: the system may wait until
  /// the device is idle and on Wi-Fi.
  downloading,

  /// The model can answer now.
  available,
}
