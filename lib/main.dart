import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sea_lanka/core/di/injection_container.dart' as di;
import 'package:sea_lanka/core/notifications/push_notification_service.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/theme/app_theme.dart';
import 'package:sea_lanka/core/theme/app_theme_dark.dart';

/// App-wide current locale. A ValueNotifier is enough here — this is the
/// only piece of global mutable UI state in the app, so a full Cubit/Provider
/// setup would be pure ceremony.
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await di.init();

  try {
    await initPushNotifications();
  } catch (e) {
    // Never block app startup on push registration (e.g. no Google Play
    // Services on some emulators/devices).
    debugPrint('Push notification init failed: $e');
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const SeaLankaApp());
}

class SeaLankaApp extends StatefulWidget {
  const SeaLankaApp({super.key});

  @override
  State<SeaLankaApp> createState() => _SeaLankaAppState();
}

class _SeaLankaAppState extends State<SeaLankaApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) {
        return MaterialApp.router(
          title: 'Sea Lanka',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(locale),
          darkTheme: AppThemeDark.dark(locale),
          themeMode: ThemeMode.light,
          locale: locale,
          supportedLocales: const [
            Locale('en'),
            Locale('si'),
            Locale('ta'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: appRouter,
          // Clamps the device's system font-scale setting instead of
          // ignoring it (inaccessible) or applying it unbounded (Android's
          // "Large text" accessibility setting can reach 1.3-2x -- every
          // fixed-height screen in the app, not just the two already fixed
          // for overflow, would be at real risk of breaking for anyone
          // using it, a setting skewed toward exactly this app's older
          // fisherman demographic).
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context)
                  .textScaler
                  .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
            ),
            child: child!,
          ),
        );
      },
    );
  }
}
