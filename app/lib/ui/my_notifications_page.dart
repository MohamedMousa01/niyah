import 'package:flutter/material.dart';
import 'package:niyah_core/niyah_core.dart' as core;

import '../l10n/app_localizations.dart';
import '../state/app_scope.dart';
import '../theme/niyah_theme.dart';
import 'home_shell.dart';
import 'widgets.dart';

/// "Le mie notifiche": le notifiche scritte dall'utente, con testo, orario e
/// giorni scelti da lui.
class MyNotificationsPage extends StatefulWidget {
  const MyNotificationsPage({super.key});

  @override
  State<MyNotificationsPage> createState() => _MyNotificationsPageState();
}

class _MyNotificationsPageState extends State<MyNotificationsPage> {
  Future<List<core.Reminder>>? _reminders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si ricarica a ogni notifica del controller (nuova, modificata…).
    _reminders = AppScope.of(context).reminders.personalReminders();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navNotifications), actions: const [SettingsButton()]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.newNotification),
        onPressed: () => showPersonalEditor(context),
      ),
      body: FutureBuilder<List<core.Reminder>>(
        future: _reminders,
        builder: (context, snap) {
          final reminders = snap.data;
          if (reminders == null) {
            return snap.hasError ? EmptyState(text: l.genericError, icon: Icons.error_outline) : const SizedBox.shrink();
          }
          return NiyahPage(
            // Spazio in fondo perché il pulsante non copra l'ultima riga.
            padding: const EdgeInsets.fromLTRB(NiyahSpace.m, NiyahSpace.s, NiyahSpace.m, 96),
            children: [
              if (c.notificationsEnabled == false)
                NoticeBanner(text: l.notificationsOff, actionLabel: l.openSettings, onAction: c.gateway.openSettings),
              if (reminders.isEmpty)
                EmptyState(text: l.personalEmpty, icon: Icons.edit_notifications_outlined)
              else ...[
                const SizedBox(height: NiyahSpace.s),
                RowGroup(children: [for (final r in reminders) _PersonalTile(reminder: r)]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PersonalTile extends StatelessWidget {
  const _PersonalTile({required this.reminder});

  final core.Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final r = reminder;
    final title = (r.title ?? '').isNotEmpty ? r.title! : r.body ?? '';
    final body = (r.title ?? '').isNotEmpty ? r.body : null;
    final summary = scheduleSummary(context, type: r.scheduleType, time: r.time, daysMask: r.daysMask);
    final muted = r.enabled && c.lastSummary.mutedByQuietHours.contains(r.id);
    return MergeSemantics(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.only(start: NiyahSpace.m, end: NiyahSpace.s),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body != null && body.isNotEmpty) ...[
              const SizedBox(height: NiyahSpace.xs),
              Text(body),
            ],
            const SizedBox(height: NiyahSpace.xs),
            Text(summary, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
            if (muted)
              Padding(
                padding: const EdgeInsets.only(top: NiyahSpace.xs),
                child: Text(l.mutedByQuietHours, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ),
          ],
        ),
        trailing: Switch(value: r.enabled, onChanged: (v) => c.setReminderEnabled(r.id, v)),
        onTap: () => showPersonalEditor(context, reminder: r),
      ),
    );
  }
}

/// Editor di una notifica personalizzata: nuova se [reminder] è null.
Future<void> showPersonalEditor(BuildContext context, {core.Reminder? reminder}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PersonalEditor(reminder: reminder),
  );
}

class _PersonalEditor extends StatefulWidget {
  const _PersonalEditor({this.reminder});

  final core.Reminder? reminder;

  @override
  State<_PersonalEditor> createState() => _PersonalEditorState();
}

class _PersonalEditorState extends State<_PersonalEditor> {
  late final _title = TextEditingController(text: widget.reminder?.title ?? '');
  late final _body = TextEditingController(text: widget.reminder?.body ?? '');
  late core.LocalTime _time = widget.reminder?.time ?? const core.LocalTime(9, 0);
  late int _mask = widget.reminder == null || widget.reminder!.scheduleType == core.ScheduleType.daily
      ? core.DaysMask.all
      : widget.reminder!.daysMask;
  bool _triedSave = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _hasText => _title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;
  bool get _hasDays => _mask & core.DaysMask.all != 0;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: _time.hour, minute: _time.minute));
    if (picked != null) setState(() => _time = core.LocalTime(picked.hour, picked.minute));
  }

  Future<void> _save() async {
    setState(() => _triedSave = true);
    if (!_hasText || !_hasDays) return;
    final nav = Navigator.of(context);
    await AppScope.read(context).savePersonal(
      id: widget.reminder?.id,
      title: _title.text,
      body: _body.text,
      time: _time,
      daysMask: _mask,
    );
    nav.pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final controller = AppScope.read(context);
    final nav = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.deleteReminder(widget.reminder!.id);
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        // Il foglio sale sopra la tastiera.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(NiyahSpace.l, 0, NiyahSpace.l, NiyahSpace.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.reminder == null ? l.newNotification : l.editNotification, style: theme.textTheme.titleLarge),
              const SizedBox(height: NiyahSpace.l),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.fieldTitle, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: NiyahSpace.m),
              TextField(
                controller: _body,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_triedSave) setState(() {});
                },
                decoration: InputDecoration(
                  labelText: l.fieldText,
                  border: const OutlineInputBorder(),
                  errorText: _triedSave && !_hasText ? l.errorTextRequired : null,
                ),
              ),
              const SizedBox(height: NiyahSpace.l),
              RowGroup(children: [
                SettingRow(title: l.time, value: formatTime(context, _time), icon: Icons.schedule, onTap: _pickTime),
              ]),
              const SizedBox(height: NiyahSpace.l),
              Text(l.days, style: theme.textTheme.titleSmall),
              const SizedBox(height: NiyahSpace.s),
              DaysSelector(mask: _mask, onChanged: (m) => setState(() => _mask = m)),
              if (!_hasDays)
                Padding(
                  padding: const EdgeInsets.only(top: NiyahSpace.s),
                  child: Text(l.errorDaysRequired, style: TextStyle(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: NiyahSpace.l),
              FilledButton(onPressed: _hasDays ? _save : null, child: Text(l.save)),
              if (widget.reminder != null) ...[
                const SizedBox(height: NiyahSpace.s),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l.delete),
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
