// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model.dart';

/// Where the on-device model is on this device, as [AIOnDeviceModel.status]
/// reports it.
///
/// An open set: a later version may add a status, so a `switch` over it
/// needs a default case.
extension type const AIOnDeviceStatus._(String _) implements String {
  /// This device can't run the model: it isn't supported, the system's AI is
  /// switched off, or the platform has no on-device model.
  static const unavailable = AIOnDeviceStatus._('unavailable');

  /// The device can run the model once it is downloaded; see
  /// [AIOnDeviceModel.download].
  static const downloadable = AIOnDeviceStatus._('downloadable');

  /// The model is downloading. This can take hours: the system may wait until
  /// the device is idle and on Wi-Fi.
  static const downloading = AIOnDeviceStatus._('downloading');

  /// The model can answer now.
  static const available = AIOnDeviceStatus._('available');

  /// The statuses this version reports.
  static const values = [unavailable, downloadable, downloading, available];
}
