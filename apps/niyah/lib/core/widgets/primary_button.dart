import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';
import 'niyah_icons.dart';

enum _Variant { primary, danger, outline }

/// Full-width button, 54 px tall with a 16 px radius.
///
/// - `PrimaryButton`: `primary` fill. A null [onPressed] shows the disabled
///   style (`chipOff` fill, `text3` label), e.g. "Pick at least one day".
/// - `PrimaryButton.danger`: `danger` fill ("Delete" in the delete sheet).
/// - `PrimaryButton.outline`: `surface` with an `inputBorder` outline
///   ("Turn it off instead").
///
/// The delete sheet draws its two buttons at [height] 52.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.height = 54})
    : _variant = _Variant.primary;

  const PrimaryButton.danger({super.key, required this.label, required this.onPressed, this.height = 54})
    : _variant = _Variant.danger;

  const PrimaryButton.outline({super.key, required this.label, required this.onPressed, this.height = 54})
    : _variant = _Variant.outline;

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final enabled = onPressed != null;
    final (Color bg, Color fg, BorderSide side) = switch (_variant) {
      _ when !enabled => (c.chipOff, c.text3, BorderSide.none),
      _Variant.primary => (c.primary, c.onPrimary, BorderSide.none),
      _Variant.danger => (c.danger, c.onPrimary, BorderSide.none),
      _Variant.outline => (c.surface, c.text, BorderSide(color: c.inputBorder)),
    };
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: side);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: NiyahText.sans(
                16,
                weight: _variant == _Variant.outline ? FontWeight.w600 : FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44 px text button (15 px semibold), optionally with a leading icon:
/// "Cancel" (`primaryInk`), "Delete reminder" / "Remove from my reminders"
/// ([danger]: `dangerInk`), "Change the words".
class NiyahTextButton extends StatelessWidget {
  const NiyahTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.fontSize = 15,
    this.center = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? icon;
  final bool danger;
  final double fontSize;

  /// Centred in the available width (sheet footers) or start-aligned.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final color = danger ? c.dangerInk : c.primaryInk;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: center ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (icon != null) ...[
                NiyahIcon(icon!, size: 18, strokeWidth: 1.8, color: color),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  style: NiyahText.sans(fontSize, weight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
