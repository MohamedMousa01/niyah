import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/app_scope.dart';
import '../state/app_settings.dart';
import '../theme/niyah_theme.dart';
import 'widgets.dart';

/// Onboarding breve: benvenuto, lingua, notifiche (architettura §2.2).
/// Il permesso si chiede solo dopo la spiegazione, mai all'avvio (§27).
/// Posizione, interessi e suggerimenti arriveranno con le prossime schermate.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _step = 0;
  static const _steps = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() => _step = step);
    _pages.animateToPage(step, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish({required bool askPermission}) async {
    final controller = AppScope.read(context);
    if (askPermission) await controller.requestPermission();
    await controller.settings.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = AppScope.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: NiyahSpace.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(NiyahSpace.l),
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _Step(
                          children: [
                            const NiyahHeader(),
                            Text(l.onboardingWelcomeTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                            const SizedBox(height: NiyahSpace.m),
                            Text(l.onboardingWelcomeBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                          ],
                        ),
                        _Step(
                          children: [
                            Text(l.onboardingLanguageTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                            const SizedBox(height: NiyahSpace.l),
                            LanguageList(
                              selected: controller.settings.language,
                              onSelected: controller.setLanguage,
                            ),
                          ],
                        ),
                        _Step(
                          children: [
                            Icon(Icons.notifications_active_outlined, size: 48, color: theme.colorScheme.primary),
                            const SizedBox(height: NiyahSpace.l),
                            Text(l.onboardingNotificationsTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                            const SizedBox(height: NiyahSpace.m),
                            Text(l.onboardingNotificationsBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_step < _steps - 1) ...[
                    FilledButton(onPressed: () => _go(_step + 1), child: Text(l.next)),
                    const SizedBox(height: NiyahSpace.s),
                    SizedBox(
                      height: 52,
                      child: _step > 0 ? TextButton(onPressed: () => _go(_step - 1), child: Text(l.back)) : null,
                    ),
                  ] else ...[
                    FilledButton(onPressed: () => _finish(askPermission: true), child: Text(l.allowNotifications)),
                    const SizedBox(height: NiyahSpace.s),
                    SizedBox(
                      height: 52,
                      child: TextButton(onPressed: () => _finish(askPermission: false), child: Text(l.notNow)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// Le 4 lingue, ognuna scritta nella propria lingua.
class LanguageList extends StatelessWidget {
  const LanguageList({super.key, required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (v) {
        if (v != null) onSelected(v);
      },
      child: RowGroup(
        children: [
          for (final lang in kSupportedLanguages)
            RadioListTile<String>(
              value: lang,
              title: Text(
                kLanguageNames[lang]!,
                style: TextStyle(fontFamily: NiyahTheme.fontFor(Locale(lang))),
              ),
            ),
        ],
      ),
    );
  }
}
