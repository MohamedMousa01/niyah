import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';

/// Placeholder: replaced by its work package (docs/app-plan.md §5).
class AddReminderScreen extends StatelessWidget {
  const AddReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a reminder')),
      body: ListView(
        children: [
          ListTile(title: const Text('Write your own'), onTap: () => context.push(Routes.newReminder)),
        ],
      ),
    );
  }
}
