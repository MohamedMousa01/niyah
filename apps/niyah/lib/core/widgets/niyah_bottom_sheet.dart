import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/niyah_theme.dart';
import 'icon_tile.dart';
import 'niyah_icons.dart';
import 'tap_area.dart';

/// Shows [builder]'s content in a modal bottom sheet over the design's scrim.
/// Wrap the content in a [NiyahBottomSheet].
Future<T?> showNiyahSheet<T>(BuildContext context, {required WidgetBuilder builder}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  useRootNavigator: true,
  backgroundColor: Colors.transparent,
  barrierColor: NiyahColors.scrim,
  elevation: 0,
  builder: builder,
);

/// Sheet body: `surface`, 28 px top radius, drag handle, at most 90 % of the
/// screen, scrolling when taller. Children are laid out with [gap] between
/// them (18 in the setup sheet, 12 in the delete sheet).
class NiyahBottomSheet extends StatelessWidget {
  const NiyahBottomSheet({
    super.key,
    required this.children,
    this.gap = 18,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 26),
    this.semanticLabel,
  });

  final List<Widget> children;
  final double gap;
  final EdgeInsets padding;

  /// Name of the dialog for screen readers (usually the sheet title).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final media = MediaQuery.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: semanticLabel != null,
      label: semanticLabel,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Material(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: padding.copyWith(bottom: padding.bottom + media.viewInsets.bottom + media.padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: c.inputBorder, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                for (final child in children) ...[SizedBox(height: gap), child],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Setup-sheet header: 44 px icon tile, 20 px bold title, 44 px close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, this.icon, required this.title, this.onClose});

  final String? icon;
  final String title;

  /// Defaults to popping the sheet.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Row(
      children: [
        if (icon != null) ...[IconTile(icon: icon!, size: 44, radius: 14, iconSize: 22), const SizedBox(width: 12)],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: NiyahText.sans(20, weight: FontWeight.w700, color: c.text),
            ),
          ),
        ),
        const SizedBox(width: 12),
        TapArea(
          onTap: onClose ?? () => Navigator.of(context).maybePop(),
          semanticLabel: AppLocalizations.of(context).close,
          child: NiyahIcon(NiyahIcons.close, size: 22, strokeWidth: 1.8, color: c.text2),
        ),
      ],
    );
  }
}

/// Quoted text on `quoteBg` (14 px radius): the template body in the setup
/// sheet, the message sample on the Prayer screen (with a [title]).
class QuoteBox extends StatelessWidget {
  const QuoteBox({super.key, this.title, required this.body, this.fontSize = 14.5});

  final String? title;
  final String body;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: c.quoteBg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: NiyahText.sans(15, weight: FontWeight.w700, color: c.text),
            ),
            const SizedBox(height: 4),
          ],
          Text(body, style: NiyahText.sans(fontSize, height: 1.45, color: c.textBody)),
        ],
      ),
    );
  }
}
