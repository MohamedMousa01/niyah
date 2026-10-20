# MyNiyah — Flutter app plan (Milestone 1: reminders flow, Milestone 2: Settings)

Status: approved scope, 19 Oct 2026. Source design: canvas **"MyNiyah App Design"**
(claude.ai/artifact/4RzizNDXAvQpExM7zskMt2). Architecture reference: [architettura.md](architettura.md).

## 1. Decisions

| Topic | Decision |
|---|---|
| Build | Hand-written Flutter app in `apps/niyah/`, using `packages/niyah_core` by path. FlutterFlow is retired for the mobile app; `flutterflow/` is removed once its runtime code is ported. |
| Scope | Only the designed screens: Home, My reminders, Add a reminder (+ setup sheet), Write your own, Edit reminder (+ delete sheet), Prayer reminders. Light + dark. |
| Not in scope | Onboarding, Quran/Hadith/Dhikr content, struggle reminders, "Sto per…", Firebase, account sync. (Settings arrived in milestone 2, §9.) |
| Languages | `it` + `en` via `gen-l10n` (device language, fallback `en`; overridable in Settings since milestone 2). Layout uses start/end everywhere so `ar`/`fr` can be added later. |
| Backend | None. SQLite seed + local notifications, fully offline. |
| Platforms | Android (built and tested on this Windows machine) and iOS (configured, but needs a Mac to build). |

### First-run values (`lib/data/defaults.dart`, all editable in Settings since milestone 2)
- Prayer location: **none** until the user picks a city or uses the phone's location; until then prayer times and prayer notifications wait, and Settings and the Prayer screen ask for a location. (Milestone 1 used Milan as a temporary default.) Method: the one usual in the location's country (`defaultMethodForCountry`), Shafi'i (standard) Asr. Device timezone is used for everything else.
- Quiet hours: off (22:30 → 07:00 when switched on). Wake-up time 06:40 (weekends 08:00), bedtime 22:30.
- Notification permission is requested **in context**: the first time the user adds or turns on a reminder (one system prompt, then only the "Open settings" row).

