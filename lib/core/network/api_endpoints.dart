class ApiEndpoints {
  ApiEndpoints._();

  // No mock layer anymore -- every build talks to a real sealanka-be
  // instance. Defaults to the local dev backend (docker compose up -d in
  // sealanka-be, bound to 0.0.0.0:8000 so it's reachable beyond localhost).
  // "localhost" only resolves to the backend host itself, though -- override
  // per target:
  //   Android emulator (its own loopback alias for the host machine):
  //     --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1
  //   Physical device (phone and dev machine on the same Wi-Fi/LAN --
  //   "localhost" on the PHONE means the phone itself, not your PC, hence
  //   DioExceptionType.connectionError/"Connection refused" if left unset.
  //   Find your machine's LAN IP with `ipconfig` (Windows) / `ifconfig`
  //   (macOS/Linux) -- look for the Wi-Fi adapter's IPv4, e.g.:
  //     --dart-define=API_BASE_URL=http://192.168.1.6:8000/v1
  //   That IP is whatever your dev machine's Wi-Fi adapter has *today* --
  //   DHCP can reassign it, so re-check with `ipconfig`/`ifconfig` if the
  //   app suddenly can't connect after a network change or reboot.
  //   Production, once deployed:
  //     --dart-define=API_BASE_URL=https://api.sealanka.lk/v1
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/v1',
  );

  // Auth
  static const login = '/auth/login';
  static const signup = '/auth/signup';
  static const logout = '/auth/logout';
  static const refreshToken = '/auth/refresh';
  static const sendOtp = '/auth/otp/send';
  static const verifyOtp = '/auth/otp/verify';
  static const resetPassword = '/auth/otp/reset';
  static const googleLogin = '/auth/google';
  static const setPhone = '/auth/set-phone';
  static const loginOtpRequest = '/auth/login/otp/request';
  static const loginOtpVerify = '/auth/login/otp/verify';

  // Home
  static const weatherSummary = '/weather/summary';
  static const weatherForecast = '/weather/forecast';
  static const fishingCondition = '/fishing/condition';

  // PFZ
  static const pfzZones = '/pfz/zones';
  static const pfzZoneDetail = '/pfz/zones/{id}';
  static const pfzExport = '/pfz/export';

  // Subscription
  static const subscriptionPlans = '/subscription/plans';
  static const subscribe = '/subscription/subscribe';
  static const mySubscription = '/subscription/me';

  // Logbook
  static const tripLogs = '/logbook/trips';
  static const createTrip = '/logbook/trips';
  static const logbookPhotos = '/logbook/photos';

  // Alerts
  static const safetyAlerts = '/alerts';

  // Wind
  static const windData = '/wind/current';
  static const windGrid = '/wind/grid';
  static const windOutlook = '/wind/outlook';
  static const windForecastHours = '/wind/forecast-hours';

  // Ocean
  static const oceanCurrents = '/ocean/currents';
  static const oceanCurrentsGrid = '/ocean/currents/grid';
  static const oceanCurrentsOutlook = '/ocean/currents/outlook';
  static const tidePredictions = '/ocean/tides';

  // Rain radar
  static const rainRadarFrames = '/rain/radar/frames';

  // Marine Traffic
  static const vessels = '/marine/vessels';
  static const vesselsCell = '/marine/vessels/cell';
  static const vesselsAll = '/marine/vessels/all';

  // Solunar
  static const solunarData = '/solunar';

  // Profile
  static const profile = '/profile';
}
