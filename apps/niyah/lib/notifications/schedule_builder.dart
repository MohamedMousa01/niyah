import 'dart:ui' show Locale;

import 'package:niyah_core/niyah_core.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import 'schedule_inputs.dart';

/// Pure parts of the reschedule: texts, reminder preparation and the plan.
/// No plugin calls here, so everything is unit-testable.

/// Days of prayer times computed for each plan (the planner looks 14 days
/// ahead, plus margin for the last day and timezone edges).
const prayerDaysAhead = 16;

/// App or device locale → a supported app locale (fallback English).
AppLocalizations notificationLocalizations(Locale device) {
  final supported = AppLocalizations.supportedLocales.any((l) => l.languageCode == device.languageCode);
  return lookupAppLocalizations(Locale(supported ? device.languageCode : 'en'));
}

String prayerName(AppLocalizations l, Prayer p) => switch (p) {
      Prayer.fajr => l.prayerFajr,
      Prayer.dhuhr => l.prayerDhuhr,
      Prayer.asr => l.prayerAsr,
      Prayer.maghrib => l.prayerMaghrib,
      Prayer.isha => l.prayerIsha,
    };

/// Localized names of the 8 Android channels (channel id → name).
Map<String, String> channelNames(AppLocalizations l) => {
      NiyahChannels.prayer: l.channelPrayer,
      NiyahChannels.niyyah: l.channelNiyyah,
      NiyahChannels.quran: l.channelQuran,
      NiyahChannels.hadith: l.channelHadith,
      NiyahChannels.dhikr: l.channelDhikr,
      NiyahChannels.goodDeeds: l.channelGoodDeeds,
      NiyahChannels.islamicEvents: l.channelIslamicEvents,
      NiyahChannels.personal: l.channelPersonal,
    };

/// Texts the planner uses when a reminder has none of its own.
NotificationStrings notificationStrings(AppLocalizations l) {
  // The planner fills `{minutes}` itself; a sentinel number turns the
  // generated message back into a template.
  const sentinel = 987654321;
  return NotificationStrings(
    prayerNames: {for (final p in Prayer.values) p: prayerName(l, p)},
    prayerAtTime: l.notifPrayerAtTime('{prayer}'),
    prayerBefore: l.notifPrayerBefore('{prayer}', sentinel).replaceAll('$sentinel', '{minutes}'),
    prayerAfter: l.notifPrayerAfter('{prayer}', sentinel).replaceAll('$sentinel', '{minutes}'),
    quranTitle: l.channelQuran,
    hadithTitle: l.channelHadith,
    dhikrTitle: l.channelDhikr,
    // Content reminders are not in milestone 1 and there is no string yet.
    tapToRead: '',
    refreshTitle: l.appName,
    refreshBody: l.notifRefreshBody,
    privateTitle: l.appName,
    privateBody: l.notifPrivateBody,
  );
}

/// Default body of a prayer reminder: > 0 = before adhan, 0 = at adhan,
/// < 0 = after the prayer.
String prayerBody(AppLocalizations l, Prayer prayer, int offsetMin) {
  final name = prayerName(l, prayer);
  if (offsetMin > 0) return l.notifPrayerBefore(name, offsetMin);
  if (offsetMin == 0) return l.notifPrayerAtTime(name);
  return l.prayerDefaultBodyAfter;
}

/// Applies the app rules the core planner doesn't know about:
/// - the prayer reminder without custom words gets its default body
///   (the planner would write "in -20 minutes" for after-prayer);
/// - prayer reminders follow the "during quiet hours" switch.
List<Reminder> prepareReminders(List<Reminder> reminders, AppLocalizations l, {required bool prayerDuringQuiet}) => [
      for (final r in reminders)
        if (r.kind == ReminderKind.prayer && r.prayer != null)
          r.copyWith(
            body: (r.body ?? '').trim().isEmpty ? prayerBody(l, r.prayer!, r.offsetMin) : r.body,
            respectsQuietHours: !prayerDuringQuiet,
          )
        else
          r,
    ];

/// Builds the desired OS schedule from the inputs (no side effects).
Future<SchedulePlan> buildSchedulePlan({
  required ScheduleInputs inputs,
  required AppLocalizations l10n,
  required tz.Location location,
  required tz.TZDateTime now,
  required int budget,
  List<ExistingNotification> existing = const [],
}) async {
  final reminders = prepareReminders(
    await inputs.plannerReminders(),
    l10n,
    prayerDuringQuiet: inputs.prayerDuringQuiet,
  );
  final templates = await inputs.templateTexts(l10n.localeName);

  final prayerDays = <LocalDate, DayPrayerTimes>{};
  final prayerSettings = inputs.prayerSettings;
  // Without a location there are no times: prayer reminders stay silent.
  if (prayerSettings != null && reminders.any((r) => r.enabled && r.scheduleType == ScheduleType.prayer)) {
    // Computed in memory for the window. The instants depend only on the
    // coordinates; the device timezone keeps days and quiet hours local.
    final today = LocalDate.of(tz.TZDateTime.from(now, location));
    for (final d in computePrayerDays(today, prayerDaysAhead, prayerSettings, location)) {
      prayerDays[d.date] = d;
    }
  }

  final planner = NotificationPlanner(
    location: location,
    settings: PlannerSettings(
      budget: budget,
      quietHours: inputs.quietHours,
      pausedUntil: inputs.pausedUntil,
    ),
    strings: notificationStrings(l10n),
    templateTexts: templates,
    prayerTimes: (d) => prayerDays[d],
  );
  return planner.plan(reminders, now, existing: existing);
}
