import 'package:flutter/foundation.dart';

import '../defaults.dart';
import '../models.dart';
import '../repositories.dart';

/// In-memory implementations. Used by widget tests, by the web preview and
/// while the SQLite versions are being built. Sample data mirrors the design.

class FakeReminderRepository extends ReminderRepository {
  FakeReminderRepository({List<ReminderItem>? initial}) {
    for (final r in initial ?? sampleReminders) {
      _items[r.id] = r;
    }
  }

  final Map<String, ReminderItem> _items = {};
  int _seq = 0;

  static const prayerId = 'prayer';

  static const sampleReminders = [
    ReminderItem(
      id: 'p1',
      source: ReminderSource.personal,
      title: 'Why am I doing this?',
      body: 'Pause — make it for Allah, not for the eyes of people.',
      schedule: TimeSchedule(LocalTime(7, 15)),
    ),
    ReminderItem(
      id: 'p2',
      source: ReminderSource.personal,
      title: 'Before I open my phone',
      body: 'Begin with Bismillah and a clear intention.',
      schedule: AnchorSchedule(Anchor.wake),
    ),
    ReminderItem(
      id: 't1',
      source: ReminderSource.template,
      templateId: 'niyyah_renew_morning',
      title: 'Renew your intention',
      body: 'Begin your day seeking the pleasure of Allah.',
      schedule: TimeSchedule(LocalTime(8, 0)),
    ),
    ReminderItem(
      id: 't2',
      source: ReminderSource.template,
      templateId: 'niyyah_work',
      title: 'Remember Allah in your work',
      body: 'Do this work seeking the reward of Allah.',
      schedule: TimeSchedule(LocalTime(9, 0), daysMask: 31),
    ),
    ReminderItem(
      id: 't3',
      source: ReminderSource.template,
      templateId: 'dhikr_pause',
      title: 'A moment for dhikr',
      body: 'Pause for a moment and remember Allah.',
      schedule: TimeSchedule(LocalTime(13, 0)),
      enabled: false,
    ),
    ReminderItem(
      id: 't4',
      source: ReminderSource.template,
      templateId: 'niyyah_family',
      title: 'Intention with your family',
      body: 'Spend time with your family with a good intention.',
      schedule: TimeSchedule(LocalTime(19, 0)),
      enabled: false,
    ),
  ];

  @override
  Future<void> init() async {}

  @override
  List<ReminderItem> get all => List.unmodifiable(_items.values);

  @override
  ReminderItem? byId(String id) => _items[id];

  @override
  ReminderItem? byTemplate(String templateId) {
    for (final r in _items.values) {
      if (r.templateId == templateId) return r;
    }
    return null;
  }

  @override
  ReminderItem get prayer => _items.putIfAbsent(
        prayerId,
        () => const ReminderItem(id: prayerId, source: ReminderSource.prayer, schedule: Defaults.prayerReminder),
      );

  @override
  Future<void> save(ReminderItem reminder) async {
    _items[reminder.id] = reminder;
    notifyListeners();
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    final r = _items[id];
    if (r == null) return;
    _items[id] = r.copyWith(enabled: enabled);
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    if (_items.remove(id) != null) notifyListeners();
  }

  @override
  String newId() => 'fake-${++_seq}';
}

class FakeTemplateRepository implements TemplateRepository {
  static const _all = 127, _weekdays = 31;
  static const _five = {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha};

