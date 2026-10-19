import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/app.dart';
import 'package:niyah/app_scope.dart';

void main() {
  testWidgets('app starts on Home and every tab opens', (tester) async {
    final services = AppServices.fake();
    await services.init();
    await tester.pumpWidget(NiyahApp(services: services));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
