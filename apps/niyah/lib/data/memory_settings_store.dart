import 'defaults.dart';
import 'models.dart';
import 'repositories.dart';

/// [SettingsStore] held in memory, starting from [Defaults]. Base of the
/// persisted store (which saves, then calls `super`) and of the fake one.
class MemorySettingsStore extends SettingsStore {
  MemorySettingsStore({PrayerLocation? location}) {
    _location = location;
  }

  AnchorTimes _anchors = Defaults.anchors;
  bool _prayerDuringQuiet = Defaults.prayerDuringQuiet;
  String? _languageCode;
  PrayerLocation? _location;
  String? _methodChoice;
  String _madhab = Defaults.madhab;
  QuietHours _quietHours = Defaults.quietHours;
  DateTime? _pausedUntil;

  @override
  Future<void> init() async {}

  /// Sets stored values without notifying (a null leaves a value as is).
  void load({
    AnchorTimes? anchors,
    bool? prayerDuringQuiet,
    String? languageCode,
    PrayerLocation? location,
    String? methodChoice,
    String? madhab,
    QuietHours? quietHours,
    DateTime? pausedUntil,
  }) {
    _anchors = anchors ?? _anchors;
    _prayerDuringQuiet = prayerDuringQuiet ?? _prayerDuringQuiet;
    _languageCode = languageCode ?? _languageCode;
    _location = location ?? _location;
    _methodChoice = methodChoice ?? _methodChoice;
    _madhab = madhab ?? _madhab;
    _quietHours = quietHours ?? _quietHours;
    _pausedUntil = pausedUntil?.toUtc() ?? _pausedUntil;
  }

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

  @override
  String? get languageCode => _languageCode;
  @override
  Future<void> setLanguageCode(String? value) async {
    _languageCode = value;
    notifyListeners();
  }

  @override
  PrayerLocation? get location => _location;
  @override
  Future<void> setLocation(PrayerLocation? value) async {
    _location = value;
    notifyListeners();
  }

  @override
  String? get methodChoice => _methodChoice;
  @override
  Future<void> setMethodChoice(String? value) async {
    _methodChoice = value;
    notifyListeners();
  }

  @override
  String get madhab => _madhab;
  @override
  Future<void> setMadhab(String value) async {
    _madhab = value;
    notifyListeners();
  }

  @override
  QuietHours get quietHours => _quietHours;
  @override
  Future<void> setQuietHours(QuietHours value) async {
    _quietHours = value;
    notifyListeners();
  }

  @override
  DateTime? get pausedUntil => _pausedUntil;
  @override
  Future<void> setPausedUntil(DateTime? value) async {
    _pausedUntil = value?.toUtc();
    notifyListeners();
  }
}
