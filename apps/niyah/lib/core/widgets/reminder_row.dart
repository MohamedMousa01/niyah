import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/niyah_theme.dart';
import 'icon_tile.dart';
import 'niyah_card.dart';
import 'niyah_switch.dart';

/// A reminder inside a card: icon tile, title, body, "when" line and a switch.
///
/// When [enabled] is false the row is dimmed (62 % opacity) and the "when"
/// line reads "Off". [showDivider] draws the 1 px line above the row (every
/// row but the first). Tapping the text area calls [onTap]; the switch calls
/// [onChanged].
///
/// With a [trailing] widget (e.g. the add/added badge of "Add a reminder") the
/// switch is replaced and the whole row becomes the tap target.
class ReminderRow extends StatelessWidget {
  const ReminderRow({
    super.key,
    required this.icon,
    this.tone = IconTileTone.tint,
    required this.title,
    this.body,
    required this.when,
    this.enabled = true,
    this.onChanged,
    this.onTap,
    this.showDivider = false,
    this.trailing,
    this.semanticLabel,
  });

  final String icon;
  final IconTileTone tone;
  final String title;
  final String? body;
  final String when;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;
  final bool showDivider;
  final Widget? trailing;

  /// Label of the tap target; defaults to title, body and "when" read together.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final whenText = enabled ? when : AppLocalizations.of(context).off;

    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: NiyahText.sans(15, weight: FontWeight.w600, color: c.text),
        ),
        if (body != null && body!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(body!, style: NiyahText.sans(13.5, height: 1.4, color: c.text2)),
        ],
        const SizedBox(height: 5),
        Text(
          whenText,
          style: NiyahText.sans(12.5, weight: FontWeight.w600, color: c.primaryInk),
        ),
      ],
    );

    final main = Row(
      children: [
        IconTile(icon: icon, tone: tone),
        const SizedBox(width: 12),
        Expanded(child: texts),
      ],
    );

    final label = semanticLabel ?? [title, if (body != null && body!.isNotEmpty) body!, whenText].join('. ');

    final Widget row;
    if (trailing != null) {
      row = Semantics(
        button: true,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 12, 14),
            child: Row(
              children: [
                Expanded(child: main),
                const SizedBox(width: 12),
                trailing!,
              ],
            ),
          ),
        ),
      );
    } else {
      row = Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: onTap != null,
                label: label,
                onTap: onTap,
                excludeSemantics: true,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 0, 14), child: main),
                ),
              ),
            ),
            const SizedBox(width: 4),
            NiyahSwitch(value: enabled, onChanged: onChanged, semanticLabel: title),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) const RowDivider(),
        Opacity(opacity: enabled ? 1 : 0.62, child: row),
      ],
    );
  }
}
