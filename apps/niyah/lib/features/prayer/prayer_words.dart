import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';

/// Arabic names of the prayers, as drawn on the Prayer screen.
const prayerArabicNames = {
  Prayer.fajr: 'الفجر',
  Prayer.dhuhr: 'الظهر',
  Prayer.asr: 'العصر',
  Prayer.maghrib: 'المغرب',
  Prayer.isha: 'العشاء',
};

/// The next prayer of [among] after [now] today, or the first of them
/// (tomorrow) when they have all passed. An empty set means all five.
Prayer upcomingPrayer(PrayerRepository repo, Set<Prayer> among, DateTime now) {
  final candidates = [
    for (final p in Prayer.values)
      if (among.isEmpty || among.contains(p)) p,
  ];
  final times = repo.today?.times;
  final minutes = now.hour * 60 + now.minute;
  for (final p in candidates) {
    final t = times?[p];
    if (t != null && t.minutesOfDay > minutes) return p;
  }
  return candidates.first;
}

/// The default body of the prayer reminder for a signed [offsetMin].
String defaultPrayerBody(AppLocalizations l, int offsetMin, Prayer prayer) {
  final name = prayerName(l, prayer);
  if (offsetMin > 0) return l.prayerDefaultBodyBefore(name);
  if (offsetMin == 0) return l.prayerDefaultBodyAtAdhan(name);
  return l.prayerDefaultBodyAfter;
}

/// Top-right time of the notification preview: "before Fajr", "at Fajr",
/// "after Fajr".
String prayerMoment(AppLocalizations l, int offsetMin, Prayer prayer) {
  final name = prayerName(l, prayer);
  if (offsetMin > 0) return l.editorPreviewBeforePrayer(name);
  if (offsetMin == 0) return l.ePreviewAtPrayer(name);
  return l.ePreviewAfterPrayer(name);
}
