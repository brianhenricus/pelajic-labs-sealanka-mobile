import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/features/auth/domain/entities/user.dart';
import 'package:sea_lanka/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:sea_lanka/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:sea_lanka/features/auth/presentation/pages/login_page.dart';
import 'package:sea_lanka/features/auth/presentation/pages/otp_login_page.dart';
import 'package:sea_lanka/features/auth/presentation/pages/signup_page.dart';
import 'package:sea_lanka/features/auth/presentation/pages/splash_page.dart';
import 'package:sea_lanka/features/auth/presentation/pages/onboarding_page.dart';
import 'package:sea_lanka/features/auth/presentation/pages/verify_phone_page.dart';
import 'package:sea_lanka/features/home/presentation/pages/home_page.dart';
import 'package:sea_lanka/features/logbook/presentation/pages/add_trip_page.dart';
import 'package:sea_lanka/features/logbook/presentation/pages/logbook_page.dart';
import 'package:sea_lanka/features/pfz/presentation/pages/pfz_map_page.dart';
import 'package:sea_lanka/features/subscription/presentation/pages/subscription_tiers_page.dart';
import 'package:sea_lanka/features/wind/presentation/pages/wind_map_page.dart';
import 'package:sea_lanka/features/ocean/presentation/pages/ocean_current_page.dart';
import 'package:sea_lanka/features/ocean/presentation/pages/tide_graph_page.dart';
import 'package:sea_lanka/features/marine_traffic/presentation/pages/marine_traffic_page.dart';
import 'package:sea_lanka/features/solunar/presentation/pages/solunar_page.dart';
import 'package:sea_lanka/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:sea_lanka/features/profile/presentation/pages/profile_page.dart';
import 'package:sea_lanka/features/profile/presentation/pages/complete_profile_page.dart';
import 'package:sea_lanka/features/alerts/presentation/bloc/alerts_bloc.dart';
import 'package:sea_lanka/features/alerts/presentation/pages/alerts_page.dart';
import 'package:sea_lanka/core/widgets/sea_lanka_bottom_nav.dart';

class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const completeProfile = '/complete-profile';
  static const verifyPhone = '/verify-phone';
  static const forgotPassword = '/forgot-password';
  static const otpLogin = '/login/otp';
  static const subscription = '/subscription';
  static const home = '/home';
  static const pfz = '/pfz';
  // Almanac sub-routes (tab index 2)
  static const almanacWind = '/almanac/wind';
  static const almanacOcean = '/almanac/ocean';
  static const almanacSolunar = '/almanac/solunar';
  // Standalone tabs
  static const marine = '/marine';
  static const logbook = '/logbook';
  static const addTrip = '/logbook/add';
  static const profile = '/profile';
  static const alerts = '/alerts';
}

/// Where to send a just-authenticated user -- phone verification (server-
/// enforced, see sealanka-be's get_verified_user) gates everything else, so
/// it's checked before profile completion. A Google-only account (no
/// phone at all -- nothing in the Google identity provides one) also goes
/// through verify-phone, which shows a phone-entry stage first in that case.
String postAuthRoute(User user) {
  if (!user.phoneVerified) return AppRoutes.verifyPhone;
  if (user.needsProfileCompletion) return AppRoutes.completeProfile;
  return AppRoutes.home;
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, __) => const SplashPage(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, __) => const OnboardingPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => BlocProvider(
        create: (_) => sl<AuthBloc>(),
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (_, __) => BlocProvider(
        create: (_) => sl<AuthBloc>(),
        child: const SignupPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.verifyPhone,
      builder: (_, __) => const VerifyPhonePage(),
    ),
    GoRoute(
      path: AppRoutes.completeProfile,
      builder: (_, __) => BlocProvider(
        create: (_) => sl<ProfileBloc>(),
        child: const CompleteProfilePage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (_, __) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: AppRoutes.otpLogin,
      builder: (_, __) => const OtpLoginPage(),
    ),
    GoRoute(
      path: AppRoutes.subscription,
      builder: (_, __) => const SubscriptionTiersPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => SeaLankaBottomNav(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: AppRoutes.pfz,
          builder: (_, __) => const PfzMapPage(),
        ),
        // Almanac sub-routes all share tab index 2
        GoRoute(
          path: AppRoutes.almanacWind,
          builder: (_, __) => const WindMapPage(),
        ),
        GoRoute(
          path: AppRoutes.almanacOcean,
          builder: (_, __) => const OceanCurrentPage(),
        ),
        GoRoute(
          path: AppRoutes.almanacSolunar,
          builder: (_, __) => const SolunarPage(),
        ),
        // Marine Traffic — standalone tab 3
        GoRoute(
          path: AppRoutes.marine,
          builder: (_, __) => const MarineTrafficPage(),
        ),
        // Logbook — tab 4
        GoRoute(
          path: AppRoutes.logbook,
          builder: (_, __) => const LogbookPage(),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.addTrip,
      builder: (_, __) => const AddTripPage(),
    ),
    // Tide graph pushed from Ocean page
    GoRoute(
      path: '/tide',
      builder: (_, __) => const TideGraphPage(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (_, __) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => sl<ProfileBloc>()),
          BlocProvider(create: (_) => sl<AuthBloc>()),
        ],
        child: const ProfilePage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.alerts,
      builder: (_, __) => BlocProvider(
        create: (_) => sl<AlertsBloc>(),
        child: const AlertsPage(),
      ),
    ),
  ],
);
