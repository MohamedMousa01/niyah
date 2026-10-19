import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/niyah_theme.dart';
import 'niyah_icons.dart';
import 'tap_area.dart';

/// Header of pushed screens: 44 px back button and an Amiri 28 px title,
/// below the status bar (`padding: 52px 16px 6px 8px` in the design).
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, this.onBack, this.backLabel});

  final String title;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  /// Defaults to "Back"; e.g. "Back to My reminders".
  final String? backLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(8, NiyahInsets.top(context, 52), 16, 6),
      child: Row(
        children: [
          TapArea(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            semanticLabel: backLabel ?? AppLocalizations.of(context).back,
            child: NiyahIcon(NiyahIcons.chevronLeft, size: 24, strokeWidth: 1.8, color: c.text),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Semantics(
              header: true,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: ScreenTitle.maxTextScale,
                child: Text(title, style: NiyahText.serif(28, color: c.text)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amiri screen title of a tab (34 px), with an optional subtitle.
/// Titles stop growing at [maxTextScale] so long words never break.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  /// Largest text scale applied to Amiri titles.
  static const maxTextScale = 1.5;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: maxTextScale,
            child: Text(title, style: NiyahText.serif(34, height: 1.1, color: c.text)),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: NiyahText.sans(14, color: c.text2)),
        ],
      ],
    );
  }
}
