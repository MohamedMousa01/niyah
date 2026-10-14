import 'package:flutter/widgets.dart';

import 'app_controller.dart';

/// Rende disponibile l'AppController a tutto l'albero dei widget. Chi usa
/// [of] si ricostruisce quando il controller notifica un cambiamento.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Senza dipendenza: per i callback (onTap, onChanged…).
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
