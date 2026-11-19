import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';
import 'package:stream_core_flutter/core.dart';

/// An app bar switcher between answering in the cloud and answering with the
/// model on this device.
///
/// The device button shows where the model is, as a badge: ready, downloadable,
/// downloading (a ring that fills), turned off in Settings, or not on this
/// device (disabled). Tapping it
/// switches to the device when the model is ready, and offers to download it
/// when it can be.
class AnswerSourceSwitcher extends StatefulWidget {
  const AnswerSourceSwitcher({
    super.key,
    required this.model,
    required this.useDevice,
    required this.onChanged,
  });

  final AIOnDeviceModel model;

  /// Whether answers come from [model] rather than the cloud.
  final bool useDevice;

  /// Called with the source the person picked: `true` for the device.
  final ValueChanged<bool> onChanged;

  @override
  State<AnswerSourceSwitcher> createState() => _AnswerSourceSwitcherState();
}

class _AnswerSourceSwitcherState extends State<AnswerSourceSwitcher> {
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
    // The model went away while answering on the device: back to the cloud.
    if (widget.useDevice && status != AIOnDeviceStatus.available) widget.onChanged(false);
  }

  Future<void> _confirmDownload() async {
    final download = await showStreamSheet<bool>(
      context: context,
      isDismissible: true,
      builder: (context, scrollController) => const _DownloadSheet(),
    );
    if (download != true || !mounted) return;
    _startDownload();
  }

  void _startDownload() {
    setState(() => _status = AIOnDeviceStatus.downloading);
    int? total;
    _download = widget.model.download().listen(
      (event) {
        switch (event) {
          case AIOnDeviceDownloadStarted(:final bytesToDownload):
            total = bytesToDownload;
          case AIOnDeviceDownloadProgress(:final bytesDownloaded):
            setState(() => _progress = _fractionOf(bytesDownloaded, total));
          case AIOnDeviceDownloadCompleted():
            _show('The on-device model is ready.');
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

  // How much of a download of [total] bytes is done, or null while the size
  // isn't known.
  static double? _fractionOf(int done, int? total) {
    if (total == null || total <= 0) return null;
    return done / total;
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleDevicePressed() {
    switch (_status) {
      case AIOnDeviceStatus.available:
        widget.onChanged(true);
      case AIOnDeviceStatus.downloadable:
        unawaited(_confirmDownload());
      case AIOnDeviceStatus.downloading:
        _show('The on-device model is still downloading. The system may wait until the device is idle and on Wi-Fi.');
      case AIOnDeviceStatus.notEnabled:
        _show('Turn on Apple Intelligence in Settings to answer on this device.');
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    final icons = context.streamIcons;
    final status = _status;
    // Core has no cloud, phone or laptop glyph.
    final deviceIcon = defaultTargetPlatform == TargetPlatform.macOS
        ? Icons.laptop_mac_outlined
        : Icons.smartphone_outlined;

    final (tooltip, badge) = switch (status) {
      AIOnDeviceStatus.available => ('Answer on this device', (colors.accentSuccess, icons.checkmark)),
      AIOnDeviceStatus.downloadable => ('Download the on-device model', (colors.accentPrimary, icons.arrowDown)),
      AIOnDeviceStatus.downloading => ('Downloading the on-device model', null),
      AIOnDeviceStatus.notEnabled => (
        'Turn on Apple Intelligence to answer on this device',
        (colors.accentWarning, icons.exclamationMarkFill),
      ),
      null => ('Checking for an on-device model', null),
      _ => (
        'No on-device model: it needs Gemini Nano (a recent flagship Android phone) or Apple Intelligence '
            '(iOS or macOS 26)',
        (colors.accentNeutral, icons.xmark),
      ),
    };
    final enabled =
        status == AIOnDeviceStatus.available ||
        status == AIOnDeviceStatus.downloadable ||
        status == AIOnDeviceStatus.downloading ||
        status == AIOnDeviceStatus.notEnabled;

    Widget device = Icon(deviceIcon);
    if (status == AIOnDeviceStatus.downloading) {
      device = Stack(
        alignment: Alignment.center,
        children: [
          StreamLoadingSpinner(value: _progress, size: .lg),
          Icon(deviceIcon, size: 14),
        ],
      );
    } else if (badge case (final color, final glyph)) {
      device = Stack(
        clipBehavior: Clip.none,
        children: [
          device,
          Positioned(
            right: -3,
            bottom: -3,
            child: _BadgeDot(color: color, icon: glyph),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: context.streamSpacing.xxs,
      children: [
        StreamButton.icon(
          style: .secondary,
          type: .ghost,
          tooltip: 'Answer in the cloud',
          isSelected: !widget.useDevice,
          icon: const Icon(Icons.cloud_outlined),
          onPressed: () => widget.onChanged(false),
        ),
        StreamButton.icon(
          style: .secondary,
          type: .ghost,
          tooltip: tooltip,
          isSelected: widget.useDevice,
          icon: device,
          onPressed: enabled ? _handleDevicePressed : null,
        ),
      ],
    );
  }
}

// Asks before downloading the model, and pops with whether to.
class _DownloadSheet extends StatelessWidget {
  const _DownloadSheet();

  @override
  Widget build(BuildContext context) {
    final spacing = context.streamSpacing;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamSheetHeader(title: const Text('Download the on-device model?')),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing.md),
            child: Text(
              'It answers without a connection. The download is large, and the system may wait until the '
              'device is idle and on Wi-Fi, so it can take a while.',
              style: context.streamTextTheme.bodyDefault.copyWith(color: context.streamColorScheme.textSecondary),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: spacing.xs,
              children: [
                StreamButton(
                  style: .secondary,
                  type: .ghost,
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Not now'),
                ),
                StreamButton(onPressed: () => Navigator.pop(context, true), child: const Text('Download')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// The status badge on the device button.
class _BadgeDot extends StatelessWidget {
  const _BadgeDot({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.streamColorScheme;
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: colors.backgroundApp, width: 1.5),
      ),
      child: Icon(icon, size: 8, color: colors.textOnAccent),
    );
  }
}
