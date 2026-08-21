import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' hide XFile;
import 'package:photo_manager/photo_manager.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_controller.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_composer_factory.dart';
import 'package:stream_chat_flutter_ai/src/composer/chat_option.dart';
import 'package:stream_chat_flutter_ai/src/util/lru_cache.dart';

/// How many asset-id → file-path mappings to remember. Comfortably more than
/// the strip shows at once, small enough to stay cheap.
const _kAssetPathCacheCapacity = 128;

/// Maps a [AssetEntity.id] to the file path resolving it produced.
///
/// A tile's checkmark is derived from [ChatComposerController.attachments],
/// which stores paths, while the strip is keyed by asset id — so telling
/// whether an asset is attached needs the mapping between the two, and
/// resolving it is an async platform call (on iOS, potentially an iCloud
/// download). Cached at library scope rather than in the sheet's state so that
/// closing and reopening the sheet doesn't forget which photos are still
/// attached.
final _assetPathCache = LruCache<String, String>(_kAssetPathCacheCapacity);

/// Clears the asset-path cache. Exposed for tests.
@visibleForTesting
void debugClearAssetPathCache() => _assetPathCache.clear();

/// The combined attachment / chat-option sheet opened from the composer's
/// leading "+" button by default (see [ChatComposerFactory.buildLeading]).
///
/// Shows, in a single scrollable sheet:
/// - A camera tile and a horizontal strip of the user's recent photos, each
///   tappable to toggle it in/out of [ChatComposerController.attachments].
///   Selecting a photo takes effect immediately — there is no separate
///   confirm step, so the sheet can stay open while the user picks several.
/// - An "All Photos" button that opens the platform's full image picker.
/// - Below that (only if non-empty), [ChatComposerController.chatOptions] as a
///   list of selectable rows (icon, title, subtitle) — tapping one calls
///   [ChatComposerController.selectChatOption] and closes the sheet.
///
/// Requires platform permissions for gallery access:
///
/// **iOS** — add to `ios/Runner/Info.plist`:
/// ```xml
/// <key>NSPhotoLibraryUsageDescription</key>
/// <string>Photo library access is needed to attach images to your message.</string>
/// <key>NSCameraUsageDescription</key>
/// <string>Camera access is needed to attach a new photo to your message.</string>
/// ```
///
/// **Android** — add to `android/app/src/main/AndroidManifest.xml`:
/// ```xml
/// <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
/// <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
/// ```
class ComposerAttachmentSheet extends StatefulWidget {
  /// Creates a [ComposerAttachmentSheet].
  const ComposerAttachmentSheet({super.key, required this.controller});

  /// The controller whose [ChatComposerController.attachments] and
  /// [ChatComposerController.chatOptions] this sheet reads and mutates.
  final ChatComposerController controller;

  @override
  State<ComposerAttachmentSheet> createState() => _ComposerAttachmentSheetState();
}

class _ComposerAttachmentSheetState extends State<ComposerAttachmentSheet> {
  static const int _recentPhotoLimit = 30;
  static const double _tileSize = 72;

  List<AssetEntity> _recentPhotos = const [];

