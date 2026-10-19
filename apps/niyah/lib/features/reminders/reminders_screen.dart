import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';

/// Placeholder: replaced by its work package (docs/app-plan.md §5).
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My reminders')),
      body: ListView(
        children: [
          ListTile(title: const Text('Add'), onTap: () => context.push(Routes.add)),
          ListTile(title: const Text('Write your own'), onTap: () => context.push(Routes.newReminder)),
          ListTile(title: const Text('Edit p1'), onTap: () => context.push(Routes.edit('p1'))),
          ListTile(title: const Text('Prayer reminders'), onTap: () => context.push(Routes.prayer)),
        ],
      ),
    );
  }
}
