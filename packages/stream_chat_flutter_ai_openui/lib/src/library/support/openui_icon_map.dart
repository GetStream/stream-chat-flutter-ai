import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:stream_core_flutter/core.dart';

/// The icon of [name], or `null` when the design system has none for it.
///
/// [name] is a Lucide icon name, in any case and with spaces around it. A
/// name that isn't one is tried without its numeric parts and then with
/// trailing parts dropped one at a time (`arrow-up-right-2` finds
/// `arrow-up-right`, then `arrow-up`), and then [category] is tried. A name
/// with an `off`, `open`, `x` or `minus` part has no trailing part dropped, as
/// the shorter name would mean the opposite.
///
/// Internal to the package.
@internal
IconData? openUIIconOf(StreamIcons icons, String name, [String? category]) {
  final map = _maps[icons] ??= _map(icons);
  final key = name.trim().toLowerCase();
  final found = map[key] ?? _loose(key).map((candidate) => map[candidate]).nonNulls.firstOrNull;
  if (found != null) return found;
  final fallback = _categoryFallbacks[category?.trim().toLowerCase()];
  return fallback == null ? null : map[fallback];
}

/// What an icon is read as: [name] without its numeric parts, in lower case,
/// or `null` when nothing is left.
///
/// Internal to the package.
@internal
String? openUIIconLabel(String name) {
  final parts = name
      .split(RegExp(r'[-._\s]'))
      .where((part) => part.isNotEmpty && int.tryParse(part) == null)
      .join(' ')
      .toLowerCase();
  return parts.isEmpty ? null : parts;
}

Iterable<String> _loose(String key) sync* {
  if (key.length > 64) return;
  final parts = key.split('-');
  final withoutNumbers = parts.where((part) => int.tryParse(part) == null).join('-');
  if (withoutNumbers.isNotEmpty && withoutNumbers != key) yield withoutNumbers;
  // A part that negates or inverts the icon (`eye-off`, `lock-open`) means the
  // shorter name is not the icon asked for.
  if (parts.any(_inverting.contains)) return;
  for (var count = parts.length - 1; count >= 1; count--) {
    yield parts.take(count).join('-');
  }
}

const _inverting = {'off', 'open', 'x', 'minus'};

// The map of each design system icon set, made once.
final _maps = Expando<Map<String, IconData>>();

const _categoryFallbacks = {
  'accessibility': 'accessibility',
  'account': 'user',
  'arrows': 'arrow-right',
  'buildings': 'building',
  'charts': 'chart-line',
  'communication': 'message-square',
  'development': 'code',
  'files': 'file',
  'finance': 'dollar-sign',
  'layout': 'layout',
  'mail': 'mail',
  'notifications': 'bell',
  'people': 'users',
  'photography': 'camera',
  'security': 'shield',
  'social': 'share-2',
  'sports': 'trophy',
  'text': 'type',
  'time': 'clock',
  'navigation': 'map-pin',
  'multimedia': 'play',
  'devices': 'smartphone',
  'tools': 'settings',
  'weather': 'cloud',
};

// Lucide names the design system has an icon for, as the iOS map reads them.
Map<String, IconData> _map(StreamIcons i) => {
  'arrow-right': i.arrowRight,
  'arrow-left': i.arrowLeft,
  'arrow-up': i.arrowUp,
  'arrow-down': i.arrowDown,
  'arrow-up-right': i.arrowUpRight,
  'chevron-right': i.chevronRight,
  'chevron-left': i.chevronLeft,
  'chevron-up': i.chevronUp,
  'chevron-down': i.chevronDown,
  'external-link': i.arrowUpRight,
  'link': i.link,
  'link-2': i.link,
  'refresh-cw': i.refresh,
  'rotate-cw': i.refresh,
  'map-pin': i.location,
  'map-pinned': i.location,
  'locate': i.location,
  'navigation': i.location,
  'flag': i.flag,
  'check': i.checkmark,
  'check-circle': i.checkmark,
  'circle-check': i.checkmark,
  'check-circle-2': i.checkmark,
  'badge-check': i.verifiedFill,
  'x': i.xmark,
  'x-circle': i.xCircle,
  'circle-x': i.xCircle,
  'plus': i.plus,
  'minus': i.minus,
  'minus-circle': i.minusCircle,
  'circle-minus': i.minusCircle,
  'alert-triangle': i.exclamationTriangleFill,
  'triangle-alert': i.exclamationTriangleFill,
  'alert-circle': i.exclamationCircle,
  'circle-alert': i.exclamationCircle,
  'info': i.info,
  'help-circle': i.questionCircleFill,
  'circle-help': i.questionCircleFill,
  'ban': i.noSign,
  'star': i.starFill,
  'zap': i.bolt,
  'trophy': i.trophy,
  'award': i.trophy,
  'bell': i.bell,
  'bell-off': i.bellOff,
  'user': i.user,
  'user-round': i.account,
  'users': i.users,
  'users-round': i.users,
  'user-plus': i.userAdd,
  'user-minus': i.userRemove,
  'user-check': i.userCheck,
  'message-square': i.messageBubble,
  'message-circle': i.messageBubble,
  'messages-square': i.messageBubbles,
  'mail': i.send,
  'send': i.send,
  'phone': i.phoneFill,
  'phone-off': i.phoneDownFill,
  'video': i.video,
  'video-off': i.videoOffFill,
  'mic': i.voice,
  'mic-off': i.voiceOffFill,
  'megaphone': i.megaphone,
  'share': i.share,
  'share-2': i.share,
  'at-sign': i.mention,
  'languages': i.language,
  'clock': i.clock,
  'clock-3': i.clock,
  'history': i.clock,
  'file': i.file,
  'file-text': i.file,
  'files': i.copy,
  'folder': i.folder,
  'folder-open': i.folder,
  'bookmark': i.save,
  'quote': i.quote,
  'pen': i.edit,
  'pencil': i.edit,
  'edit': i.edit,
  'image': i.image,
  'images': i.gallery,
  'camera': i.camera,
  'download': i.download,
  'upload': i.upload,
  'save': i.save,
  'copy': i.copy,
  'trash': i.delete,
  'trash-2': i.delete,
  'archive': i.archive,
  'search': i.search,
  'eye': i.eyeFill,
  'list': i.reorder,
  'menu': i.menu,
  'more-horizontal': i.moreHorizontal,
  'ellipsis': i.moreHorizontal,
  'ellipsis-vertical': i.moreVerticalFill,
  'filter': i.slidersFill,
  'sliders': i.slidersFill,
  'sliders-horizontal': i.slidersFill,
  'settings': i.settings,
  'settings-2': i.settings,
  'cog': i.settings,
  'lock': i.lock,
  'unlock': i.unlock,
  'lock-open': i.unlock,
  'lock-keyhole-open': i.unlock,
  'shield': i.shield,
  'shield-check': i.shield,
  'globe': i.language,
  'chart-bar': i.statsFill,
  'bar-chart': i.statsFill,
  'bar-chart-2': i.statsFill,
  'chart-column': i.statsFill,
  'trending-up': i.statsFill,
  'pin': i.pin,
  'play': i.playFill,
  'pause': i.pauseFill,
  'smile': i.emoji,
  'terminal': i.command,
  'command': i.command,
};