### Content-integrity rule kept from the repo
Templates with `requires_source = true` (Jumu'ah, al-Kahf, Monday/Thursday fast) stay **hidden** until they are linked to verified content, as `seed/README.md` requires. The "Weekly" filter therefore shows nothing yet and is hidden while empty.

## 2. Gaps between the design and the core (data-model changes)

| Design needs | Change |
|---|---|
| One reminder covering several prayers ("Before each prayer", Prayer screen toggles) | New column `prayers_mask INTEGER` (bit 0 = Fajr … bit 4 = Isha). `prayer` stays for old rows. |
| "After prayer" / "At adhan" / "10 min before" | `offset_min` becomes signed: > 0 = before, 0 = at adhan, < 0 = after. Valid range −60…120. The planner already subtracts the offset, so only `validate()` changes. |
| "After waking up" / "Before sleeping" with a separate weekend time | New `schedule_type = 'anchor'` + column `anchor TEXT ('wake'|'sleep')`. The anchor times live in settings, not on the reminder. |
| Morning/evening adhkar tied to Fajr/Asr + 20 min | These templates become `schedule_type = 'prayer'` with `prayers_mask` + offset −20. |
| Prayer reminder with custom words | The single `kind = prayer` reminder keeps its own `title`/`body` (null = default text). |

**How the planner stays unchanged:** a new pure function `expandReminders(reminders, anchors)` in `niyah_core` turns each multi-prayer reminder into one virtual reminder per prayer (`id:fajr`) and each anchor reminder into two weekly reminders (weekdays/weekend, `id:wd` / `id:we`). Stable ids keep the "no duplicates" property.

Schema goes to `user_version = 2`, with a migration for databases created at v1.

## 3. App architecture

```
apps/niyah/
  lib/
    main.dart                 open DB + settings → runApp → after first frame: init notifications, reschedule
    app.dart                  MaterialApp.router, themes (system light/dark), l10n
    router.dart               go_router: StatefulShellRoute with 3 tabs + pushed routes
    app_scope.dart            InheritedWidget that hands out the repositories and services
    core/theme/               NiyahColors (ThemeExtension, light+dark tokens from the design), text styles
    core/widgets/             shared widgets (§4)
    data/
      defaults.dart           temporary defaults (§1)
      models.dart             UI-facing models (ReminderItem, TemplateItem, PrayerDay…)
      repositories.dart       abstract ReminderRepository, TemplateRepository, PrayerRepository, SettingsStore
      fake/                   in-memory versions (used by widget tests and while the real ones are built)
      sqlite/                 sqflite implementations, seed copy + migrations
    notifications/            plugin wrapper + reschedule service (ported from flutterflow/custom_actions)
    features/
      home/  reminders/  add_reminder/  editor/  prayer/  settings/
    l10n/app_en.arb, app_it.arb
  assets/db/niyah_seed.db     built by seed/build_seed.py (scripts/build_seed_asset.sh)
  assets/fonts/               Amiri, Plus Jakarta Sans (OFL, bundled — no runtime download)
```

Principles:
- **No state-management package.** Repositories are `ChangeNotifier`s; screens listen with `ListenableBuilder`. Form state (editor, setup sheet) is local `StatefulWidget` state.
- **One write path:** every save, delete or toggle goes repository → `NotificationService.reschedule()`. `reschedule()` is serialized and idempotent (already true in the ported code).
- **Pure logic stays in `niyah_core`** and is tested with `dart test`; the app layer stays thin.
- Packages: `go_router`, `sqflite`, `path`, `shared_preferences`, `flutter_local_notifications`, `timezone`, `flutter_timezone`, `uuid`, `flutter_localizations`/`intl`. Versions already verified are listed in `flutterflow/README.md` §1.1.

### Routes
| Route | Screen (design artboard) |
|---|---|
| `/` tab 1 | Home (`Main`) |
| `/reminders` tab 2 | My reminders (`Reminders`) |
| `/settings` tab 3 | Settings (no artboard, §9) |
| `/settings/location` | Prayer location: GPS once or offline city search |
| `/reminders/add` | Add a reminder (`AddReminder`), setup sheet is a modal bottom sheet |
| `/reminders/new` | Write your own (`Editor`, mode new) |
| `/reminders/:id` | Edit reminder (`Editor`, mode edit, delete sheet) |
| `/reminders/prayer` | Prayer reminders (`Prayer`) |

Tapping a row in My reminders: personal → `/reminders/:id`; template → reopens the same setup sheet as Add (time/days/remove); prayer card → `/reminders/prayer`. "Change the words" on Prayer opens the Editor with the schedule section hidden.

## 4. Design system (from the canvas)
- Colors: the `.th` tokens (`bg`, `surface`, `text`, `text2`, `text3`, `textBody`, `border`, `divider`, `primary`, `primaryInk`, `onPrimary`, `tint`, `warmTint`, `warmInk`, `secondary`, `trackOff`, `seg`, `segOn`, `chipOff`, `inputBorder`, `previewBg`, `quoteBg`, `danger`, `dangerInk`, `ornament`) in light and dark, as a `ThemeExtension`.
- Type: Amiri 700 for screen titles and the Home hero; Plus Jakarta Sans for everything else (sizes as drawn: 34/28 titles, 16 body, 12.5 uppercase section labels).
- Shape: cards with 20 px radius and a 1 px border, 44 px minimum touch targets, 54 px primary buttons with 16 px radius.
- Widgets: `NiyahCard`, `SectionLabel`, `NiyahSwitch` (48×28 custom track), `SegmentedControl`, `ReminderRow`, `IconTile`, `TimeStepper` (hour ±1, minutes ±5), `DaysSelector`, `PrayerChips`, `OffsetStepper`, `PrimaryButton`, `DangerSheet`, `NotificationPreview`, `NiyahNavBar`, `GeometricOrnament` (the Home star, `CustomPainter`).
- Respect reduced motion; only short fades and the default route transitions.

## 5. Work breakdown and team

Phases run in order; work packages inside a phase run in parallel, each agent in its own git worktree/branch. The manager reviews and merges each branch into `main` and runs the full checks after every merge.

### Phase 1 — Foundation (manager)
`flutter create` in `apps/niyah` (org `app.niyah`), dependencies, folder layout, router with placeholder screens, `AppScope`, abstract repositories + fakes + `models.dart`, ARB files pre-filled with **every string from the design** in en + it, `analysis_options`, CI job (`flutter analyze`, `flutter test`).
**Done when:** the app runs on the Android emulator with 3 working tabs and every route reachable.

### Phase 2 — in parallel
| Agent | Owns (files) | Delivers |
|---|---|---|
| **A · Core & data** | `packages/niyah_core/`, `seed/`, `apps/niyah/lib/data/sqlite/`, `apps/niyah/assets/db/`, `scripts/` | §2 model changes + tests; schema v2 + migration + seed template updates + tests; SQLite repositories passing the same tests as the fakes; seed asset build script. Removes `flutterflow/` and its copy test (after B has ported the runtime). |
| **B · Notifications** | `apps/niyah/lib/notifications/`, `android/`, `ios/` | Port `niyah_runtime` + reschedule + prayer-cache refresh + tap handling; Android manifest/gradle and iOS AppDelegate changes (`flutterflow/README.md` §1.2); contextual permission flow; `reschedule()` on start, on resume after 6 h, after every write. |
| **C · Design system + Home + My reminders** | `lib/core/`, `assets/fonts/`, `lib/features/home/`, `lib/features/reminders/` | Theme tokens, fonts, all shared widgets from §4, Home (next-prayer line), My reminders (sections, toggles, "Show N more", empty state), widget tests in light + dark. |

### Phase 3 — in parallel (needs C's widgets merged)
| Agent | Owns | Delivers |
|---|---|---|
| **D · Add & setup sheet** | `lib/features/add_reminder/` | Filters, groups from templates, setup sheet for time / anchor (+ weekend) / prayer kinds, validation ("Pick at least one day"), add/save/remove. |
| **E · Editor & Prayer** | `lib/features/editor/`, `lib/features/prayer/` | Write your own / Edit (live preview, ideas, time or around-a-prayer, 140-character counter, delete sheet with "Turn it off instead"); Prayer screen (Before / At adhan / After, minutes stepper 5–45, per-prayer toggles with today's times, quiet-hours switch, change the words). |

### Phase 4 — Integration & QA (manager)
Swap fakes for SQLite in `main.dart`, run the end-to-end flow on the emulator, compare each screen with its artboard in light and dark, then the device checks below.

## 6. Done criteria for the milestone
- `dart test` (core), `python -m unittest` (seed), `flutter analyze` and `flutter test` (app) are green in CI.
- On Android, in airplane mode: add a template, write a personal reminder, edit, turn off, delete, change prayer timing. Everything survives an app restart, and the pending notifications match (no duplicates).
- A daily reminder and a prayer reminder fire on time, also after a phone reboot.
- Every screen matches its artboard in light and dark, in it and en, and at 200 % font scale nothing is clipped.

## 7. Prerequisites
- **Python 3.12** to build the seed DB and run its tests (not installed on this machine).
- Font files from the official `google/fonts` repository (OFL).
- An Android emulator or device for Phase 4. A Mac only when iOS builds are needed.
- Android SDK on Windows (Android Studio, 20 Oct 2026): also install **NDK 28.2.13676358** and **CMake 3.22.1** (needed by the `jni` plugin). Install them with `cmdline-tools/latest/bin/android.exe sdk install "ndk;28.2.13676358"` and `"cmake;3.22.1"`: since cmdline-tools 23.0, `sdkmanager.bat` is a batch wrapper that splits package names at `;`, so Gradle's automatic install of these fails.

## 8. Status — 19 Oct 2026
All five work packages are merged on `app/milestone-1`: 220 app tests, 68 core tests and 10 seed tests pass, and `flutter analyze` is clean. Every screen was checked against its artboard in the web preview (it/en, light/dark).

Still open (updated for milestone 2, §9):
- **Device checks (§6):** a release build now runs on the Android emulator (API 37): it starts, shows Home and Settings, and keeps a changed setting across a restart. Release builds crashed on start until 20 Oct 2026: `shared_preferences_android` 2.5.0 calls its Kotlin code through JNI and R8 renamed the classes it looks up by name; `android/app/proguard-rules.pro` keeps them and CI checks every release APK with `scripts/check_apk_jni_signatures.sh`. Nothing has run on iOS (no Mac). Still pending on Android: delivery, reboot restore, exact alarms, permission prompts, notification taps (the navigation itself is covered by widget tests), the GPS permission flow and fix (`geolocator`, coarse location only), the v2 → v3 migration on a real install (it copies ~34,000 cities with `ATTACH`).
- **Background reschedule** (WorkManager / BGAppRefresh): not ported; reschedule happens at launch, on every change, and on resume after 6 h. A pause that ends while the app is closed is fine (the planner already scheduled what follows it), but a long pause uses one-off notifications and needs the app opened within the 14-day window.
- **City names are not localized:** GeoNames gives one name per city ("Milan"); the search also matches other Latin-script names ("Milano"), but the label shows the GeoNames name. Country is shown as its ISO code ("IT · Europe/Rome").
- **iOS location prompt text** is English only (`NSLocationWhenInUseUsageDescription`, no `InfoPlist.strings` yet).
- **Native review** of the new it/fr/ar template texts and UI strings, now including Settings and the Italian names of the calculation methods.
- **GeoNames attribution (CC-BY 4.0)** must appear on an About page, which does not exist yet.

Closed by milestone 2: Settings tab, prayer location (no more Milan default), notification-tap navigation, `SectionLabel` with `trailing`.

## 9. Milestone 2 — Settings (19 Oct 2026, branch `app/milestone-2`)
No artboard exists for Settings: it is built from the design system (`NiyahCard` rows, `SectionLabel`, `NiyahSwitch`, `SegmentedControl`, `TimeStepper`, `NiyahBottomSheet`), light and dark, it/en, checked at 200 % text.

| Setting | Where it lives | Effect |
|---|---|---|
| Language (phone / English / Italiano) | `SettingsStore.languageCode` | `MaterialApp.locale`; notification texts and Android channel names follow it (`main.dart` re-inits the channels). |
| Prayer location | `SettingsStore.location` (`PrayerLocation`: name, country, lat/lng, IANA time zone, `fromGps`) | GPS once (`geolocator`, coarse, rounded to 0.01°, named after the biggest city within 15 km) or offline search in the seed's `cities` table (GeoNames cities15000, also by other Latin names: `alt_names`). |
| Calculation method | `SettingsStore.methodChoice` (null = suggested for the country) | Picking the suggested one stores null, so it follows a later change of location. Prayer times are computed by the `adhan` package in `niyah_core`. |
| Asr | `SettingsStore.madhab` (`shafi` / `hanafi`) | |
| Quiet hours | `SettingsStore.quietHours` (core `QuietHours`, mode `skip`) | Prayer reminders keep their own "during quiet hours" switch. |
| Pause all | `SettingsStore.pausedUntil` (1 day, 3 days, 1 week, or `SettingsStore.pausedForever`) | Planner `pausedUntil`. |
| My day | `SettingsStore.anchors` | Same editor as the wake/bed setup sheet (`AnchorFields`). |

Every setter notifies; `main.dart` reschedules on each change. `CorePrayerRepository` and `ScheduleSource` read location, method, madhab, quiet hours and pause from the settings (`ScheduleInputs` has no defaults any more).

Data changes: seed schema **v3** (`cities.alt_names`); the app migrates v2 → v3 by rebuilding `cities` and refilling every seed table from the bundled seed through `ATTACH` (no rows in memory). `scripts/build_seed_asset.sh cities15000.zip` now always builds the asset with cities (5 MB).

Notification taps: `NiyahApp` listens to `NotificationService.tappedPayload` (also a tap that launched the app), maps `{"r": id}` back with `baseReminderId()` and opens personal → Editor, template → its setup sheet over My reminders, prayer → Prayer screen. The refresh notice and deleted reminders open nothing.

Checks: `flutter analyze` clean; 280 app tests (220 before), 68 core tests and 10 seed tests pass. New widget tests cover Settings, the location screen and the sheets in it/en × light/dark × text scale 1.0/2.0, every setting, the no-location state, and notification-tap navigation. Checked by eye in the web preview (it, light/dark).
