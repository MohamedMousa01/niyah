import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/niyah_theme.dart';
import 'geometric_ornament.dart';

/// "How it will arrive": a mock system notification on a `previewBg` panel
/// (24 px radius). [title] is one line, [body] at most two; [time] is the
/// top-right text ("07:15" or "before Fajr").
class NotificationPreview extends StatelessWidget {
  const NotificationPreview({super.key, required this.title, required this.body, required this.time, this.label});

  final String title;
  final String body;
  final String time;

  /// Panel caption; defaults to "How it will arrive".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final caption = label ?? l.editorPreviewLabel;
    return Semantics(
      container: true,
      label: caption,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.previewBg, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                caption.toUpperCase(),
                style: NiyahText.sans(12, weight: FontWeight.w700, letterSpacing: 1.2, color: c.text2),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: NiyahColors.cardShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                    child: GeometricOrnament.icon(color: c.onPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.appName,
                                style: NiyahText.sans(12, weight: FontWeight.w600, color: c.text2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(time, style: NiyahText.sans(12, color: c.text2)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NiyahText.sans(15, weight: FontWeight.w700, color: c.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: NiyahText.sans(14, height: 1.4, color: c.textBody),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