  bool _isLoading = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRecentPhotos());
  }

  Future<void> _loadRecentPhotos() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final paths = await PhotoManager.getAssetPathList(onlyAll: true, type: RequestType.image);
      final assets = paths.isEmpty
          ? const <AssetEntity>[]
          : await paths.first.getAssetListRange(start: 0, end: _recentPhotoLimit);

      if (!mounted) return;
      setState(() {
        _recentPhotos = assets;
        _hasAccess = true;
        _isLoading = false;
      });
    } catch (error, stack) {
      // Every failure lands in the same "no access" state, so the camera tile
      // and chat options still render — but only one *kind* of failure is
      // expected: no platform gallery implementation (web, desktop without
      // native setup, a test environment). Anything else used to be swallowed
      // into the same dead end, sending the user to Settings, where access was
      // already granted, and back to the same empty strip with no diagnostic
      // anywhere.
      if (!_isMissingImplementation(error)) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'stream_chat_flutter_ai',
            context: ErrorDescription('while loading recent photos for the composer attachment sheet'),
          ),
        );
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Whether [error] means "this platform has no gallery plugin" rather than
  /// "the gallery failed".
  static bool _isMissingImplementation(Object error) => error is MissingPluginException || error is UnimplementedError;

  /// Whether [asset] is currently among the controller's attachments.
  ///
  /// Derived rather than tracked: the composer's own thumbnail ✕ removes
  /// attachments behind the sheet's back, and the sheet is rebuilt from
  /// scratch every time it opens.
  bool _isSelected(AssetEntity asset) {
    // `peek`, not `get`: this runs from `build`, twice per tile, and marking an
    // entry most-recently-used from there would make the cache's recency track
    // paint order rather than use.
    final path = _assetPathCache.peek(asset.id);
    return path != null && widget.controller.hasAttachmentAt(path);
  }

  Future<void> _toggleAsset(AssetEntity asset) async {
    final cachedPath = _assetPathCache.get(asset.id);
    if (cachedPath != null && widget.controller.hasAttachmentAt(cachedPath)) {
      widget.controller.removeAttachment(XFile(cachedPath));
      return;
    }

    // Always re-resolved when adding, never taken from the cache: on iOS the
    // path points at a temporary copy the system is free to purge, so a cached
    // one is only trustworthy for as long as the attachment referencing it
    // lives.
    final path = (await asset.file)?.path;
    if (path == null || !mounted) return;
    _assetPathCache.set(asset.id, path);
    widget.controller.addAttachments([XFile(path)]);
  }

  Future<void> _pickFromCamera() async {
    // The platform picker is a separate activity on Android, so the host can be
    // recreated behind it — hence the `mounted` check on the way back, before
    // touching a controller whose owner may be gone.
    final photo = await _guardPicker(() => ImagePicker().pickImage(source: ImageSource.camera));
    if (photo == null || !mounted) return;
    widget.controller.addAttachments([photo]);
  }

  Future<void> _pickFromFullLibrary() async {
    final remaining = widget.controller.remainingAttachmentSlots;
    if (remaining <= 0) return;

    // `pickMultiImage` rejects a limit below 2, so the last free slot has to be
    // filled by the single-image picker instead.
    final List<XFile>? photos;
    if (remaining == 1) {
      final photo = await _guardPicker(() => ImagePicker().pickImage(source: ImageSource.gallery));
      photos = photo == null ? const [] : [photo];
    } else {
      photos = await _guardPicker(() => ImagePicker().pickMultiImage(limit: remaining));
    }
    if (photos == null || photos.isEmpty || !mounted) return;
    widget.controller.addAttachments(photos);
  }

  /// Runs a picker call, reporting rather than rethrowing a platform failure.
  ///
  /// Both callers are tap handlers, so an escaping `PlatformException` — a
  /// camera that isn't available, a permission revoked while the picker was up
  /// — became an unhandled async error: nothing happens, and nothing says why.
  Future<T?> _guardPicker<T>(Future<T?> Function() pick) async {
    try {
      return await pick();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'stream_chat_flutter_ai',
          context: ErrorDescription('while picking an image for the composer'),
        ),
      );
      return null;
    }
  }

  void _selectChatOption(ChatOption option) {
    widget.controller.selectChatOption(option);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilt from the controller so the checkmarks track
    // `ChatComposerController.attachments` rather than a private copy of it —
    // removing a photo via the composer's own thumbnail ✕ clears its checkmark
    // here too, and reaching the cap greys out the tiles that can no longer be
    // added.
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chatOptions = widget.controller.chatOptions;
    final atCapacity = widget.controller.remainingAttachmentSlots <= 0;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Text('Photos', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: atCapacity ? null : _pickFromFullLibrary,
                    child: const Text('All Photos'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: _tileSize,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CameraTile(onTap: atCapacity ? null : _pickFromCamera),
                  const SizedBox(width: 8),
                  if (_isLoading)
                    const SizedBox(
                      width: _tileSize,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!_hasAccess)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: TextButton(
                          onPressed: PhotoManager.openSetting,
                          child: Text('Allow photo access'),
                        ),
                      ),
                    )
                  else
                    for (final asset in _recentPhotos) ...[
                      _RecentPhotoTile(
                        asset: asset,
                        selected: _isSelected(asset),
                        // Deselecting stays available at the cap; only *adding*
                        // is blocked.
                        onTap: atCapacity && !_isSelected(asset) ? null : () => _toggleAsset(asset),
                      ),
                      const SizedBox(width: 8),
                    ],
                ],
              ),
            ),
            if (chatOptions.isNotEmpty) ...[
              Divider(height: 24, color: colorScheme.outlineVariant),
              for (final option in chatOptions) _ChatOptionTile(option: option, onTap: () => _selectChatOption(option)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.onTap});

  /// `null` once the composer is holding its maximum attachments, which
  /// disables the tile.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(12);
    final iconColor = onTap == null ? colorScheme.onSurface.withValues(alpha: 0.3) : colorScheme.onSurface;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: borderRadius,
      ),
      // Above the fill, so the ink splash is actually visible.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Tooltip(
            message: 'Take a photo',
            child: Center(child: Icon(Icons.camera_alt_outlined, color: iconColor)),
          ),
        ),
      ),
    );
  }
}

class _RecentPhotoTile extends StatefulWidget {
  const _RecentPhotoTile({required this.asset, required this.selected, required this.onTap});

  final AssetEntity asset;
  final bool selected;

  /// `null` when the composer is at its attachment cap and this photo isn't one
  /// of the attached ones, which disables the tile.
  final VoidCallback? onTap;

  @override
  State<_RecentPhotoTile> createState() => _RecentPhotoTileState();
}

class _RecentPhotoTileState extends State<_RecentPhotoTile> {
  /// Held in state rather than started inside `build`.
  ///
  /// Toggling one photo rebuilds the whole sheet, so a future created in `build`
  /// re-requested every visible thumbnail from the platform on each selection.
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(200));
  }

  @override
  void didUpdateWidget(covariant _RecentPhotoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.asset.id != oldWidget.asset.id) {
      _thumbnail = widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(200));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selected = widget.selected;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Opacity(
                // Dimmed when the cap makes this photo unpickable, so the tile
                // reads as unavailable rather than unresponsive.
                opacity: widget.onTap == null ? 0.4 : 1,
                child: FutureBuilder<Uint8List?>(
                  future: _thumbnail,
                  builder: (context, snapshot) {
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return ColoredBox(color: colorScheme.surfaceContainerHigh);
                    }
                    return Image.memory(bytes, fit: BoxFit.cover);
                  },
                ),
              ),
            ),
            if (selected)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary, width: 3),
                ),
              ),
            if (selected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(color: colorScheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatOptionTile extends StatelessWidget {
  const _ChatOptionTile({required this.option, required this.onTap});

  final ChatOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: option.icon != null ? Icon(option.icon, color: colorScheme.onSurface) : null,
      title: Text(option.text),
      subtitle: option.description != null ? Text(option.description!) : null,
      onTap: onTap,
    );
  }
}
