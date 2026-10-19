import 'dart:convert';

import 'package:niyah_core/niyah_core.dart' show baseReminderId;

import '../data/models.dart';
import '../data/repositories.dart';

/// The saved reminder behind a tapped notification, or null (the refresh
/// notice, a deleted reminder, a payload this version cannot read).
///
/// The planner writes `{"r": "<id>"}` with the id of the *expanded*
/// reminder ("abc:fajr", "abc:wd"): [baseReminderId] maps it back.
ReminderItem? tappedReminder(String payload, ReminderRepository reminders) {
  final Object? json;
  try {
    json = jsonDecode(payload);
  } on FormatException {
    return null;
  }
  if (json is! Map || json['r'] is! String) return null;
  return reminders.byId(baseReminderId(json['r'] as String));
}
