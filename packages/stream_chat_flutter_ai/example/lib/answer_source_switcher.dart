import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter_ai_ondevice/stream_chat_flutter_ai_ondevice.dart';

/// An app bar switcher between answering in the cloud and answering with the
/// model on this device.
///
/// The device half shows where the model is, as a badge: ready, downloadable,
/// downloading (a ring that fills) or not on this device (disabled). Tapping it
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
    final download = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download the on-device model?'),
        content: const Text(
          'It answers without a connection. The download is large, and the system may wait until the '
          'device is idle and on Wi-Fi, so it can take a while.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Download')),
        ],
      ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = _status;
    final deviceIcon = defaultTargetPlatform == TargetPlatform.macOS
        ? Icons.laptop_mac_outlined
        : Icons.smartphone_outlined;

    final (tooltip, badge) = switch (status) {
      AIOnDeviceStatus.available => ('Answer on this device', _Badge.ready),
      AIOnDeviceStatus.downloadable => ('Download the on-device model', _Badge.download),
      AIOnDeviceStatus.downloading => ('Downloading the on-device model', null),
      null => ('Checking for an on-device model', null),
      _ => (
        'No on-device model: it needs Gemini Nano (a recent flagship Android phone) or Apple Intelligence '
            '(iOS or macOS 26)',
        _Badge.unavailable,
      ),
    };
    final enabled =
        status == AIOnDeviceStatus.available ||
        status == AIOnDeviceStatus.downloadable ||
        status == AIOnDeviceStatus.downloading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              _Segment(
                tooltip: 'Answer in the cloud',
                selected: !widget.useDevice,
                onPressed: () => widget.onChanged(false),
                icon: Icons.cloud_outlined,
              ),
              _Segment(
                tooltip: tooltip,
                selected: widget.useDevice,
                onPressed: enabled ? _handleDevicePressed : null,
                icon: deviceIcon,
                badge: badge,
                progress: status == AIOnDeviceStatus.downloading ? (_progress ?? -1) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Badge { ready, download, unavailable }

// One half of the switcher: an icon, raised when `selected`, with an optional
// status `badge` or download `progress` (-1 while it is unknown).
class _Segment extends StatelessWidget {
  const _Segment({
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    required this.icon,
    this.badge,
    this.progress,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;
  final IconData icon;
  final _Badge? badge;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = this.progress;
    final badge = this.badge;
    final iconColor = onPressed == null
        ? colors.onSurface.withValues(alpha: 0.38)
        : selected
        ? colors.primary
        : colors.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        enabled: onPressed != null,
        child: Material(
          color: selected ? colors.surface : Colors.transparent,
          elevation: selected ? 1 : 0,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 40,
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress != null)
                    SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(value: progress < 0 ? null : progress, strokeWidth: 2),
                    ),
                  Icon(icon, size: progress != null ? 16 : 20, color: iconColor),
                  if (badge != null) Positioned(right: 5, bottom: 4, child: _BadgeDot(badge)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeDot extends StatelessWidget {
  const _BadgeDot(this.badge);

  final _Badge badge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (color, icon) = switch (badge) {
      _Badge.ready => (Colors.green.shade700, Icons.check),
      _Badge.download => (colors.primary, Icons.arrow_downward),
      _Badge.unavailable => (colors.outline, Icons.close),
    };
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surfaceContainerHighest, width: 1.5),
      ),
      child: Icon(icon, size: 8, color: Colors.white),
    );
  }
}
