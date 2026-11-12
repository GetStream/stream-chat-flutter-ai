import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/openui_component_scope.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_strings.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';
import 'package:stream_chat_flutter_ai_openui/src/view/openui_view_scope.dart';
import 'package:stream_core_flutter/core.dart';

/// Builds an `Image`: its `src` across the space it is given, 180 tall,
/// with rounded corners.
///
/// Internal to the package.
@internal
Widget buildOpenUIImage(BuildContext context, OpenUIComponentScope scope) {
  return _rounded(
    context,
    // The image has no text to size it, so its height is its own.
    SizedBox(
      height: _imageHeight,
      width: double.infinity,
      child: OpenUIRemoteImage(source: scope.string('src'), alt: scope.text('alt')),
    ),
  );
}

/// Builds an `ImageBlock`: its `src` across the space it is given, in a 16
/// to 9 frame, with rounded corners.
///
/// Internal to the package.
@internal
Widget buildOpenUIImageBlock(BuildContext context, OpenUIComponentScope scope) {
  return _rounded(
    context,
    AspectRatio(
      aspectRatio: 16 / 9,
      child: OpenUIRemoteImage(source: scope.string('src'), alt: scope.text('alt')),
    ),
  );
}

const _imageHeight = 180.0;
const _tileExtent = 100.0;

Widget _rounded(BuildContext context, Widget child) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(OpenUIViewScope.of(context).theme.mediumCornerRadius),
    child: child,
  );
}

/// Builds an `ImageGallery`: its `images` as wrapping tiles 100 square, which
/// open a preview of the images, one at a time.
///
/// It draws nothing without images.
///
/// Internal to the package.
@internal
Widget buildOpenUIImageGallery(BuildContext context, OpenUIComponentScope scope) {
  final images = [
    for (final image in openUIJsonList(scope.value('images')))
      if (image is Map<String, Object?>)
        _GalleryImage(
          src: image['src'] is String ? image['src']! as String : null,
          alt: image['alt'] is String ? image['alt']! as String : null,
          details: image['details'] is String ? image['details']! as String : null,
        ),
  ];
  if (images.isEmpty) return const SizedBox.shrink();
  return _Gallery(images: images);
}

class _GalleryImage {
  const _GalleryImage({this.src, this.alt, this.details});

  final String? src;
  final String? alt;
  final String? details;
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.images});

  final List<_GalleryImage> images;

  @override
  Widget build(BuildContext context) {
    final theme = OpenUIViewScope.of(context).theme;
    final spacing = theme.sSpacing;
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final (index, image) in images.indexed)
            // A tile holds an image, not text, so its side is its own.
            ConstrainedBox(
              constraints: BoxConstraints.tight(const Size.square(_tileExtent)),
              child: Semantics(
                button: true,
                // The tile is read by what it shows, and the image in it is not.
                label: image.alt,
                excludeSemantics: true,
                onTap: () => _preview(context, index),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _preview(context, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(theme.smallCornerRadius),
                    child: OpenUIRemoteImage(source: image.src, alt: image.alt, extent: _tileExtent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _preview(BuildContext context, int initial) {
    final view = OpenUIViewScope.of(context);
    final captured = InheritedTheme.capture(from: context, to: Navigator.of(context, rootNavigator: true).context);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: OpenUIStrings.done,
      pageBuilder: (dialogContext, _, _) => captured.wrap(
        OpenUIViewScope(
          runtime: view.runtime,
          library: view.library,
          theme: view.theme,
          mediaUrl: view.mediaUrl,
          openLink: view.openLink,
          isStreaming: view.isStreaming,
          unknownTypes: view.unknownTypes,
          child: _Preview(images: images, initial: initial),
        ),
      ),
    );
  }
}

class _Preview extends StatefulWidget {
  const _Preview({required this.images, required this.initial});

  final List<_GalleryImage> images;
  final int initial;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late final PageController _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  var _showChrome = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    final caption = current.details ?? current.alt;
    return StreamMediaViewer(
      showChrome: _showChrome,
      header: StreamAppBar(
        automaticallyImplyLeading: false,
        leading: StreamButton.icon(
          style: .secondary,
          type: .ghost,
          size: .small,
          icon: Icon(context.streamIcons.xmark),
          tooltip: OpenUIStrings.done,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      footer: caption == null || caption.isEmpty ? null : StreamBottomAppBar(title: Text(caption)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showChrome = !_showChrome),
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (index) => setState(() => _index = index),
          itemBuilder: (context, index) {
            final image = widget.images[index];
            return OpenUIRemoteImage(source: image.src, alt: image.alt, fit: BoxFit.contain);
          },
        ),
      ),
    );
  }
}
