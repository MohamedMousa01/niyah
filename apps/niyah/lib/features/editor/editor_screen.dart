import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../prayer/prayer_words.dart';
import 'editor_widgets.dart';

/// "Write your own" / "Edit reminder" (artboard `Editor`).
///
/// - `EditorScreen()` writes a new personal reminder.
/// - `EditorScreen(reminderId: id)` edits one (with delete).
/// - `EditorScreen.prayerWords()` edits only the words of the prayer reminder;
///   empty fields mean the default words.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, this.reminderId}) : prayerWordsOnly = false;
  const EditorScreen.prayerWords({super.key}) : reminderId = null, prayerWordsOnly = true;

  final String? reminderId;
  final bool prayerWordsOnly;

  static const titleMax = 60;
  static const bodyMax = 140;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

enum _Trigger { time, prayer }

enum _DeleteChoice { delete, turnOff }

class _EditorScreenState extends State<EditorScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();

  bool _loaded = false;
  ReminderItem? _existing;

  _Trigger _trigger = _Trigger.time;
  LocalTime _time = const LocalTime(8, 0);
  int _days = DaysMask.all;
  bool _timeOpen = false;
  Set<Prayer> _prayers = const {Prayer.fajr};
  int _offset = 10;

  /// An edited wake-up/bedtime reminder keeps its anchor until the user
  /// changes the schedule.
  AnchorSchedule? _anchor;
  bool _saving = false;

  bool get _isEdit => widget.reminderId != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _body.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final s = AppScope.of(context);
    final r = widget.prayerWordsOnly
        ? s.reminders.prayer
        : widget.reminderId == null
        ? null
        : s.reminders.byId(widget.reminderId!);
    _existing = r;
    if (r == null) return;
    _title.text = r.title ?? '';
    _body.text = r.body ?? '';
    switch (r.schedule) {
      case TimeSchedule(:final time, :final daysMask):
        _time = time;
        _days = daysMask;
      case AnchorSchedule(:final anchor):
        _anchor = AnchorSchedule(anchor);
        _time = s.settings.anchors.weekday(anchor);
      case PrayerSchedule(:final prayers, :final offsetMin):
        _trigger = _Trigger.prayer;
        _prayers = prayers;
        _offset = offsetMin;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Updates the schedule and drops a kept anchor.
  void _edit(VoidCallback change) => setState(() {
    change();
    _anchor = null;
  });

  Schedule get _schedule => _trigger == _Trigger.prayer
      ? PrayerSchedule(_prayers, offsetMin: _offset)
      : _anchor ?? TimeSchedule(_time, daysMask: _days);

  static String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  String? _invalidReason(AppLocalizations l) {
    if (widget.prayerWordsOnly) return null;
    if (_clean(_title) == null && _clean(_body) == null) return l.editorTextRequired;
    if (_trigger == _Trigger.prayer && _prayers.isEmpty) return l.pickOnePrayer;
    if (_trigger == _Trigger.time && _anchor == null && _days & DaysMask.all == 0) return l.pickOneDay;
    return null;
  }

  Future<void> _save() async {
    final s = AppScope.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final existing = _existing;
    if (widget.prayerWordsOnly) {
      final p = s.reminders.prayer;
      await s.reminders.save(
        ReminderItem(
          id: p.id,
          source: p.source,
          templateId: p.templateId,
          title: _clean(_title),
          body: _clean(_body),
          schedule: p.schedule,
          enabled: p.enabled,
        ),
      );
    } else {
      if (existing == null) await s.notifications.ensurePermission();
      await s.reminders.save(
        ReminderItem(
          id: existing?.id ?? s.reminders.newId(),
          source: existing?.source ?? ReminderSource.personal,
          templateId: existing?.templateId,
          title: _clean(_title),
          body: _clean(_body),
          schedule: _schedule,
          enabled: existing?.enabled ?? true,
        ),
      );
    }
    if (mounted) await nav.maybePop();
  }

  Future<void> _askDelete(String name) async {
    final s = AppScope.of(context);
    final nav = Navigator.of(context);
    final id = _existing!.id;
    final choice = await showNiyahSheet<_DeleteChoice>(context, builder: (_) => _DeleteSheet(name: name));
    if (choice == null || !mounted) return;
    switch (choice) {
      case _DeleteChoice.delete:
        await s.reminders.delete(id);
      case _DeleteChoice.turnOff:
        await s.reminders.setEnabled(id, false);
    }
    if (mounted) await nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final s = AppScope.of(context);

    final heading = widget.prayerWordsOnly
        ? l.prayerTitle
        : _isEdit
        ? l.editorEditTitle
        : l.editorNewTitle;

    if (_isEdit && _existing == null) {
      return Scaffold(body: BackHeader(title: heading));
    }

    // Prayer words: empty fields fall back to the default words.
    final prayerSchedule = widget.prayerWordsOnly ? _existing!.schedule : null;
    final wordsOffset = prayerSchedule is PrayerSchedule ? prayerSchedule.offsetMin : 0;
    final wordsPrayer = prayerSchedule is PrayerSchedule
        ? upcomingPrayer(s.prayers, prayerSchedule.prayers, DateTime.now())
        : Prayer.fajr;
    final titleFallback = widget.prayerWordsOnly ? l.prayerDefaultTitle : l.editorPreviewTitleFallback;
    final bodyFallback = widget.prayerWordsOnly
        ? defaultPrayerBody(l, wordsOffset, wordsPrayer)
        : l.editorPreviewBodyFallback;

    final title = _clean(_title);
    final body = _clean(_body);
    final reason = _invalidReason(l);

    return Scaffold(
      body: Column(
        children: [
          BackHeader(title: heading),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NotificationPreview(
                    title: title ?? titleFallback,
                    body: body ?? bodyFallback,
                    time: widget.prayerWordsOnly ? prayerMoment(l, wordsOffset, wordsPrayer) : _previewTime(l),
                  ),
                  const SizedBox(height: 22),
                  EditorField(
                    label: l.editorTitleLabel,
                    controller: _title,
                    hint: widget.prayerWordsOnly ? l.prayerDefaultTitle : l.editorTitleHint,
                    maxLength: EditorScreen.titleMax,
                  ),
                  const SizedBox(height: 14),
                  EditorField(
                    label: l.editorMessageLabel,
                    controller: _body,
                    hint: widget.prayerWordsOnly ? bodyFallback : l.editorMessageHint,
                    maxLength: EditorScreen.bodyMax,
                    multiline: true,
                    trailing: l.editorCharsLeft(EditorScreen.bodyMax - _body.text.characters.length),
                  ),
                  const SizedBox(height: 14),
                  _Ideas(onPick: _useIdea),
                  if (!widget.prayerWordsOnly) ...[const SizedBox(height: 22), ..._schedulePart(l)],
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(l.editorPrivacyNote, style: NiyahText.sans(13, height: 1.5, color: c.text2)),
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.bg,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, math.max(26, MediaQuery.paddingOf(context).bottom + 12)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: reason ?? (_isEdit || widget.prayerWordsOnly ? l.saveChanges : l.editorSave),
                    onPressed: reason == null && !_saving ? _save : null,
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 4),
                    NiyahTextButton(
                      label: l.editorDelete,
                      icon: NiyahIcons.trash,
                      danger: true,
                      onPressed: () => _askDelete(title ?? body ?? l.editorPreviewTitleFallback),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _previewTime(AppLocalizations l) {
    if (_trigger == _Trigger.time) return formatTime(_time);
    for (final p in Prayer.values) {
      if (_prayers.contains(p)) return prayerMoment(l, _offset, p);
    }
    return offsetLabel(l, _offset);
  }

  void _useIdea((String, String) idea) {
    _title.value = TextEditingValue(
      text: idea.$1,
      selection: TextSelection.collapsed(offset: idea.$1.length),
    );
    _body.value = TextEditingValue(
      text: idea.$2,
      selection: TextSelection.collapsed(offset: idea.$2.length),
    );
  }

  List<Widget> _schedulePart(AppLocalizations l) {
    final c = context.niyah;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          header: true,
          child: Text(
            l.editorWhenTitle,
            style: NiyahText.sans(14, weight: FontWeight.w600, color: c.text),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SegmentedControl<_Trigger>(
        values: _Trigger.values,
        selected: _trigger,
        semanticLabel: l.editorTriggerLabel,
        labelOf: (t) => t == _Trigger.time ? l.editorAtATime : l.editorAroundPrayer,
        onChanged: (t) {
          if (t != _trigger) _edit(() => _trigger = t);
        },
      ),
      const SizedBox(height: 12),
      if (_trigger == _Trigger.time)
        TimeCard(
          time: _time,
          open: _timeOpen,
          daysMask: _days,
          onToggle: () => setState(() => _timeOpen = !_timeOpen),
          onTime: (t) => _edit(() => _time = t),
          onDays: (m) => _edit(() => _days = m),
        )
      else
        PrayerCard(
          prayers: _prayers,
          offsetMin: _offset,
          label: offsetLabel(l, _offset),
          onPrayers: (p) => _edit(() => _prayers = p),
          onOffset: (o) => _edit(() => _offset = o),
        ),
    ];
  }
}

/// The three "Need words?" suggestions.
class _Ideas extends StatelessWidget {
  const _Ideas({required this.onPick});

  final ValueChanged<(String, String)> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final ideas = [(l.idea1Title, l.idea1Body), (l.idea2Title, l.idea2Body), (l.idea3Title, l.idea3Body)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(l.editorIdeasLabel, style: NiyahText.sans(13, color: c.text2)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final idea in ideas) IdeaChip(label: idea.$1, onTap: () => onPick(idea))],
        ),
      ],
    );
  }
}

/// "Delete this reminder?" sheet. Pops with the user's choice (null = cancel).
class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    return NiyahBottomSheet(
      gap: 12,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      semanticLabel: l.deleteTitle,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Semantics(
            header: true,
            child: Text(
              l.deleteTitle,
              style: NiyahText.sans(20, weight: FontWeight.w700, color: c.text),
            ),
          ),
        ),
        Text(l.deleteBody(name), style: NiyahText.sans(15, height: 1.5, color: c.text2)),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: PrimaryButton.danger(
            label: l.deleteConfirm,
            height: 52,
            onPressed: () => nav.pop(_DeleteChoice.delete),
          ),
        ),
        PrimaryButton.outline(label: l.deleteTurnOff, height: 52, onPressed: () => nav.pop(_DeleteChoice.turnOff)),
        NiyahTextButton(label: l.cancel, onPressed: () => nav.pop()),
      ],
    );
  }
}
