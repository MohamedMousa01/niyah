import 'package:flutter/material.dart';

import '../theme/niyah_theme.dart';

/// The design's switch: 48×28 track, 22 px knob, inside a 54×44 hit area.
/// Exposed to screen readers as a switch named [semanticLabel].
class NiyahSwitch extends StatelessWidget {
  const NiyahSwitch({super.key, required this.value, required this.onChanged, required this.semanticLabel});

  final bool value;

  /// Null disables the switch.
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  static const _duration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : _duration;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: 54,
          height: 44,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: AnimatedContainer(
                duration: duration,
                width: 48,
                height: 28,
                decoration: BoxDecoration(
                  color: value ? c.primary : c.trackOff,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: AnimatedAlign(
                  duration: duration,
                  alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.knob,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(0, 1), blurRadius: 2)],
                      ),
                      child: const SizedBox.square(dimension: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
