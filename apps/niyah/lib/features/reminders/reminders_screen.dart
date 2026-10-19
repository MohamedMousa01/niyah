import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import '../add_reminder/template_sheet.dart';
import 'notifications_off_row.dart';

/// "My reminders" tab (artboard `Reminders`): the user's own reminders, the
/// prayer card and the ready-made reminders they added.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  /// Template rows shown before "Show N more".
  static const visibleTemplates = 3;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> with WidgetsBindingObserver {
  bool _expanded = false;
  bool _notificationsOn = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may come back from the system settings.
    if (state == AppLifecycleState.resumed) _checkNotifications();
  }

  Future<void> _checkNotifications() async {
    if (!mounted) return;
    final on = await AppScope.of(context).notifications.areEnabled();
    if (mounted && on != _notificationsOn) setState(() => _notificationsOn = on);
  }

  Future<void> _setEnabled(ReminderItem r, bool value) async {
    final s = AppScope.of(context);
    if (value) await s.notifications.ensurePermission();
    await s.reminders.setEnabled(r.id, value);
    await _checkNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final s = AppScope.of(context);

    return ColoredBox(
      color: c.bg,
      child: Column(
        children: [
          _Header(onAdd: () => context.push(Routes.add)),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([s.reminders, s.settings]),
              builder: (context, _) {
                final all = s.reminders.all;
                final mine = [
                  for (final r in all)
                    if (r.source == ReminderSource.personal) r,
                ];
                final fromNiyah = [
                  for (final r in all)
                    if (r.source == ReminderSource.template) r,
                ];
                final anchors = s.settings.anchors;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    if (!_notificationsOn) ...[
                      NotificationsOffRow(onTap: s.notifications.openSystemSettings),
                      const SizedBox(height: 18),
                    ],
                    _Section(
                      label: l.sectionMine,
                      child: mine.isEmpty
                          ? _EmptyMine(onWrite: () => context.push(Routes.newReminder))
                          : NiyahCard(
                              child: Column(
                                children: [
                                  for (final (i, r) in mine.indexed)
                                    ReminderRow(
                                      key: ValueKey(r.id),
                                      icon: NiyahIcons.chat,
                                      tone: IconTileTone.warm,
                                      title: r.title ?? r.body ?? '',
                                      body: r.title == null ? null : r.body,
                                      when: scheduleText(l, r.schedule, anchors),
                                      enabled: r.enabled,
                                      showDivider: i > 0,
                                      onTap: () => context.push(Routes.edit(r.id)),
                                      onChanged: (v) => _setEnabled(r, v),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 26),
                    _Section(
                      label: l.sectionPrayer,
                      child: _PrayerCard(reminder: s.reminders.prayer),
                    ),
                    const SizedBox(height: 26),
                    _fromNiyah(context, fromNiyah, anchors),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fromNiyah(BuildContext context, List<ReminderItem> items, AnchorTimes anchors) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final lang = l.localeName;
    final templates = AppScope.of(context).templates;
    final hidden = items.length - RemindersScreen.visibleTemplates;
    final shown = _expanded || hidden <= 0 ? items : items.take(RemindersScreen.visibleTemplates);

    return _Section(
      label: l.sectionFromNiyah,
      footer: l.remindersFromNiyahNote,
      child: items.isEmpty
          ? null
          : NiyahCard(
              child: Column(
                children: [
                  for (final (i, r) in shown.indexed)
                    Builder(
                      builder: (context) {
                        final t = r.templateId == null ? null : templates.byId(r.templateId!, lang);
                        return ReminderRow(
                          key: ValueKey(r.id),
                          icon: t?.icon ?? NiyahIcons.heart,
                          title: t?.title ?? r.title ?? '',
                          body: t?.body ?? r.body,
                          when: scheduleText(l, r.schedule, anchors),
                          enabled: r.enabled,
                          showDivider: i > 0,
                          onTap: r.templateId == null ? null : () => showTemplateSheet(context, r.templateId!),
                          onChanged: (v) => _setEnabled(r, v),
                        );
                      },
                    ),
                  if (hidden > 0)
                    _MoreButton(
                      expanded: _expanded,
                      label: _expanded ? l.remindersShowLess : l.remindersShowMore(hidden),
                      colors: c,
                      onTap: () => setState(() => _expanded = !_expanded),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = ScreenTitle(title: l.remindersTitle, subtitle: l.remindersSubtitle);
    final add = _AddPill(label: l.remindersAdd, onTap: onAdd);
    // With very large text the pill moves under the title.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(24, NiyahInsets.top(context, 60), 20, 14),
      child: stacked
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 12), add])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                add,
              ],
            ),
    );
  }
}

class _AddPill extends StatelessWidget {
  const _AddPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.primary,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NiyahIcon(NiyahIcons.plus, size: 20, strokeWidth: 2, color: c.onPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: NiyahText.sans(15, weight: FontWeight.w600, color: c.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section label, its card and an optional footer note.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.footer});

  final String label;
  final Widget? child;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(label),
        if (child != null) ...[const SizedBox(height: 10), child!],
        if (footer != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(footer!, style: NiyahText.sans(13, height: 1.5, color: c.text2)),
          ),
        ],
      ],
    );
  }
}

class _EmptyMine extends StatelessWidget {
  const _EmptyMine({required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    return NiyahCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.remindersEmptyMine, style: NiyahText.sans(14, height: 1.45, color: c.text2)),
          NiyahTextButton(
            label: l.remindersEmptyMineAction,
            icon: NiyahIcons.pencil,
            fontSize: 14.5,
            center: false,
            onPressed: onWrite,
          ),
        ],
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({required this.reminder});

  final ReminderItem reminder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final schedule = reminder.schedule;
    final offset = schedule is PrayerSchedule ? schedule.offsetMin : 0;
    final prayers = schedule is PrayerSchedule ? schedule.prayers : const <Prayer>{};
    final title = offset > 0
        ? l.prayerCardBefore
        : offset == 0
        ? l.prayerCardAtAdhan
        : l.prayerCardAfter;
    final subtitle = !reminder.enabled || prayers.isEmpty
        ? l.off
        : l.cPrayerCardSummary(prayerList(l, prayers), prayerTimingLabel(l, offset));
    return LinkCard(
      icon: NiyahIcons.mosque,
      tone: IconTileTone.primary,
      title: title,
      subtitle: subtitle,
      onTap: () => context.push(Routes.prayer),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.expanded, required this.label, required this.colors, required this.onTap});

  final bool expanded;
  final String label;
  final NiyahColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const RowDivider(),
        Semantics(
          button: true,
          expanded: expanded,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: NiyahText.sans(14.5, weight: FontWeight.w600, color: colors.primaryInk),
                    ),
                  ),
                  const SizedBox(width: 6),
                  NiyahIcon(
                    expanded ? NiyahIcons.chevronUp : NiyahIcons.chevronDown,
                    size: 18,
                    strokeWidth: 2,
                    color: colors.primaryInk,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
