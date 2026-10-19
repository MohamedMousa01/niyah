import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/data/fake/fake_repositories.dart';

import 'repository_contract.dart';

void main() {
  group('FakeReminderRepository', () {
    reminderRepositoryContract((initial) async => FakeReminderRepository(initial: initial)..init());
  });

  group('FakeTemplateRepository', () {
    templateRepositoryContract(() async => FakeTemplateRepository());
  });
}
