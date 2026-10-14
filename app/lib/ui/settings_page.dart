import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:niyah_core/niyah_core.dart' as core;

import '../l10n/app_localizations.dart';
import '../state/app_scope.dart';
import '../state/app_settings.dart';
import '../theme/niyah_theme.dart';
import 'onboarding_page.dart';
import 'widgets.dart';

/// Deve coincidere con `version` in pubspec.yaml (un test lo controlla).
const kAppVersion = '0.1.0';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    final s = c.settings;
    final q = s.quietHours;
    final paused = s.pausedUntil;
    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: NiyahPage(
        children: [
          const SizedBox(height: NiyahSpace.s),
          RowGroup(children: [
            SettingRow(
              icon: Icons.language,
              title: l.settingsLanguage,
              value: kLanguageNames[s.language],
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LanguagePage())),
            ),
          ]),
          SectionHeader(l.navNotifications),
          RowGroup(children: [
            SettingRow(
              icon: Icons.notifications_outlined,
              title: l.settingsPermission,
              value: switch (c.notificationsEnabled) {
                true => l.permissionGranted,
                false => l.permissionDenied,
                null => null,
              },
              onTap: () async {
                final controller = AppScope.read(context);
                if (controller.notificationsEnabled == false) {
                  // Dopo un rifiuto Android non mostra più la richiesta.
                  final granted = await controller.requestPermission();
                  if (!granted) await controller.gateway.openSettings();
                } else {
                  await controller.gateway.openSettings();
                }
              },
            ),
            SettingRow(
              icon: Icons.bedtime_outlined,
              title: l.settingsQuietHours,
              value: q.enabled ? l.quietHoursRange(formatTime(context, q.start), formatTime(context, q.end)) : l.quietHoursOff,
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const QuietHoursSheet(),
              ),
            ),
            SettingRow(
              icon: Icons.pause_circle_outline,
              title: l.settingsPause,
              value: paused == null ? l.pauseNone : l.pausedUntil(formatInstant(context, paused)),
              onTap: () => showModalBottomSheet<void>(context: context, builder: (_) => const PauseSheet()),
            ),
          ]),
          SectionHeader(l.settingsAbout),
          RowGroup(children: [
            SettingRow(
              icon: Icons.info_outline,
              title: l.settingsAbout,
              value: l.aboutVersion(kAppVersion),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutPage())),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Data e ora locali di un istante, nella lingua dell'app.
String formatInstant(BuildContext context, DateTime utc) {
  final local = utc.toLocal();
  final now = DateTime.now();
  final time = formatTime(context, core.LocalTime(local.hour, local.minute));
  final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
  if (sameDay) return time;
  final date = DateFormat.MMMEd(Localizations.localeOf(context).toLanguageTag()).format(local);
  return '$date, $time';
}

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsLanguage)),
      body: NiyahPage(children: [
        const SizedBox(height: NiyahSpace.s),
        LanguageList(selected: c.settings.language, onSelected: c.setLanguage),
      ]),
    );
  }
}

class QuietHoursSheet extends StatefulWidget {
  const QuietHoursSheet({super.key});

  @override
  State<QuietHoursSheet> createState() => _QuietHoursSheetState();
}

class _QuietHoursSheetState extends State<QuietHoursSheet> {
  late core.QuietHours _q = AppScope.read(context).settings.quietHours;

  Future<core.LocalTime?> _pick(core.LocalTime t) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: t.hour, minute: t.minute));
    return picked == null ? null : core.LocalTime(picked.hour, picked.minute);
  }

  void _set({bool? enabled, core.LocalTime? start, core.LocalTime? end, core.QuietMode? mode}) {
    setState(() {
      _q = core.QuietHours(
        enabled: enabled ?? _q.enabled,
        start: start ?? _q.start,
        end: end ?? _q.end,
        mode: mode ?? _q.mode,
      );
    });
    AppScope.read(context).setQuietHours(_q);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(NiyahSpace.l, 0, NiyahSpace.l, NiyahSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsQuietHours, style: theme.textTheme.titleLarge),
              value: _q.enabled,
              onChanged: (v) => _set(enabled: v),
            ),
            if (_q.enabled) ...[
              const SizedBox(height: NiyahSpace.s),
              RowGroup(children: [
                SettingRow(
                  title: l.quietHoursFrom,
                  value: formatTime(context, _q.start),
                  onTap: () async {
                    final t = await _pick(_q.start);
                    if (t != null) _set(start: t);
                  },
                ),
                SettingRow(
                  title: l.quietHoursTo,
                  value: formatTime(context, _q.end),
                  onTap: () async {
                    final t = await _pick(_q.end);
                    if (t != null) _set(end: t);
                  },
                ),
              ]),
              const SizedBox(height: NiyahSpace.m),
              RadioGroup<core.QuietMode>(
                groupValue: _q.mode,
                onChanged: (m) {
                  if (m != null) _set(mode: m);
                },
                child: RowGroup(children: [
                  RadioListTile<core.QuietMode>(value: core.QuietMode.skip, title: Text(l.quietModeSkip)),
                  RadioListTile<core.QuietMode>(value: core.QuietMode.shift, title: Text(l.quietModeShift)),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PauseSheet extends StatelessWidget {
  const PauseSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    final now = DateTime.now();
    final nav = Navigator.of(context);

    Future<void> pause(DateTime? until) async {
      nav.pop();
      await c.pauseUntil(until);
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.timer_outlined), title: Text(l.pause1h), onTap: () => pause(now.add(const Duration(hours: 1)))),
          ListTile(
            leading: const Icon(Icons.nightlight_outlined),
            title: Text(l.pauseToday),
            onTap: () => pause(DateTime(now.year, now.month, now.day, 23, 59)),
          ),
          ListTile(
            leading: const Icon(Icons.wb_twilight),
            title: Text(l.pauseTomorrow),
            onTap: () => pause(DateTime(now.year, now.month, now.day + 1, 7, 0)),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: Text(l.pauseCustom),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 60)),
              );
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 7, minute: 0));
              if (time == null) return;
              final until = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              if (until.isAfter(DateTime.now())) await pause(until);
            },
          ),
          if (c.settings.pausedUntil != null)
            ListTile(leading: const Icon(Icons.play_circle_outline), title: Text(l.resume), onTap: () => pause(null)),
          const SizedBox(height: NiyahSpace.s),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAbout)),
      body: NiyahPage(children: [
        const NiyahHeader(),
        Text(l.aboutBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: NiyahSpace.m),
        Text(l.aboutVersion(kAppVersion), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: NiyahSpace.l),
        OutlinedButton(
          onPressed: () => showLicensePage(context: context, applicationName: l.appTitle, applicationVersion: kAppVersion),
          child: Text(l.aboutLicenses),
        ),
      ]),
    );
  }
}
