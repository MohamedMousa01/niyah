import 'package:flutter/material.dart';

/// Opens the setup sheet of a ready-made moment (time / wake-bed / prayer),
/// used by "Add a reminder" and by template rows in "My reminders".
///
/// Placeholder: the add-reminder work package replaces the body. Keep the
/// signature.
Future<void> showTemplateSheet(BuildContext context, String templateId) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Setup sheet for $templateId')));
}
