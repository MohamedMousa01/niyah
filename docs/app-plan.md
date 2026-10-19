# MyNiyah — Flutter app plan (Milestone 1: reminders flow)

Status: approved scope, 19 Oct 2026. Source design: canvas **"MyNiyah App Design"**
(claude.ai/artifact/4RzizNDXAvQpExM7zskMt2). Architecture reference: [architettura.md](architettura.md).

## 1. Decisions

| Topic | Decision |
|---|---|
| Build | Hand-written Flutter app in `apps/niyah/`, using `packages/niyah_core` by path. FlutterFlow is retired for the mobile app; `flutterflow/` is removed once its runtime code is ported. |
| Scope | Only the designed screens: Home, My reminders, Add a reminder (+ setup sheet), Write your own, Edit reminder (+ delete sheet), Prayer reminders. Light + dark. |
| Not in scope | Settings content, onboarding, Quran/Hadith/Dhikr content, struggle reminders, "Sto per…", Firebase, account sync. The Settings tab shows a simple placeholder. |
| Languages | `it` + `en` via `gen-l10n` (device language, fallback `en`). Layout uses start/end everywhere so `ar`/`fr` can be added later. |
| Backend | None. SQLite seed + local notifications, fully offline. |
| Platforms | Android (built and tested on this Windows machine) and iOS (configured, but needs a Mac to build). |

### Defaults while Settings doesn't exist (temporary, kept in one file `lib/data/defaults.dart`)
- Prayer location: Milan (45.4642, 9.1900), `Europe/Rome`, Muslim World League, Shafi'i Asr. Device timezone is used for everything else.
- Quiet hours: off. Wake-up time 06:40 (weekends 08:00), bedtime 22:30.
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
      home/  reminders/  add_reminder/  editor/  prayer/  settings/ (placeholder)
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
| `/settings` tab 3 | placeholder |
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
