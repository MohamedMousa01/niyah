import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niyah/app.dart';
import 'package:niyah/state/app_controller.dart';
import 'package:niyah/ui/home_shell.dart';
import 'package:niyah/ui/onboarding_page.dart';

import 'support.dart';

Future<AppController> _pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}, FakeGateway? gateway}) async {
  // Creato nella zona del test (non in runAsync): le sue Future devono
  // avanzare con pump().
  final c = await makeController(prefs: prefs, gateway: gateway);
  await tester.pumpWidget(NiyahApp(controller: c, startServices: false));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('primo avvio: onboarding, lingua, permesso solo alla fine', (tester) async {
    final gateway = FakeGateway()..enabled = false;
    final c = await _pumpApp(tester, gateway: gateway);
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('Benvenuto in Niyah'), findsOneWidget);
    expect(gateway.enabled, isFalse);

    await tester.tap(find.text('Avanti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(c.settings.language, 'en');
    expect(find.text('Choose your language'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();
    expect(gateway.enabled, isTrue);
    expect(c.settings.onboardingCompleted, isTrue);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('"Non ora" completa l\'onboarding senza chiedere il permesso', (tester) async {
    final gateway = FakeGateway()..enabled = false;
    final c = await _pumpApp(tester, gateway: gateway);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Avanti'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();
    expect(gateway.enabled, isFalse);
    expect(c.settings.onboardingCompleted, isTrue);
  });

  testWidgets('Home: tre accessi, nessun conteggio, porta alle schede', (tester) async {
    await _pumpApp(tester, prefs: {'onboarding_completed': true});
    expect(find.text('Rinnova la tua intenzione.'), findsOneWidget);
    await tester.tap(find.text('Prima di un\'azione, rinnova l\'intenzione.'));
    await tester.pumpAndSettle();
    expect(find.text('Mangiare'), findsOneWidget);

    await tester.tap(find.text('Mangiare'));
    await tester.pumpAndSettle();
    expect(find.textContaining('verifica delle fonti'), findsOneWidget);
  });

  testWidgets('in arabo l\'interfaccia è da destra a sinistra', (tester) async {
    await _pumpApp(tester, prefs: {'onboarding_completed': true, 'language': 'ar'});
    final dir = Directionality.of(tester.element(find.byType(HomeShell)));
    expect(dir, TextDirection.rtl);
    expect(find.text('جدّد نيّتك.'), findsOneWidget);
  });

  testWidgets('Le mie notifiche: attivare un modello e cambiarne i giorni', (tester) async {
    final c = await _pumpApp(tester, prefs: {'onboarding_completed': true});
    await tester.tap(find.text('Le mie notifiche').last);
    await tester.pumpAndSettle();

    expect(find.text('Suggeriti da Niyah'), findsOneWidget);
    expect(find.text('Mattino'), findsOneWidget);
    expect(find.text('Spento'), findsNothing); // modello disattivato
    // Senza contenuti verificati la sezione lo spiega invece di offrire il modello.
    expect(find.text('Corano'), findsNothing);
    expect(find.textContaining('verifica delle fonti'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    final reminders = await c.reminders.templateReminders();
    expect(reminders['morning']!.enabled, isTrue);
    expect(c.lastSummary.pending, greaterThan(0));

    await tester.tap(find.text('Mattino'));
    await tester.pumpAndSettle();
    expect(find.text('Giorni'), findsOneWidget);
    // Toglie tutti i giorni: il salvataggio non è possibile.
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byType(FilterChip).at(i));
      await tester.pump();
    }
    expect(find.text('Scegli almeno un giorno.'), findsOneWidget);
    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();
    final updated = await c.reminders.templateReminders();
    expect(updated['morning']!.daysMask, 1);
    expect(find.textContaining('alle 08:00'), findsOneWidget);
  });

  testWidgets('notifiche disattivate: avviso discreto con accesso alle impostazioni', (tester) async {
    final gateway = FakeGateway()..enabled = false;
    final c = await _pumpApp(tester, prefs: {'onboarding_completed': true}, gateway: gateway);
    await c.refreshPermission();
    await tester.pump();
    await tester.tap(find.text('Le mie notifiche').last);
    await tester.pumpAndSettle();
    expect(find.text('Le notifiche di Niyah sono disattivate su questo telefono.'), findsOneWidget);
    await tester.tap(find.text('Apri impostazioni'));
    expect(gateway.openSettingsCalls, 1);
  });

  testWidgets('Impostazioni: lingua e pausa', (tester) async {
    final c = await _pumpApp(tester, prefs: {'onboarding_completed': true});
    await tester.tap(find.text('Impostazioni').last);
    await tester.pumpAndSettle();
    expect(find.text('Notifiche attive'), findsOneWidget);

    await tester.tap(find.text('Pausa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per 1 ora'));
    await tester.pumpAndSettle();
    expect(c.settings.pausedUntil, isNotNull);
    expect(find.textContaining('In pausa fino a'), findsOneWidget);

    await tester.tap(find.text('Lingua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(c.settings.language, 'fr');
    expect(find.text('Langue'), findsOneWidget);
  });
}
