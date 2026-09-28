# Sea Lanka — Flutter Mobile App

**Company:** Pelajic Labs (Pvt) Ltd  
**Platform:** Android & iOS  
**Flutter:** 3.22+, Dart 3.3+

## Architecture
Strict **Hexagonal (Ports & Adapters)** — every feature has `domain/`, `data/`, `presentation/` layers.  
State management: **BLoC**.  Navigation: **GoRouter**.  DI: **GetIt**.

## Key Commands
```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis (0 errors currently)
flutter build apk        # Release APK
flutter build ios        # Release iOS
flutter test             # Run tests
```

## Design system
Tokens mirror `../sea-lanka-design-system/project/colors_and_type.css` (the source of truth).
- Typography: `lib/core/constants/app_typography.dart` — use `AppTextStyles.{display,h1,h2,h3,bodyL,body,caption,overline}(locale)` (locale-aware; render overline text UPPERCASE). Display font = Inter; body = Inter (DS body fallback until a real Noto Sans TTF is added). Sinhala +15% line-height, Tamil +0.01em tracking applied automatically.
- Colours/spacing/shadows/motion: `app_colors.dart`, `app_spacing.dart`, `app_shadows.dart`, `app_motion.dart`.
- Shared widgets in `lib/core/widgets/`: SeaLankaHeader, SeaLankaCard, SeaLankaButton (variant `cta` = gold gradient), SeaLankaFab, DataStatusBadge, MetricTile, SectionTitle, ZoneTile, ListRow, Attribution, SlSegmented, SlTextField, `showSlBottomSheet`, SeaLankaPressable, LoadingShimmer.
- No spinners for data loading — use `LoadingShimmer`/`ShimmerCard`.

## Backend
No mock layer — every build talks to a real `sealanka-be` instance (`docker compose up -d` in
that repo). `lib/core/network/api_endpoints.dart` → `baseUrl` defaults to `http://localhost:8000/v1`
(desktop/web/iOS simulator, where "localhost" is the dev machine itself). Override with
`--dart-define=API_BASE_URL=...` for:
- **Android emulator**: `http://10.0.2.2:8000/v1` (its own loopback alias for the host).
- **Physical device**: `http://<your-LAN-IP>:8000/v1` — on a real phone, "localhost" means the
  *phone*, not your PC, so the default silently fails with `DioExceptionType.connectionError`
  ("Connection refused"). Find your machine's Wi-Fi adapter IPv4 with `ipconfig` (Windows) /
  `ifconfig` (macOS/Linux); phone and dev machine must be on the same Wi-Fi/LAN. That IP can
  change on reconnect (DHCP) — recheck if the app that worked yesterday can't connect today.
- **Deployed backend**: `https://api.sealanka.lk/v1` (once it exists).

## Before building for real devices
1. **Fonts** — real **Inter** TTFs are in `assets/fonts/Inter/`. Noto Sans (base body), NotoSansSinhala, and NotoSansTamil are still 12-byte placeholders — drop real TTFs in `assets/fonts/` for full multilingual rendering. Poppins has been removed.
2. **Google Maps API Key** — add your key to:
   - `android/app/src/main/AndroidManifest.xml` → `com.google.android.geo.API_KEY`
   - `ios/Runner/AppDelegate.swift` → `GMSServices.provideAPIKey(...)`
3. **Backend URL** — set `--dart-define=API_BASE_URL=...` for your target (see Backend section above).
4. **Android signing** — add `android/key.properties` and configure `android/app/build.gradle`.
5. **iOS signing** — configure team ID and bundle identifier in Xcode.
6. **Google Sign-In** — needs BOTH of these or it fails silently after the account picker:
   - `--dart-define=GOOGLE_WEB_CLIENT_ID=...` (the Web application OAuth client ID, not the
     Android one — `lib/core/constants/google_config.dart` defaults to `''`, which is a silent
     no-op, not an error you'll see at build time). Must match the backend's `GOOGLE_CLIENT_ID`.
   - Your signing certificate's SHA-1 registered against the Firebase project (`sealanka-f7a83`)
     → Project Settings → the Android app → "Add fingerprint", then re-download
     `android/app/google-services.json` — `oauth_client` in that file is empty until this is done.
     Debug builds sign with `android/sealanka-debug.keystore` (a project-specific keystore, not
     Android's shared machine-wide `~/.android/debug.keystore` — that default is reused by every
     Android project built on the same machine, so its SHA-1 can already be registered to a
     *different* Google Cloud project, which blocks registering it here too). Get its SHA-1 with:
     `keytool -list -v -keystore android/sealanka-debug.keystore -alias androiddebugkey -storepass android -keypass android`
     A release build needs its own real signing config (see item 4) with its own SHA-1 registered
     the same way once one exists.
   - Use `scripts/run_on_device.sh <your-LAN-IP>` to build+install a physical-device debug build
     with the web client ID already baked in, instead of typing both dart-defines by hand.
7. **OTP SMS autofill (Android)** — the `sms_autofill` package uses the SMS Retriever API, which
   silently drops any SMS not ending in an 11-char hash tied to the signing certificate (sealanka-be's
   `app/services/auth/service.py`'s `_ANDROID_SMS_AUTOFILL_HASH`, currently computed for
   `android/sealanka-debug.keystore`). Recompute it for a release keystore (algorithm: SHA-256 of
   `"<package_name> <hex-encoded DER certificate>"`, truncated to 9 bytes, base64, first 11 chars —
   see `AppSignatureHelper.java` in the `sms_autofill` package for the reference implementation) and
   update that backend constant, or autofill will stop working on release builds with no visible error.

## Feature Map
| Route | Feature | Status |
|---|---|---|
| `/` | Splash + auth check | ✅ |
| `/login` | Login | ✅ |
| `/signup` | Sign up | ✅ |
| `/forgot-password` | OTP reset | ✅ |
| `/subscription` | Plan tiers | ✅ BLoC |
| `/home` | Dashboard + weather | ✅ BLoC |
| `/pfz` | Fishing zone map | ✅ BLoC |
| `/logbook` | Trip logbook | ✅ BLoC |
| `/logbook/add` | Add trip | ✅ |
| `/alerts` | Safety alerts (entry: home header bell) | ✅ BLoC |
| `/profile` | User profile (entry: home header avatar) | ✅ BLoC |
| `/almanac/wind` | Wind map (Windy) | ✅ WebView |
| `/almanac/ocean` | Ocean currents | ✅ BLoC |
| `/tide` | Tide graph | ✅ BLoC |
| `/marine` | AIS traffic (MarineTraffic) | ✅ WebView |
| `/almanac/solunar` | Solunar calendar | ✅ BLoC |

Bloc provisioning: `home`, `pfz`, `profile`, `alerts` are provided at the route via `sl<XBloc>()`;
`subscription`, `logbook`, `ocean`, `solunar` self-provide their bloc inside the page (built from
`sl<Dio>()`/`sl<NetworkInfo>()`). Both patterns are valid.

## Localisation
ARB files: `lib/core/l10n/app_en.arb`, `app_si.arb`, `app_ta.arb`.  
Run `flutter gen-l10n` to generate `AppLocalizations`.
