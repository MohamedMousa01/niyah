import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'template_sheet.dart';

/// "Add a reminder" (artboard `AddReminder`): write your own, or pick a
/// ready-made moment and set it up in the sheet.
class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  /// Null = "All".
  TemplateGroup? _filter;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final templates = s.templates.templates(l.localeName);
    final groups = {
      for (final g in TemplateGroup.values)
        if (templates.any((t) => t.group == g)) g: [for (final t in templates) if (t.group == g) t],
    };
    final filter = groups.containsKey(_filter) ? _filter : null;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          BackHeader(title: l.addTitle, backLabel: l.backToReminders),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([s.reminders, s.settings]),
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                children: [
                  _OwnWords(onTap: () => context.push(Routes.newReminder)),
                  const SizedBox(height: 22),
                  const _OrDivider(),
                  const SizedBox(height: 22),
                  _Heading(title: l.addReadyMadeTitle, note: l.addReadyMadeNote),
                  const SizedBox(height: 12),
                  SegmentedControl<TemplateGroup?>(
                    values: [null, ...groups.keys],
                    selected: filter,
                    labelOf: (g) => _filterLabel(l, g),
                    onChanged: (g) => setState(() => _filter = g),
                    semanticLabel: l.addFilterLabel,
                    gap: 2,
                    fontSize: 13.5,
                  ),
                  for (final MapEntry(key: group, value: items) in groups.entries)
                    if (filter == null || filter == group) ...[
                      const SizedBox(height: 22),
                      _Group(title: _groupTitle(l, group), items: items),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _filterLabel(AppLocalizations l, TemplateGroup? g) => switch (g) {
    null => l.filterAll,
    TemplateGroup.prayer => l.filterPrayer,
    TemplateGroup.daily => l.filterDaily,
    TemplateGroup.dhikr => l.filterDhikr,
    TemplateGroup.weekly => l.filterWeekly,
  };

  static String _groupTitle(AppLocalizations l, TemplateGroup g) => switch (g) {
    TemplateGroup.prayer => l.groupPrayer,
    TemplateGroup.daily => l.groupDaily,
    TemplateGroup.dhikr => l.groupDhikr,
    TemplateGroup.weekly => l.groupWeekly,
  };
}

/// 18 px bold heading with a 13 px note under it.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: NiyahText.sans(18, weight: FontWeight.w700, color: c.text)),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: NiyahText.sans(13, height: 1.5, color: c.text2)),
          ],
        ],
      ),
    );
  }
}

/// "In your own words": the card that opens the editor.
class _OwnWords extends StatelessWidget {
  const _OwnWords({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: c.secondary, width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(title: l.addOwnWordsTitle),
        const SizedBox(height: 10),
        Semantics(
          button: true,
          label: l.addOwnWordsLabel,
          onTap: onTap,
          excludeSemantics: true,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(18)),
              boxShadow: [BoxShadow(color: Color(0x0F2E3532), offset: Offset(0, 1), blurRadius: 2)],
            ),
            child: Material(
              color: c.surface,
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: shape,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 10, 10),
                  child: Row(
                    children: [
                      NiyahIcon(NiyahIcons.pencil, size: 22, strokeWidth: 1.8, color: c.primaryInk),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l.addOwnWordsHint, style: NiyahText.sans(15.5, height: 1.35, color: c.text3)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                        child: NiyahIcon(NiyahIcons.arrow, size: 20, strokeWidth: 2, color: c.onPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l.addOwnWordsNote, style: NiyahText.sans(13, height: 1.5, color: c.text2)),
        ),
      ],
    );
  }
}

/// The "or" line between the two ways to add a reminder.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final line = Expanded(child: ColoredBox(color: c.border, child: const SizedBox(height: 1)));
    return ExcludeSemantics(
      child: Row(
        children: [
          line,
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context).addOr,
            style: NiyahText.sans(13, weight: FontWeight.w600, color: c.text3),
          ),
          const SizedBox(width: 12),
          line,
        ],
      ),
    );
  }
}

/// A group of ready-made moments: section label and a card of rows.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.items});

  final String title;
  final List<TemplateItem> items;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final anchors = s.settings.anchors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(title),
        const SizedBox(height: 10),
        NiyahCard(
          child: Column(
            children: [
              for (final (i, t) in items.indexed)
                Builder(
                  builder: (context) {
                    final added = s.reminders.byTemplate(t.id);
                    return ReminderRow(
                      key: ValueKey(t.id),
                      icon: t.icon,
                      title: t.title,
                      body: l.dQuoted(t.body),
                      when: scheduleText(l, added?.schedule ?? t.defaultSchedule, anchors),
                      showDivider: i > 0,
                      semanticLabel: added != null ? l.addChangeItem(t.title) : l.addSetUpItem(t.title),
                      onTap: () => showTemplateSheet(context, t.id),
                      trailing: _AddedBadge(added: added != null),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Round badge at the end of a row: check when added, plus otherwise.
class _AddedBadge extends StatelessWidget {
  const _AddedBadge({required this.added});

  final bool added;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: added ? c.primary : c.surface,
        border: added ? null : Border.all(color: c.secondary, width: 1.5),
      ),
      child: added
          ? NiyahIcon(NiyahIcons.check, size: 20, strokeWidth: 2.2, color: c.onPrimary)
          : NiyahIcon(NiyahIcons.plus, size: 20, strokeWidth: 2, color: c.primaryInk),
    );
  }
}