  // (id, group, icon, schedule, en title, en body, it title, it body)
  static const _rows = [
    ('before_prayer', TemplateGroup.prayer, 'mosque', PrayerSchedule(_five, offsetMin: 10),
        'Before each prayer', 'Prepare your heart for the prayer.',
        'Prima di ogni preghiera', 'Prepara il cuore alla preghiera.'),
    ('after_prayer', TemplateGroup.prayer, 'heart', PrayerSchedule(_five, offsetMin: -15),
        'After each prayer', 'Take a moment for the adhkar after prayer.',
        'Dopo ogni preghiera', 'Prenditi un momento per gli adhkar dopo la preghiera.'),
    ('wake_up', TemplateGroup.daily, 'sunrise', AnchorSchedule(Anchor.wake),
        'After waking up', 'Start your day with a clear intention.',
        'Dopo il risveglio', 'Inizia la giornata con un\'intenzione chiara.'),
    ('niyyah_renew_morning', TemplateGroup.daily, 'renew', TimeSchedule(LocalTime(8, 0), daysMask: _all),
        'Renew your intention', 'Begin your day seeking the pleasure of Allah.',
        'Rinnova la tua intenzione', 'Inizia la giornata cercando il compiacimento di Allah.'),
    ('niyyah_work', TemplateGroup.daily, 'work', TimeSchedule(LocalTime(9, 0), daysMask: _weekdays),
        'Remember Allah in your work', 'Do this work seeking the reward of Allah.',
        'Ricorda Allah nel tuo lavoro', 'Fai questo lavoro cercando la ricompensa di Allah.'),
    ('niyyah_study', TemplateGroup.daily, 'book', TimeSchedule(LocalTime(15, 0), daysMask: _weekdays),
        'Intention before studying', 'Study with the intention of seeking knowledge for the sake of Allah.',
        'Intenzione prima dello studio', 'Studia con l\'intenzione di cercare la conoscenza per Allah.'),
    ('kindness_today', TemplateGroup.daily, 'heart', TimeSchedule(LocalTime(17, 0), daysMask: _all),
        'A kind gesture', 'Is there someone you can do good to today?',
        'Un gesto gentile', 'C\'è qualcuno a cui oggi puoi fare del bene?'),
    ('niyyah_family', TemplateGroup.daily, 'family', TimeSchedule(LocalTime(19, 0), daysMask: _all),
        'Intention with your family', 'Spend time with your family with a good intention.',
        'Intenzione in famiglia', 'Vivi il tempo con la tua famiglia con una buona intenzione.'),
    ('before_sleep', TemplateGroup.daily, 'bed', AnchorSchedule(Anchor.sleep),
        'Before sleeping', 'End your day with a sincere heart.',
        'Prima di dormire', 'Chiudi la giornata con un cuore sincero.'),
    ('dhikr_pause', TemplateGroup.dhikr, 'heart', TimeSchedule(LocalTime(13, 0), daysMask: _all),
        'A moment for dhikr', 'Pause for a moment and remember Allah.',
        'Un momento per il dhikr', 'Fermati un istante e ricorda Allah.'),
    ('adhkar_morning', TemplateGroup.dhikr, 'sunrise', PrayerSchedule({Prayer.fajr}, offsetMin: -20),
        'Morning adhkar', 'It is time for the morning adhkar.',
        'Adhkar del mattino', 'È il momento degli adhkar del mattino.'),
    ('adhkar_evening', TemplateGroup.dhikr, 'moon', PrayerSchedule({Prayer.asr}, offsetMin: -20),
        'Evening adhkar', 'It is time for the evening adhkar.',
        'Adhkar della sera', 'È il momento degli adhkar della sera.'),
  ];

  @override
  Future<void> init() async {}

  @override
  List<TemplateItem> templates(String languageCode) => [
        for (final r in _rows)
          TemplateItem(
            id: r.$1,
            group: r.$2,
            icon: r.$3,
            defaultSchedule: r.$4,
            title: languageCode == 'it' ? r.$7 : r.$5,
            body: languageCode == 'it' ? r.$8 : r.$6,
          ),
      ];

  @override
  TemplateItem? byId(String id, String languageCode) {
    for (final t in templates(languageCode)) {
      if (t.id == id) return t;
    }
    return null;
  }
}

class FakePrayerRepository extends PrayerRepository {
  @override
  Future<void> init() async {}

  @override
  PrayerDay? get today {
    final now = DateTime.now();
    return PrayerDay(DateTime(now.year, now.month, now.day), const {
      Prayer.fajr: LocalTime(5, 58),
      Prayer.dhuhr: LocalTime(12, 58),
      Prayer.asr: LocalTime(15, 42),
      Prayer.maghrib: LocalTime(18, 20),
      Prayer.isha: LocalTime(19, 45),
    });
  }

  @override
  String get locationLabel => '${Defaults.prayerCity} · ${Defaults.prayerMethodLabel}';

  @override
  (Prayer, LocalTime)? nextPrayer(DateTime now) {
    final minutes = now.hour * 60 + now.minute;
    for (final e in today!.times.entries) {
      if (e.value.minutesOfDay > minutes) return (e.key, e.value);
    }
    return null;
  }
}

class FakeSettingsStore extends SettingsStore {
  AnchorTimes _anchors = Defaults.anchors;
  bool _prayerDuringQuiet = Defaults.prayerDuringQuiet;

  @override
  Future<void> init() async {}

  @override
  AnchorTimes get anchors => _anchors;

  @override
  Future<void> setAnchors(AnchorTimes value) async {
    _anchors = value;
    notifyListeners();
  }

  @override
  bool get prayerDuringQuiet => _prayerDuringQuiet;

  @override
  Future<void> setPrayerDuringQuiet(bool value) async {
    _prayerDuringQuiet = value;
    notifyListeners();
  }
}

class FakeNotificationService implements NotificationService {
  int rescheduleCount = 0;
  bool permission = true;

  @override
  Future<void> init() async {}

  @override
  Future<void> reschedule() async => rescheduleCount++;

  @override
  Future<bool> ensurePermission() async => permission;

  @override
  final ValueNotifier<String?> tappedPayload = ValueNotifier(null);
}
