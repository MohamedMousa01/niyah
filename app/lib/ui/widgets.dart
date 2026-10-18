// Componenti riutilizzabili del design system (architettura §10).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:niyah_core/niyah_core.dart' as core;

import '../l10n/app_localizations.dart';
import '../theme/niyah_theme.dart';

/// Contenuto centrato con larghezza massima (tablet).
class NiyahPage extends StatelessWidget {
  const NiyahPage({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: NiyahSpace.maxContentWidth),
        child: ListView(
          padding: padding ?? const EdgeInsets.fromLTRB(NiyahSpace.m, NiyahSpace.s, NiyahSpace.m, NiyahSpace.xl),
          children: children,
        ),
      ),
    );
  }
}

/// "Niyah", la Bismillah piccola e discreta, la frase del giorno.
class NiyahHeader extends StatelessWidget {
  const NiyahHeader({super.key});

  /// U+FDFD: la Bismillah come singolo carattere Unicode (testo standard,
  /// non generato).
  static const bismillah = '﷽';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NiyahSpace.l),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Text(
              bismillah,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: NiyahTheme.arabicFont,
              ),
            ),
          ),
          const SizedBox(height: NiyahSpace.m),
          Text(
            l.appTitle,
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: NiyahSpace.s),
          Text(l.tagline, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(NiyahSpace.xs, NiyahSpace.l, NiyahSpace.xs, NiyahSpace.s),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Gruppo di righe dentro una card con separatori sottili.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: NiyahSpace.m, endIndent: NiyahSpace.m),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.title, this.value, this.icon, this.onTap});

  final String title;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: value == null ? null : Text(value!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Testo calmo al posto di un elenco vuoto.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, this.icon = Icons.hourglass_empty});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(NiyahSpace.l),
      child: Column(
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: NiyahSpace.m),
          Text(text, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Riga discreta di avviso (es. notifiche disattivate).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NiyahSpace.m, NiyahSpace.s, NiyahSpace.s, NiyahSpace.s),
        child: Row(
          children: [
            Icon(Icons.notifications_off_outlined, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: NiyahSpace.m),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

/// Sette giorni selezionabili, dal lunedì (bit 0) alla domenica (bit 6).
class DaysSelector extends StatelessWidget {
  const DaysSelector({super.key, required this.mask, required this.onChanged});

  final int mask;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Wrap(
      spacing: NiyahSpace.xs,
      runSpacing: NiyahSpace.xs,
      children: [
        for (var w = 1; w <= 7; w++)
          FilterChip(
            showCheckmark: false,
            label: Text(weekdayShort(locale, w)),
            selected: core.DaysMask.includes(mask, w),
            onSelected: (on) => onChanged(on ? mask | (1 << (w - 1)) : mask & ~(1 << (w - 1))),
          ),
      ],
    );
  }
}

/// Nome breve del giorno (1 = lunedì) nella lingua [locale].
String weekdayShort(String locale, int weekday) =>
    // 1 gennaio 2024 era un lunedì.
    DateFormat.E(locale).format(DateTime(2024, 1, weekday));

String formatTime(BuildContext context, core.LocalTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: t.hour, minute: t.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// "Ogni giorno alle 08:00", "lun, mar alle 09:00", "Tra le 09:00 e le 21:00".
String scheduleSummary(
  BuildContext context, {
  required core.ScheduleType type,
  core.LocalTime? time,
  int daysMask = core.DaysMask.all,
  core.LocalTime? windowStart,
  core.LocalTime? windowEnd,
}) {
  final l = AppLocalizations.of(context);
  if (type == core.ScheduleType.window && windowStart != null && windowEnd != null) {
    return l.betweenTimes(formatTime(context, windowStart), formatTime(context, windowEnd));
  }
  if (time == null) return '';
  final t = formatTime(context, time);
  if (daysMask & core.DaysMask.all == core.DaysMask.all) return l.everyDayAt(t);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final days = core.DaysMask.weekdays(daysMask).map((w) => weekdayShort(locale, w)).join(', ');
  return l.daysAt(days, t);
}
