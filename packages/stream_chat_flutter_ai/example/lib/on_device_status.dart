import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';

/// An app bar button that shows where the on-device model is and, when this
/// device can run it but doesn't have it yet, downloads it on tap.
class OnDeviceStatusButton extends StatefulWidget {
  const OnDeviceStatusButton({super.key, required this.model});

  final AIOnDeviceModel model;

  @override
  State<OnDeviceStatusButton> createState() => _OnDeviceStatusButtonState();
}

class _OnDeviceStatusButtonState extends State<OnDeviceStatusButton> {
  AIOnDeviceStatus? _status;
  StreamSubscription<AIOnDeviceDownload>? _download;
  double? _progress;

  // The status can change while the app is in the background: Apple
  // Intelligence turned on in Settings, or AICore finishing a download.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_refresh()));
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_download?.cancel());
    super.dispose();
  }

  Future<void> _refresh() async {
    final status = await widget.model.status();
    if (!mounted) return;
    // AICore reports the model downloadable until it starts the download it
    // was asked for, so keep showing the download until the status moves on.
    if (_download != null && status == AIOnDeviceStatus.downloadable) return;
    setState(() => _status = status);
  }

  void _startDownload() {
    setState(() => _status = AIOnDeviceStatus.downloading);
    int? total;
    _download = widget.model.download().listen(
      (event) {
        switch (event) {
          case AIOnDeviceDownloadStarted(:final bytesToDownload):
            total = bytesToDownload;
          case AIOnDeviceDownloadProgress(:final bytesDownloaded, :final fraction):
            final size = total;
            setState(() {
              _progress =
                  fraction ?? (size != null && size > 0 && bytesDownloaded != null ? bytesDownloaded / size : null);
            });
          case AIOnDeviceDownloadCompleted():
            _show('The on-device model is ready: turn the cloud off to answer on this device.');
          case AIOnDeviceDownloadFailed(:final error):
            _show('The download failed: ${error.message}');
        }
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _download = null;
          _progress = null;
        });
        unawaited(_refresh());
      },
    );
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onPressed() {
    switch (_status) {
      case AIOnDeviceStatus.downloadable:
        _startDownload();
        _show('Downloading the on-device model. This can take a while.');
      case AIOnDeviceStatus.downloading:
        _show('The on-device model is downloading. The system may wait until the device is idle and on Wi-Fi.');
      case AIOnDeviceStatus.available:
        _show('The on-device model is ready: turn the cloud off to answer on this device.');
      case AIOnDeviceStatus.unavailable || null:
        _show(
          'This device has no on-device model: it needs Gemini Nano (a recent flagship Android phone) or '
          'Apple Intelligence (iOS or macOS 26).',
        );
        unawaited(_refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, tooltip) = switch (_status) {
      AIOnDeviceStatus.available => (Icons.offline_bolt_outlined, 'On-device model ready'),
      AIOnDeviceStatus.downloadable => (Icons.download_outlined, 'Download the on-device model'),
      AIOnDeviceStatus.downloading => (Icons.downloading_outlined, 'Downloading the on-device model'),
      AIOnDeviceStatus.unavailable || null => (Icons.mobile_off_outlined, 'No on-device model'),
    };
    final button = IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: _onPressed);
    final progress = _progress;
    if (progress == null) return button;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(dimension: 36, child: CircularProgressIndicator(value: progress, strokeWidth: 2)),
        button,
      ],
    );
  }
}
