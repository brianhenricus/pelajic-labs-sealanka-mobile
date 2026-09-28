/// Fallback coordinate used only when LocationService returns null
/// (permission denied, GPS off, or unavailable in an emulator) -- never
/// presented as if it were a real reading, just a sane default so the app
/// still functions. Historically the value every screen hardcoded before
/// the real LocationService existed.
class AppLocation {
  AppLocation._();

  static const defaultLat = 7.8731;
  static const defaultLon = 80.7718;
}
