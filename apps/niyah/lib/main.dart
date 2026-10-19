import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Phase 4 swaps in the SQLite repositories and real notifications on mobile;
  // the web preview keeps the in-memory ones.
  final services = AppServices.fake();
  await services.init();
  runApp(NiyahApp(services: services));
  WidgetsBinding.instance.addPostFrameCallback((_) => _startBackground(services));
}

/// Work that must never delay the first frame (architettura §11).
void _startBackground(AppServices s) {
  void reschedule() => unawaited(s.notifications.reschedule());
  unawaited(s.notifications.init().then((_) => reschedule()));
  // Every change to reminders or settings rebuilds the OS schedule.
  s.reminders.addListener(reschedule);
  s.settings.addListener(reschedule);
}
