import 'package:geolocator/geolocator.dart';

import 'repositories.dart';

/// [LocationService] on `geolocator`: one coarse fix (about 1–3 km, enough
/// for prayer times), only when the user asks for it.
class GeolocatorLocationService implements LocationService {
  static const _timeout = Duration(seconds: 20);

  @override
  Future<PositionResult> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const PositionFailed(PositionProblem.serviceOff);
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      switch (permission) {
        case LocationPermission.denied:
          return const PositionFailed(PositionProblem.denied);
        case LocationPermission.deniedForever:
          return const PositionFailed(PositionProblem.deniedForever);
        case LocationPermission.whileInUse || LocationPermission.always || LocationPermission.unableToDetermine:
          break;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: _timeout),
      );
      return PositionFound(p.latitude, p.longitude);
    } catch (_) {
      return const PositionFailed(PositionProblem.unavailable);
    }
  }

  @override
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
