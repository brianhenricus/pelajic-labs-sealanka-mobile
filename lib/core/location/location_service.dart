import 'package:geolocator/geolocator.dart';
import 'package:sea_lanka/core/constants/app_location.dart';

/// Mirrors NetworkInfo's pattern (lib/core/network/network_info.dart).
/// Returns null rather than throwing when a position can't be obtained
/// (permission denied, location services off) so callers can fall back to
/// a default coordinate instead of crashing or hanging.
abstract class LocationService {
  Future<Position?> getCurrentPosition();

  /// Convenience for every feature that just wants a coordinate to query
  /// with -- resolves the real device position, falling back to
  /// [AppLocation]'s fixed Sri Lanka coordinate only when the device
  /// position genuinely can't be obtained. Never fabricates a "real" reading.
  Future<(double lat, double lon)> getLatLonOrDefault() async {
    final position = await getCurrentPosition();
    if (position == null) return (AppLocation.defaultLat, AppLocation.defaultLon);
    return (position.latitude, position.longitude);
  }
}

class LocationServiceImpl extends LocationService {
  @override
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        // A fresh GPS fix can time out indoors/weak signal -- the device's
        // last known position (usually seconds to minutes old, network or
        // GPS) is still far more accurate than falling straight through to
        // AppLocation's generic island-center default, which put a
        // fisherman standing near the coast onto an inland point with no
        // marine data at all.
        return await Geolocator.getLastKnownPosition();
      }
    } catch (_) {
      // Emulators without a fix, platform channel errors, etc. -- any
      // failure here just means "use the fallback," never crash on it.
      return null;
    }
  }
}
