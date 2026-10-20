import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';
import 'settings_sheets.dart';
import 'settings_widgets.dart';

/// Settings tab: prayer times (location, method, Asr), notifications (quiet
/// hours, pause), "My day" (wake-up and bedtime), the theme and the app
/// language.
/// Every change is saved at once; `main.dart` reschedules on each one.
///
/// No artboard exists for it: built from the design system's cards, rows,
/// switches and sheets.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// Languages of the app, by their own name (not translated).
  static const languages = {'en': 'English', 'it': 'Italiano'};

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final settings = AppScope.of(context).settings;
    return ColoredBox(
      color: c.bg,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: EdgeInsetsDirectional.fromSTEB(16, NiyahInsets.top(context, 60), 16, 32),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ScreenTitle(title: l.settingsTitle, subtitle: l.settingsSubtitle),
            ),
            const SizedBox(height: 24),
            _PrayerSection(settings: settings),
            const SizedBox(height: 24),
            _NotificationsSection(settings: settings),
            const SizedBox(height: 24),
            _DaySection(settings: settings),
            const SizedBox(height: 24),
            _AppearanceSection(settings: settings),
            const SizedBox(height: 24),
            _LanguageSection(settings: settings),
          ],
        ),
      ),
    );
  }
}

class _PrayerSection extends StatelessWidget {
  const _PrayerSection({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final location = settings.location;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.settingsSectionPrayer),
        const SizedBox(height: 10),
        SettingsCard(
          children: [
            SettingsRow(
              icon: 'pin',
              title: l.settingsLocation,
              value: location == null ? l.settingsLocationNotSet : placeName(l, location),
              onTap: () => context.push(Routes.location),
            ),
            SettingsRow(
              icon: NiyahIcons.mosque,
              title: l.settingsMethod,
              value: methodName(l, settings.method),
              onTap: () => showMethodSheet(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.settingsAsr, style: NiyahText.sans(15, weight: FontWeight.w600, color: c.text)),
                  const SizedBox(height: 10),
                  SegmentedControl<String>(
                    values: const ['shafi', 'hanafi'],
                    selected: settings.madhab,
                    semanticLabel: l.settingsAsr,
                    labelOf: (m) => m == 'hanafi' ? l.settingsAsrHanafi : l.settingsAsrStandard,
                    onChanged: (m) {
                      if (m != settings.madhab) settings.setMadhab(m);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(l.settingsAsrNote, style: NiyahText.sans(13, height: 1.45, color: c.text2)),
                ],
              ),
            ),
          ],
        ),
        if (location == null) SettingsNote(l.prayerNoLocation),
      ],
    );
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection({required this.settings});

  final SettingsStore settings;

  Future<void> _pickTime(BuildContext context, {required bool start}) async {
    final l = AppLocalizations.of(context);
    final q = settings.quietHours;
    final picked = await showTimeSheet(
      context,
      title: start ? l.settingsQuietStart : l.settingsQuietEnd,
      initial: start ? q.start : q.end,
    );
    if (picked == null) return;
    await settings.setQuietHours(
      QuietHours(enabled: q.enabled, start: start ? picked : q.start, end: start ? q.end : picked, mode: q.mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = settings.quietHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.settingsSectionNotifications),
        const SizedBox(height: 10),
        SettingsCard(
          children: [
            SettingsSwitchRow(
              icon: NiyahIcons.moon,
              title: l.settingsQuietHours,
              note: q.enabled ? l.settingsQuietOnNote(formatTime(q.start), formatTime(q.end)) : l.settingsQuietOffNote,
              value: q.enabled,
              onChanged: (v) => settings.setQuietHours(QuietHours(enabled: v, start: q.start, end: q.end, mode: q.mode)),
            ),
            if (q.enabled) ...[
              SettingsRow(
                title: l.settingsQuietFrom,
                value: formatTime(q.start),
                onTap: () => _pickTime(context, start: true),
              ),
              SettingsRow(
                title: l.settingsQuietTo,
                value: formatTime(q.end),
                onTap: () => _pickTime(context, start: false),
              ),
            ],
            SettingsRow(
              icon: 'pause',
              title: l.settingsPause,
              value: pauseLabel(l, settings),
              onTap: () => showPauseSheet(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.settingsSectionDay),
        const SizedBox(height: 10),
        SettingsCard(
          children: [
            for (final a in Anchor.values)
              SettingsRow(
                icon: a == Anchor.wake ? NiyahIcons.sunrise : NiyahIcons.bed,
                title: a == Anchor.wake ? l.anchorWakeLabel : l.anchorSleepLabel,
                value: anchorTimesLabel(l, settings.anchors, a),
                onTap: () => showAnchorSheet(context, a),
              ),
          ],
        ),
        SettingsNote(l.settingsDayNote),
      ],
    );
  }
}

/// Light (default) or dark, independent of the phone's setting.
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.settingsSectionAppearance),
        const SizedBox(height: 10),
        NiyahCard(
          padding: const EdgeInsets.all(12),
          child: SegmentedControl<AppTheme>(
            values: AppTheme.values,
            selected: settings.theme,
            semanticLabel: l.settingsTheme,
            labelOf: (t) => t == AppTheme.dark ? l.settingsThemeDark : l.settingsThemeLight,
            onChanged: (t) {
              if (t != settings.theme) settings.setTheme(t);
            },
          ),
        ),
      ],
    );
  }
}

class _LanguageSection extends StatelessWidget {
  const _LanguageSection({required this.settings});

  final SettingsStore settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The phone's first language, as MaterialApp resolves it.
    final locales = WidgetsBinding.instance.platformDispatcher.locales;
    final phone = locales.isEmpty ? 'en' : locales.first.languageCode;
    final phoneLanguage = SettingsScreen.languages[phone] ?? SettingsScreen.languages['en']!;
    final current = settings.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l.settingsSectionLanguage),
        const SizedBox(height: 10),
        Semantics(
          container: true,
          label: l.settingsSectionLanguage,
          child: SettingsCard(
            children: [
              ChoiceRow(
                title: l.settingsLanguagePhoneValue(phoneLanguage),
                selected: current == null,
                onTap: () => settings.setLanguageCode(null),
              ),
              for (final MapEntry(key: code, value: name) in SettingsScreen.languages.entries)
                ChoiceRow(
                  title: name,
                  selected: current == code,
                  onTap: () => settings.setLanguageCode(code),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
