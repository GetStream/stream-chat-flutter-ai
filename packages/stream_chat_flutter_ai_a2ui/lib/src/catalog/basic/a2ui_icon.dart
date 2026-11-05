import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/a2ui_component_scope.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/catalog/basic/a2ui_debug_log.dart';

/// Builds an `Icon`: the icon of A2UI's basic catalog its `name` names, or a
/// shape the agent draws with an `svgPath` in a 24 by 24 box, in the color of
/// the surrounding [IconTheme].
///
/// A name the catalog doesn't have, a missing name and a path that can't be
/// drawn show a help icon. A named icon's name is its accessibility label; an
/// icon drawn from a path has none.
///
/// Internal to the package.
@internal
Widget buildA2UIIcon(BuildContext context, A2UIComponentScope scope) {
  final name = scope.value('name');
  if (name case {'svgPath': final String path}) return _A2UISvgIcon(path: path);
  final label = name is String ? name : null;
  return Icon(a2uiIcons[label] ?? _fallback, semanticLabel: label);
}

// What an icon the catalog doesn't have shows.
const _fallback = Icons.help_rounded;

/// The icon of each name of A2UI's basic catalog, as rounded Material icons.
///
/// Internal to the package.
@internal
const Map<String, IconData> a2uiIcons = {
  'accountCircle': Icons.account_circle_rounded,
  'add': Icons.add_rounded,
  'arrowBack': Icons.arrow_back_rounded,
  'arrowForward': Icons.arrow_forward_rounded,
  'attachFile': Icons.attach_file_rounded,
  'calendarToday': Icons.calendar_today_rounded,
  'call': Icons.call_rounded,
  'camera': Icons.photo_camera_rounded,
  'check': Icons.check_rounded,
  'close': Icons.close_rounded,
  'delete': Icons.delete_rounded,
  'download': Icons.download_rounded,
  'edit': Icons.edit_rounded,
  'event': Icons.event_available_rounded,
  'error': Icons.error_rounded,
  'fastForward': Icons.fast_forward_rounded,
  'favorite': Icons.favorite_rounded,
  'favoriteOff': Icons.favorite_border_rounded,
  'folder': Icons.folder_rounded,
  'help': Icons.help_rounded,
  'home': Icons.home_rounded,
  'info': Icons.info_rounded,
  'locationOn': Icons.location_on_rounded,
  'lock': Icons.lock_rounded,
  'lockOpen': Icons.lock_open_rounded,
  'mail': Icons.email_rounded,
  'menu': Icons.menu_rounded,
  'moreVert': Icons.more_vert_rounded,
  'moreHoriz': Icons.more_horiz_rounded,
  'notificationsOff': Icons.notifications_off_rounded,
  'notifications': Icons.notifications_rounded,
  'pause': Icons.pause_rounded,
  'payment': Icons.credit_card_rounded,
  'person': Icons.person_rounded,
  'phone': Icons.phone_rounded,
  'photo': Icons.image_rounded,
  'play': Icons.play_arrow_rounded,
  'print': Icons.print_rounded,
  'refresh': Icons.refresh_rounded,
  'rewind': Icons.fast_rewind_rounded,
  'search': Icons.search_rounded,
  'send': Icons.send_rounded,
  'settings': Icons.settings_rounded,
  'share': Icons.share_rounded,
  'shoppingCart': Icons.shopping_cart_rounded,
  'skipNext': Icons.skip_next_rounded,
  'skipPrevious': Icons.skip_previous_rounded,
  'star': Icons.star_rounded,
  'starHalf': Icons.star_half_rounded,
  'starOff': Icons.star_border_rounded,
  'stop': Icons.stop_rounded,
  'upload': Icons.upload_rounded,
  'visibility': Icons.visibility_rounded,
  'visibilityOff': Icons.visibility_off_rounded,
  'volumeDown': Icons.volume_down_rounded,
  'volumeMute': Icons.volume_mute_rounded,
  'volumeOff': Icons.volume_off_rounded,
  'volumeUp': Icons.volume_up_rounded,
  'warning': Icons.warning_rounded,
};

// A shape the agent draws with the SVG path [path], filled in the icon color.
class _A2UISvgIcon extends StatelessWidget {
  const _A2UISvgIcon({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final icon = IconTheme.of(context);
    final size = icon.size ?? _viewBox;
    final color = icon.color;
    return SvgPicture.string(
      a2uiSvgOf(path),
      width: size,
      height: size,
      colorFilter: color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
      errorBuilder: (context, error, stackTrace) {
        a2uiDebugLogOnce("The Icon svgPath '$path' can't be drawn: $error");
        return Icon(_fallback, size: size);
      },
    );
  }
}

// The box the agent draws a path in.
const _viewBox = 24.0;

/// An SVG document of the path [path] in a 24 by 24 box.
///
/// The path is the agent's text, so it is escaped for the attribute it is
/// placed in and can't add markup to the document.
///
/// Internal to the package.
@internal
String a2uiSvgOf(String path) {
  final escaped = path
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $_viewBox $_viewBox"><path d="$escaped"/></svg>';
}
