# Sea Lanka — Mobile App

AI-powered fishing companion for Sri Lankan fishermen: weather, potential
fishing-zone (PFZ) predictions, marine traffic, a fishing logbook, tide/
solunar calendars, and safety alerts. Flutter (Android & iOS), talking to
the [`sealanka-be`](https://github.com/brianhenricus/pelajic-labs-sealanka-be)
FastAPI backend.

**Company:** Pelajic Labs (Pvt) Ltd
**Flutter:** 3.22+, Dart 3.3+

## Architecture

Strict **Hexagonal (Ports & Adapters)** — every feature under `lib/features/`
has its own `domain/` (entities, repository interfaces, use cases), `data/`
(repository implementations, remote/local datasources, models), and
`presentation/` (BLoC, pages, widgets) layers.

```
lib/
  core/               Cross-cutting: network client, router, DI (GetIt),
                      design-system tokens/widgets, l10n.
  features/<name>/
    domain/           Entities, repository interfaces, use cases.
    data/             Repository impls, datasources, JSON models.
    presentation/     BLoC (flutter_bloc), pages, widgets.
```

- **State management:** BLoC (`flutter_bloc`).
- **Navigation:** GoRouter.
- **DI:** GetIt.
- **No mock layer** — every build talks to a real `sealanka-be` instance.

## Feature map

| Route | Feature |
|---|---|
| `/` | Splash + auth check |
| `/login` | Login (phone/password, Google, OTP) |
| `/login/otp` | Passwordless OTP login |
| `/signup` | Sign up |
| `/forgot-password` | Password reset via OTP |
| `/verify-phone` | Mandatory phone verification gate |
| `/subscription` | Plan tiers, current plan, change plan, payment details |
| `/home` | Dashboard + weather |
| `/pfz` | Fishing zone map |
| `/logbook`, `/logbook/add` | Trip logbook |
| `/alerts` | Safety alerts |
| `/profile` | User profile + settings |
| `/almanac/wind` | Wind map (Windy) |
| `/almanac/ocean`, `/tide` | Ocean currents, tide graph |
| `/marine` | AIS traffic (MarineTraffic) |
| `/almanac/solunar` | Solunar calendar |

## Design system

Tokens mirror `../sea-lanka-design-system/project/colors_and_type.css` (the
source of truth): `lib/core/constants/app_{colors,spacing,shadows,motion}.dart`,
typography via `AppTextStyles` in `app_typography.dart` (locale-aware —
Sinhala/Tamil get adjusted line-height/tracking automatically). Shared
widgets live in `lib/core/widgets/` (SeaLankaButton, SeaLankaCard,
SlTextField, LoadingShimmer, etc. — see `CLAUDE.md` for the full list).

## Backend integration

`lib/core/network/api_endpoints.dart`'s `baseUrl` defaults to
`http://localhost:8000/v1`. Override per target with `--dart-define`:

- **Android emulator:** `--dart-define=API_BASE_URL=http://10.0.2.2:8000/v1`
- **Physical device:** `--dart-define=API_BASE_URL=http://<your-LAN-IP>:8000/v1`
  (phone and dev machine must be on the same Wi-Fi; that IP changes with
  DHCP, recheck with `ipconfig`/`ifconfig` if a working build stops connecting)
- **Deployed backend:** `--dart-define=API_BASE_URL=https://api.sealanka.lk/v1`

`scripts/run_on_device.sh <your-LAN-IP>` builds + installs a physical-device
debug build with the Google Sign-In web client ID already baked in, instead
of typing multiple `--dart-define` flags by hand.

## Getting started

```sh
flutter pub get
flutter gen-l10n          # regenerate AppLocalizations after editing lib/core/l10n/*.arb
flutter analyze
flutter test
```

Before building for a real device, see **"Before building for real
devices"** in `CLAUDE.md` — fonts, Google Maps API key, Android/iOS
signing, and the two things Google Sign-In needs (a web client ID
dart-define + your signing certificate's SHA-1 registered with the OAuth
client) or it fails silently after the account picker.

```sh
flutter build apk --debug --dart-define=API_BASE_URL=... --dart-define=GOOGLE_WEB_CLIENT_ID=...
flutter build ios
```

## Localisation

ARB files: `lib/core/l10n/app_{en,si,ta}.arb`. Run `flutter gen-l10n` to
regenerate `AppLocalizations` after editing them. No em dash in any
user-visible string — use `·`, a comma, a period, or `-` instead.

## Signing

`android/sealanka-debug.keystore` is **not** committed (see `.gitignore`) —
it's deliberately project-specific rather than the shared machine-wide
default debug keystore, so its SHA-1 can be registered with Google Sign-In's
OAuth client without colliding with any other project on the same machine.
A fresh clone needs to generate its own and re-register its SHA-1; see
`CLAUDE.md`'s "Google Sign-In" section for the exact `keytool` command and
where to register it.
