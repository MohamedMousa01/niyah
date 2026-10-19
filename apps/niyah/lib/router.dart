import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/add_reminder/add_reminder_screen.dart';
import 'features/editor/editor_screen.dart';
import 'features/home/home_screen.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/reminders/reminders_screen.dart';
import 'features/settings/location_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';

/// Every path in the app. Screens navigate with `context.go/push(Routes.x)`.
abstract final class Routes {
  static const home = '/';
  static const reminders = '/reminders';
  static const settings = '/settings';
  static const location = '/settings/location';
  static const add = '/reminders/add';
  static const newReminder = '/reminders/new';
  static const prayer = '/reminders/prayer';
  static const prayerWords = '/reminders/prayer/words';
  static String edit(String id) => '/reminders/edit/$id';
}

/// The navigator above the tabs: pushed screens and sheets (e.g. a sheet
/// opened from a notification tap).
final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: Routes.home,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.reminders,
                builder: (_, _) => const RemindersScreen(),
                // Pushed screens cover the nav bar, as in the design.
                routes: [
                  GoRoute(
                    path: 'add',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const AddReminderScreen(),
                  ),
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const EditorScreen(),
                  ),
                  GoRoute(
                    path: 'edit/:id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => EditorScreen(reminderId: state.pathParameters['id']),
                  ),
                  GoRoute(
                    path: 'prayer',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const PrayerScreen(),
                    routes: [
                      GoRoute(
                        path: 'words',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, _) => const EditorScreen.prayerWords(),
                      ),
                    ],
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'location',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const LocationScreen(),
                  ),
                ],
              ),
            ]),
          ],
        ),
      ],
    );
