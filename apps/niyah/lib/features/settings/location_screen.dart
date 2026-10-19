import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/format.dart';
import '../../core/theme/niyah_theme.dart';
import '../../core/widgets/widgets.dart';
import '../../data/city_search.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// "Prayer location": the phone's position once, or a city from the offline
/// list. Saving pops back to Settings.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _query = TextEditingController();
  List<PrayerLocation> _results = const [];

  /// Number of the latest search: older answers arriving late are dropped.
  int _search = 0;
  bool _locating = false;

  /// Why the last GPS attempt failed (no city near counts too).
  String? _problem;
  bool _offerSettings = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _onQuery(String text) async {
    final n = ++_search;
    final results = await AppScope.of(context).cities.search(text);
    if (mounted && n == _search) setState(() => _results = results);
  }

  Future<void> _choose(PrayerLocation location) async {
    final navigator = Navigator.of(context);
    await AppScope.of(context).settings.setLocation(location);
    if (mounted) navigator.maybePop();
  }

  Future<void> _useGps() async {
    if (_locating) return;
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context);
    setState(() {
      _locating = true;
      _problem = null;
      _offerSettings = false;
    });
    final result = await s.location.currentPosition();
    PrayerLocation? found;
    String? problem;
    switch (result) {
      case PositionFound(:final latitude, :final longitude):
        final city = await s.cities.nearest(latitude, longitude);
        if (city == null) {
          problem = l.locationNoCityNear;
        } else {
          found = gpsLocation(latitude, longitude, city);
        }
      case PositionFailed(problem: final p):
        problem = switch (p) {
          PositionProblem.serviceOff => l.locationServiceOff,
          PositionProblem.denied => l.locationDenied,
          PositionProblem.deniedForever => l.locationDeniedForever,
          PositionProblem.unavailable => l.locationUnavailable,
        };
        _offerSettings = p == PositionProblem.deniedForever;
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _problem = problem;
    });
    if (found != null) await _choose(found);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    final l = AppLocalizations.of(context);
    final s = AppScope.of(context);
    final current = s.settings.location;
    return Scaffold(
      body: Column(
        children: [
          BackHeader(title: l.locationTitle),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                if (current != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      l.locationCurrent(prayerLocationLabel(l, current, s.settings.method)!),
                      style: NiyahText.sans(14, height: 1.4, color: c.text2),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                LinkCard(
                  icon: 'pin',
                  tone: IconTileTone.primary,
                  title: l.locationUseGps,
                  subtitle: _locating ? l.locationFinding : l.locationGpsNote,
                  onTap: _useGps,
                ),
                if (_problem != null) ...[
                  const SizedBox(height: 10),
                  Semantics(liveRegion: true, child: QuoteBox(body: _problem!)),
                  if (_offerSettings)
                    NiyahTextButton(label: l.openSettings, center: false, onPressed: s.location.openAppSettings),
                ],
                const SizedBox(height: 24),
                SectionLabel(l.locationSearchLabel),
                const SizedBox(height: 10),
                _SearchField(controller: _query, hint: l.locationSearchHint, onChanged: _onQuery),
                const SizedBox(height: 12),
                if (_results.isNotEmpty)
                  SettingsCard(
                    children: [
                      for (final city in _results)
                        ChoiceRow(
                          title: city.name,
                          subtitle: '${city.country} · ${city.timezone}',
                          selected: current != null && !current.fromGps && current == city,
                          onTap: () => _choose(city),
                        ),
                    ],
                  )
                else if (foldCityName(_query.text).isNotEmpty)
                  SettingsNote(l.locationNoResults),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.niyah;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      autocorrect: false,
      cursorColor: c.primary,
      style: NiyahText.sans(16, color: c.text),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: NiyahText.sans(16, color: c.text3),
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
          child: NiyahIcon('search', size: 20, color: c.text2),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 20),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: border(c.inputBorder, 1),
        focusedBorder: border(c.primary, 2),
        border: border(c.inputBorder, 1),
      ),
    );
  }
}
