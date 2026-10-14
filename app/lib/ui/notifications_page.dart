import 'package:flutter/material.dart';
import 'package:niyah_core/niyah_core.dart' as core;

import '../data/catalog_repository.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import '../state/app_scope.dart';
import '../theme/niyah_theme.dart';
import 'widgets.dart';

class _Data {
  const _Data(this.templates, this.reminders, this.contentCounts);

  final List<TemplateItem> templates;
  final Map<String, core.Reminder> reminders;
  final Map<String, int> contentCounts;
}

/// "Le mie notifiche": il cuore dell'app (architettura §2.2).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  Future<_Data>? _data;
  String? _lang;

  Future<_Data> _load(AppController c) async => _Data(
        await c.catalog.templates(c.settings.language),
        await c.reminders.templateReminders(),
        await c.catalog.contentCounts(c.settings.language),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si ricarica a ogni notifica del controller (modifica, lingua…).
    final c = AppScope.of(context);
    _lang = c.settings.language;
    _data = _load(c);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navNotifications)),
      body: FutureBuilder<_Data>(
        key: ValueKey(_lang),
        future: _data,
        builder: (context, snap) {
          final data = snap.data;
          if (data == null) {
            return snap.hasError ? EmptyState(text: l.genericError, icon: Icons.error_outline) : const SizedBox.shrink();
          }
          List<TemplateItem> section(Set<String> names) =>
              data.templates.where((t) => names.contains(t.section)).toList();
          final suggested = section({'suggested'});
          final content = section({'content'})
              .where((t) => t.contentType != null && (data.contentCounts[t.contentType] ?? 0) > 0)
              .toList();
          final weekly = section({'weekly', 'seasonal'});
          return NiyahPage(
            children: [
              if (c.notificationsEnabled == false)
                NoticeBanner(text: l.notificationsOff, actionLabel: l.openSettings, onAction: c.gateway.openSettings),
              if (suggested.isNotEmpty) ...[
                SectionHeader(l.sectionSuggested),
                _TemplateGroup(templates: suggested, reminders: data.reminders),
              ],
              SectionHeader(l.sectionContent),
              if (content.isEmpty)
                EmptyState(text: l.contentComingSoon, icon: Icons.menu_book_outlined)
              else
                _TemplateGroup(templates: content, reminders: data.reminders),
              if (weekly.isNotEmpty) ...[
                SectionHeader(l.sectionWeekly),
                _TemplateGroup(templates: weekly, reminders: data.reminders),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TemplateGroup extends StatelessWidget {
  const _TemplateGroup({required this.templates, required this.reminders});

  final List<TemplateItem> templates;
  final Map<String, core.Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    return RowGroup(
      children: [for (final t in templates) TemplateTile(template: t, reminder: reminders[t.id])],
    );
  }
}

/// Un modello con il suo interruttore. Toccandolo si cambiano orario e giorni.
class TemplateTile extends StatelessWidget {
  const TemplateTile({super.key, required this.template, this.reminder});

  final TemplateItem template;
  final core.Reminder? reminder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final r = reminder;
    final on = r?.enabled ?? false;
    final summary = r != null
        ? scheduleSummary(context,
            type: r.scheduleType, time: r.time, daysMask: r.daysMask, windowStart: r.windowStart, windowEnd: r.windowEnd)
        : scheduleSummary(context,
            type: template.schedule.type,
            time: template.schedule.time,
            daysMask: template.schedule.daysMask,
            windowStart: template.schedule.windowStart,
            windowEnd: template.schedule.windowEnd);
    final muted = on && c.lastSummary.mutedByQuietHours.contains(r!.id);
    final editable = r != null && on && r.time != null && r.scheduleType != core.ScheduleType.window;
    return MergeSemantics(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: NiyahSpace.m, end: NiyahSpace.s),
        title: Text(template.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: NiyahSpace.xs),
            Text(template.body),
            const SizedBox(height: NiyahSpace.xs),
            Text(summary, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
            if (muted)
              Padding(
                padding: const EdgeInsets.only(top: NiyahSpace.xs),
                child: Text(l.mutedByQuietHours, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: Switch(
          value: on,
          onChanged: (v) => c.setTemplateEnabled(template, v),
        ),
        onTap: editable ? () => showFixedScheduleSheet(context, title: template.title, reminder: r) : null,
      ),
    );
  }
}

/// Orario e giorni di un promemoria a orario fisso.
Future<void> showFixedScheduleSheet(BuildContext context, {required String title, required core.Reminder reminder}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FixedScheduleSheet(title: title, reminder: reminder),
  );
}

class _FixedScheduleSheet extends StatefulWidget {
  const _FixedScheduleSheet({required this.title, required this.reminder});

  final String title;
  final core.Reminder reminder;

  @override
  State<_FixedScheduleSheet> createState() => _FixedScheduleSheetState();
}

class _FixedScheduleSheetState extends State<_FixedScheduleSheet> {
  late core.LocalTime _time = widget.reminder.time ?? const core.LocalTime(8, 0);
  late int _mask = widget.reminder.scheduleType == core.ScheduleType.daily ? core.DaysMask.all : widget.reminder.daysMask;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute));
    if (picked != null) setState(() => _time = core.LocalTime(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final valid = _mask & core.DaysMask.all != 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(NiyahSpace.l, 0, NiyahSpace.l, NiyahSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: NiyahSpace.l),
            RowGroup(children: [
              SettingRow(title: l.time, value: formatTime(context, _time), icon: Icons.schedule, onTap: _pickTime),
            ]),
            const SizedBox(height: NiyahSpace.l),
            Text(l.days, style: theme.textTheme.titleSmall),
            const SizedBox(height: NiyahSpace.s),
            DaysSelector(mask: _mask, onChanged: (m) => setState(() => _mask = m)),
            if (!valid)
              Padding(
                padding: const EdgeInsets.only(top: NiyahSpace.s),
                child: Text(l.errorDaysRequired, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: NiyahSpace.l),
            FilledButton(
              onPressed: valid
                  ? () async {
                      final nav = Navigator.of(context);
                      await AppScope.read(context).updateFixedSchedule(widget.reminder.id, _time, _mask);
                      nav.pop();
                    }
                  : null,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
