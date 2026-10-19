import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';

/// Placeholder: replaced by its work package (docs/app-plan.md §5).
class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer reminders')),
      body: ListView(
        children: [
          ListTile(title: const Text('Change the words'), onTap: () => context.push(Routes.prayerWords)),
        ],
      ),
    );
  }
}
