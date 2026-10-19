import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The stroke icons of the design (24×24 grid, round caps and joins), keyed by
/// name. Template icon keys from the seed resolve here too.
abstract final class NiyahIcons {
  static const home = 'home';
  static const bell = 'bell';
  static const sliders = 'sliders';
  static const chevronRight = 'chevron';
  static const chevronLeft = 'back';
  static const chevronUp = 'chevronUp';
  static const chevronDown = 'chevronDown';
  static const plus = 'plus';
  static const minus = 'minus';
  static const arrow = 'arrow';
  static const mosque = 'mosque';
  static const heart = 'heart';
  static const sunrise = 'sunrise';
  static const moon = 'moon';
  static const work = 'work';
  static const book = 'book';
  static const family = 'family';
  static const bed = 'bed';
  static const calendar = 'calendar';
  static const renew = 'renew';
  static const chat = 'chat';
  static const pencil = 'pencil';
  static const clock = 'clock';
  static const trash = 'trash';
  static const close = 'close';
  static const check = 'check';

  /// Inner SVG elements of each icon.
  static const Map<String, String> svg = {
    home: '<path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-4.5v-6h-5v6H5a1 1 0 0 1-1-1z"/>',
    bell: '<path d="M6 16v-5a6 6 0 1 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
    sliders: '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>',
    chevronRight: '<path d="m9 6 6 6-6 6"/>',
    chevronLeft: '<path d="m15 6-6 6 6 6"/>',
    chevronUp: '<path d="m6 15 6-6 6 6"/>',
    chevronDown: '<path d="m6 9 6 6 6-6"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
    mosque: '<path d="M5 20v-8a7 7 0 0 1 14 0v8zM12 5V3M3 20h18M10 20v-4a2 2 0 0 1 4 0v4"/>',
    heart: '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10z"/>',
    sunrise: '<path d="M4 18h16M7 14a5 5 0 0 1 10 0M12 4v3M5 9l1.5 1.5M19 9l-1.5 1.5"/>',
    moon: '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
    work: '<path d="M5.5 7.5h13a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2v-8a2 2 0 0 1 2-2zM9 7.5V6a1.5 1.5 0 0 1 1.5-1.5h3A1.5 1.5 0 0 1 15 6v1.5M3.5 12.5h17"/>',
    book: '<path d="M4 5.5A1.5 1.5 0 0 1 5.5 4H11v16H5.5A1.5 1.5 0 0 1 4 18.5zM20 5.5A1.5 1.5 0 0 0 18.5 4H13v16h5.5a1.5 1.5 0 0 0 1.5-1.5z"/>',
    family: '<path d="M9 5a3 3 0 1 0 0 6a3 3 0 1 0 0-6zM3.5 19a5.5 5.5 0 0 1 11 0M17 7.2a2.3 2.3 0 1 0 0 4.6a2.3 2.3 0 1 0 0-4.6zM15.5 14.2A4.5 4.5 0 0 1 21 18.5"/>',
    bed: '<path d="M3 18V7M3 13h18v5M21 13a3 3 0 0 0-3-3h-7v3"/>',
    calendar: '<path d="M6 5.5h12a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7.5a2 2 0 0 1 2-2zM4 10h16M8.5 3.5v4M15.5 3.5v4"/>',
    renew: '<path d="M19 12a7 7 0 1 1-2.05-4.95M19 4v4h-4"/>',
    chat: '<path d="M5 5.5h14a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5H10l-4.5 3.5V16.5H5A1.5 1.5 0 0 1 3.5 15V7A1.5 1.5 0 0 1 5 5.5z"/>',
    pencil: '<path d="M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4"/>',
    clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
    trash: '<path d="M4.5 7h15M9.5 7V5a1 1 0 0 1 1-1h3a1 1 0 0 1 1 1v2M6.5 7l1 12a1.5 1.5 0 0 0 1.5 1.4h6a1.5 1.5 0 0 0 1.5-1.4l1-12"/>',
    close: '<path d="M6 6l12 12M18 6 6 18"/>',
    check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
    // Not drawn in the artboards; same stroke style, for seed keys.
    'sun': '<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6 7 7M17 17l1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4"/>',
    'sunset': '<path d="M4 18h16M7 14a5 5 0 0 1 10 0M12 3v5M9.5 5.5 12 8l2.5-2.5"/>',
    'star': '<path d="m12 4 2.4 4.9 5.4.8-3.9 3.8.9 5.4-4.8-2.5-4.8 2.5.9-5.4-3.9-3.8 5.4-.8z"/>',
    'pin': '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.5"/>',
    'search': '<circle cx="11" cy="11" r="6.5"/><path d="m16 16 4 4"/>',
    'pause': '<path d="M9 6v12M15 6v12"/>',
    'globe': '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.5 2.6 3.5 5.4 3.5 8.5s-1 5.9-3.5 8.5c-2.5-2.6-3.5-5.4-3.5-8.5s1-5.9 3.5-8.5z"/>',
    'sparkle': '<path d="M12 4c.6 4.2 1.8 5.4 6 6-4.2.6-5.4 1.8-6 6-.6-4.2-1.8-5.4-6-6 4.2-.6 5.4-1.8 6-6z"/>',
  };

  /// Other names used by the seed and the design for the same drawings.
  static const Map<String, String> aliases = {
    'cal': calendar,
    'bedtime': bed,
    'refresh': renew,
    'prayer': mosque,
    'edit': pencil,
  };

  /// Drawn for unknown keys, so a new seed icon never breaks a row.
  static const fallback = 'sparkle';

  static bool has(String name) => svg.containsKey(name) || aliases.containsKey(name);

  static String elementsOf(String name) => svg[aliases[name] ?? name] ?? svg[fallback]!;
}

/// One [NiyahIcons] icon, stroked in [color] (default: the ambient icon colour).
/// Decorative: hidden from screen readers, as `aria-hidden` in the design.
class NiyahIcon extends StatelessWidget {
  const NiyahIcon(this.name, {super.key, this.size = 24, this.strokeWidth = 1.7, this.color});

  final String name;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? const Color(0xFF000000);
    final source =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" '
        'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">${NiyahIcons.elementsOf(name)}</svg>';
    return ExcludeSemantics(
      child: SvgPicture.string(
        source,
        width: size,
        height: size,
        theme: SvgTheme(currentColor: c),
        // Keep the chevrons and arrows pointing forward in RTL.
        matchTextDirection:
            name == NiyahIcons.chevronRight || name == NiyahIcons.chevronLeft || name == NiyahIcons.arrow,
      ),
    );
  }
}
