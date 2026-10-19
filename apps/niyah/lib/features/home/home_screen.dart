import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart';

/// Placeholder: replaced by its work package (docs/app-plan.md §5).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        children: [
          ListTile(title: const Text('My reminders'), onTap: () => context.go(Routes.reminders)),
        ],
      ),
    );
  }
}
