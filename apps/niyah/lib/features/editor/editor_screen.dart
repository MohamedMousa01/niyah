import 'package:flutter/material.dart';

/// Placeholder: replaced by its work package (docs/app-plan.md §5).
///
/// - `EditorScreen()` writes a new personal reminder.
/// - `EditorScreen(reminderId: id)` edits one (with delete).
/// - `EditorScreen.prayerWords()` edits only the words of the prayer reminder.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key, this.reminderId}) : prayerWordsOnly = false;
  const EditorScreen.prayerWords({super.key})
      : reminderId = null,
        prayerWordsOnly = true;

  final String? reminderId;
  final bool prayerWordsOnly;

  @override
  Widget build(BuildContext context) {
    final title = prayerWordsOnly ? 'Prayer words' : (reminderId == null ? 'Write your own' : 'Edit $reminderId');
    return Scaffold(appBar: AppBar(title: Text(title)));
  }
}
