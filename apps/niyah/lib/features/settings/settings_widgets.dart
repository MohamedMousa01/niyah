import 'package:flutter/material.dart';

import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';

/// Row of a settings card that opens a sheet or a screen: title, current
/// value below it and a chevron. One button for screen readers.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.title, required this.value, required this.onTap, this.icon});

  final String title;
  final String value;
  final VoidCallback onTap;

  /// Optional [NiyahIcons] key shown in a tile at the start.
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Semantics(
      button: true,
      label: '$title, $value',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
            child: Row(
              children: [
                if (icon != null) ...[IconTile(icon: icon!, size: 36, radius: 11, iconSize: 18), const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: NiyahText.sans(15, weight: FontWeight.w600, color: c.text)),
                      const SizedBox(height: 2),
                      Text(value, style: NiyahText.sans(13.5, height: 1.35, color: c.text2)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                NiyahIcon(NiyahIcons.chevronRight, size: 20, strokeWidth: 1.8, color: c.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row with a [NiyahSwitch]: title, a note below and the switch at the end.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.note,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String note;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
      child: Row(
        children: [
          if (icon != null) ...[IconTile(icon: icon!, size: 36, radius: 11, iconSize: 18), const SizedBox(width: 12)],
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: NiyahText.sans(15, weight: FontWeight.w600, color: c.text)),
                  const SizedBox(height: 2),
                  Text(note, style: NiyahText.sans(13.5, height: 1.35, color: c.text2)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          NiyahSwitch(value: value, onChanged: onChanged, semanticLabel: '$title. $note'),
        ],
      ),
    );
  }
}

/// One option of a single-choice list (language, method, pause length):
/// title, optional subtitle and a check mark when [selected].
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({super.key, required this.title, this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: subtitle == null ? title : '$title, $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: NiyahText.sans(15, weight: selected ? FontWeight.w700 : FontWeight.w500, color: c.text),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: NiyahText.sans(13, height: 1.35, color: c.primaryInk)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox.square(
                  dimension: 22,
                  child: selected ? NiyahIcon(NiyahIcons.check, size: 22, strokeWidth: 2.2, color: c.primaryInk) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card of rows separated by [RowDivider]s.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => NiyahCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[if (i > 0) const RowDivider(), child],
      ],
    ),
  );
}

/// 13 px `text2` note under a card.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
    child: Text(text, style: NiyahText.sans(13, height: 1.45, color: context.niyah.text2)),
  );
}
