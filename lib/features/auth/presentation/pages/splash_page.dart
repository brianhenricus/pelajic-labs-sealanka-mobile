import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sea_lanka/core/constants/app_colors.dart';
import 'package:sea_lanka/core/constants/app_spacing.dart';
import 'package:sea_lanka/core/constants/app_typography.dart';
import 'package:sea_lanka/core/di/injection_container.dart';
import 'package:sea_lanka/core/router/app_router.dart';
import 'package:sea_lanka/core/widgets/attribution.dart';
import 'package:sea_lanka/features/auth/presentation/bloc/auth_bloc.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;

  // Multilingual greetings: English | Sinhala | Tamil
  final List<_MultilingualText> _greetings = const [
    _MultilingualText(text: 'Welcome', fontFamily: 'Inter'),
    _MultilingualText(text: 'ආයුබෝවන්', fontFamily: 'NotoSansSinhala'),
    _MultilingualText(text: 'வணக்கம்', fontFamily: 'NotoSansTamil'),
  ];
  int _greetingIndex = 0;
  double _greetingOpacity = 1.0;

  // AuthBloc is registered as a factory in DI, so sl<AuthBloc>() must be
  // called exactly once here and reused — calling it again in
  // _scheduleAuthCheck would create a second, unwatched instance and the
  // BlocListener below would never see the result, leaving splash stuck.
  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>();

    // Logo animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.75, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Text cycle controller (fade in/out each greeting)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _logoController.forward();
    _startGreetingCycle();
    _scheduleAuthCheck();
  }

  void _startGreetingCycle() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) break;
      // Fade out
      setState(() => _greetingOpacity = 0);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) break;
      // Change text + fade in
      setState(() {
        _greetingIndex = (_greetingIndex + 1) % _greetings.length;
        _greetingOpacity = 1;
      });
    }
  }

  Future<void> _scheduleAuthCheck() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (mounted) {
      _authBloc.add(AuthCheckRequested());
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final locale = Localizations.localeOf(context);
    final t = AppLocalizations.of(context)!;
    return BlocProvider.value(
      value: _authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go(postAuthRoute(state.user));
          } else if (state is AuthUnauthenticated) {
            bool seenOnboarding = false;
            try {
              seenOnboarding =
                  sl<Box>().get('onboarding_seen', defaultValue: false) as bool;
            } catch (_) {}
            context.go(seenOnboarding ? AppRoutes.login : AppRoutes.onboarding);
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.midnightNavy,
          body: Stack(
            children: [
              // Radial gradient background
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 1.0,
                      colors: [
                        AppColors.deepSeaBlue, // at centre
                        AppColors.midnightNavy,
                      ],
                      stops: [0.0, 1.0],
                    ),
                  ),
                ),
              ),
              // Subtle wave-like bottom decoration
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.06,
                  child: CustomPaint(
                    size: Size(size.width, 120),
                    painter: _WavePainter(),
                  ),
                ),
              ),
              // Main content
              Positioned.fill(
                child: SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      // Logo mark
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (_, __) => FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: _LogoMark(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // Wordmark
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (_, __) => FadeTransition(
                          opacity: _logoFade,
                          child: Column(
                            children: [
                              Text(
                                t.appName,
                                style: AppTextStyles.display(locale).copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                t.appTagline,
                                style: AppTextStyles.body(locale).copyWith(
                                  color: AppColors.fgOnDark2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      // Rotating multilingual greeting
                      AnimatedOpacity(
                        opacity: _greetingOpacity,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _greetings[_greetingIndex].text,
                          style: AppTextStyles.h2(locale).copyWith(
                            fontFamily: _greetings[_greetingIndex].fontFamily,
                            color: AppColors.white.withOpacity(0.85),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl3),
                      // Footer
                      Attribution(color: AppColors.white.withOpacity(0.4)),
                      const SizedBox(height: AppSpacing.xl2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo/logo-sealanka-transparent.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.3,
        size.width * 0.5, size.height * 0.55);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.8, size.width, size.height * 0.5);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MultilingualText {
  final String text;
  final String fontFamily;
  const _MultilingualText({required this.text, required this.fontFamily});
}
