import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart';

/// Home tab (artboard `Main`): Bismillah, title, hero, next prayer and the
/// quick-access cards, over the geometric ornament.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Shown as drawn in the design, in every language.
  static const bismillah = 'بِسْمِ ٱللَّٰهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  /// Rebuilds at each new minute so the next prayer moves on by itself.
  void _scheduleTick() {
    final now = DateTime.now();
    _tick = Timer(Duration(seconds: 60 - now.second), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final prayers = AppScope.of(context).prayers;

    return ColoredBox(
      color: c.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PositionedDirectional(
            top: NiyahInsets.top(context, -60),
            end: -70,
            child: GeometricOrnament(color: c.ornament),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, NiyahInsets.top(context, 72), 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(colors: c, title: l.appName),
                const SizedBox(height: 32 + 8),
                _Hero(colors: c, headline: l.homeHeadline, subtitle: l.homeSubtitle),
                ListenableBuilder(
                  listenable: prayers,
                  builder: (context, _) {
                    final next = prayers.nextPrayer(DateTime.now());
                    if (next == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: _NextPrayer(
                        colors: c,
                        label: l.homeNextPrayer,
                        value: l.homeNextPrayerValue(prayerName(l, next.$1), formatTime(next.$2)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Semantics(
                  container: true,
                  label: l.homeQuickAccess,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinkCard(
                        large: true,
                        icon: NiyahIcons.bell,
                        tone: IconTileTone.primary,
                        title: l.homeRemindersTitle,
                        subtitle: l.homeRemindersSubtitle,
                        onTap: () => context.go(Routes.reminders),
                      ),
                      const SizedBox(height: 12),
                      LinkCard(
                        large: true,
                        icon: NiyahIcons.sliders,
                        title: l.homeSettingsTitle,
                        subtitle: l.homeSettingsSubtitle,
                        onTap: () => context.go(Routes.settings),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors, required this.title});

  final NiyahColors colors;
  final String title;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ScreenTitle.maxTextScale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            HomeScreen.bismillah,
            locale: const Locale('ar'),
            textDirection: TextDirection.rtl,
            style: NiyahText.serif(17, weight: FontWeight.w400, color: colors.text3),
          ),
          const SizedBox(height: 6),
          Semantics(
            header: true,
            child: Text(title, style: NiyahText.serif(30, letterSpacing: 0.2, color: colors.primaryInk)),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.colors, required this.headline, required this.subtitle});

  final NiyahColors colors;
  final String headline;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: ScreenTitle.maxTextScale,
            child: Text(
              headline,
              style: NiyahText.serif(44, weight: FontWeight.w400, height: 1.1, color: colors.text),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(subtitle, style: NiyahText.sans(16, height: 1.55, color: colors.text2)),
        ),
      ],
    );
  }
}

class _NextPrayer extends StatelessWidget {
  const _NextPrayer({required this.colors, required this.label, required this.value});

  final NiyahColors colors;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: colors.border);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: side, bottom: side),
        ),
        child: Row(
          children: [
            NiyahIcon(NiyahIcons.moon, size: 18, strokeWidth: 1.6, color: colors.primaryInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: NiyahText.sans(14, color: colors.text2)),
            ),
            const SizedBox(width: 10),
            Text(
              value,
              style: NiyahText.sans(14, weight: FontWeight.w600, color: colors.text),
            ),
          ],
        ),
      ),
    );
  }
}
