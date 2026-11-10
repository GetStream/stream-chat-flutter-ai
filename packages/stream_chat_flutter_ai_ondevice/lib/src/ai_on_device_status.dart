// Imported for the doc links below only.
import 'package:stream_chat_flutter_ai_ondevice/src/ai_on_device_model.dart';

/// The state of the on-device model, as [AIOnDeviceModel.status] reports it.
///
/// An open set: a later version may add a status, so a `switch` over it
/// needs a default case.
extension type const AIOnDeviceStatus._(String _) implements String {
  /// A device that can't run the model.
  ///
  /// The device isn't supported, the system's AI is switched off, or the
  /// platform has no on-device model.
  static const unavailable = AIOnDeviceStatus._('unavailable');

  /// A model the device can run once it is downloaded.
  ///
  /// See [AIOnDeviceModel.download].
  static const downloadable = AIOnDeviceStatus._('downloadable');

  /// A model that is downloading.
  ///
  /// This can take hours: the system may wait until the device is idle and on
  /// Wi-Fi.
  static const downloading = AIOnDeviceStatus._('downloading');

  /// A model that can answer now.
  static const available = AIOnDeviceStatus._('available');

  /// The statuses this version reports.
  static const values = [unavailable, downloadable, downloading, available];
}
