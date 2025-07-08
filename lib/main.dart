import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart'; // Import your home page
import 'dart:math' as math;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize the local database before app runs
  await DatabaseService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else {
          lightScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
          darkScheme = ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'ReplyWise',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
          ),
          home: const SplashLoginHomeFlow(),
        );
      },
    );
  }
}

// This widget manages the splash -> login -> splash -> home flow
class SplashLoginHomeFlow extends StatefulWidget {
  const SplashLoginHomeFlow({Key? key}) : super(key: key);

  @override
  State<SplashLoginHomeFlow> createState() => _SplashLoginHomeFlowState();
}

enum AppStage { splash, login, splashAfterLogin, home }

class _SplashLoginHomeFlowState extends State<SplashLoginHomeFlow>
    with SingleTickerProviderStateMixin {
  AppStage _stage = AppStage.splash;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _startSplash();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _startSplash() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _fadeController.forward();
    await Future.delayed(const Duration(seconds: 2));
    // Check for persisted login
    final autoLogin = await _authService.tryAutoLogin();
    if (mounted) {
      setState(() {
        _stage = autoLogin ? AppStage.splashAfterLogin : AppStage.login;
      });
    }
    if (autoLogin) {
      // Short splash after auto-login
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _stage = AppStage.home;
        });
      }
    }
  }

  void _onLoginSuccess() async {
    // Save UID after successful login
    final user = _authService.currentUser;
    if (user != null) {
      await _authService.saveUidToPrefs(user.uid);
    }
    setState(() {
      _stage = AppStage.splashAfterLogin;
    });
    _fadeController.reset();
    _fadeController.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _stage = AppStage.home;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case AppStage.splash:
        return _AnimatedSplashScreen(
          fadeAnimation: _fadeAnimation,
          loading: true,
          title: 'ReplyWise',
          subtitle: 'Smart email management made simple',
        );
      case AppStage.login:
        return LoginPage(onLoginSuccess: _onLoginSuccess);
      case AppStage.splashAfterLogin:
        return _AnimatedSplashScreen(
          fadeAnimation: _fadeAnimation,
          loading: true,
          title: 'ReplyWise',
          subtitle: 'Loading your emails...',
        );
      case AppStage.home:
        // Replace with your actual HomePage widget
        return MyHomePage(title: 'ReplyWise');
    }
  }
}

// Shared animated logo widget with shimmer and scale/fade animation
class ReplyWiseLogo extends StatefulWidget {
  final double size;
  final bool animate;
  const ReplyWiseLogo({Key? key, required this.size, this.animate = false}) : super(key: key);

  @override
  State<ReplyWiseLogo> createState() => _ReplyWiseLogoState();
}

class _ReplyWiseLogoState extends State<ReplyWiseLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant ReplyWiseLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating && _controller.value != 1.0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Hero(
      tag: 'replywise-logo',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Shimmer effect
          final shimmerValue = math.sin(_controller.value * math.pi * 2) * 0.15 + 0.85;
          return Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.8 * shimmerValue),
                      colorScheme.primary.withOpacity(0.5 * shimmerValue),
                      colorScheme.primary.withOpacity(0.25 * shimmerValue),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size * 0.4,
                  child: Center(
                    child: Text(
                      'RW',
                      style: TextStyle(
                        fontFamily: 'RW',
                        fontSize: 60, // fixed size as requested
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary.withOpacity(1.0),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedSplashScreen extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final bool loading;
  final String title;
  final String subtitle;

  const _AnimatedSplashScreen({
    required this.fadeAnimation,
    required this.loading,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.background,
      body: FadeTransition(
        opacity: fadeAnimation,
        child: Center(
          child: AnimatedBuilder(
            animation: fadeAnimation,
            builder: (context, child) {
              // Scale from 0.7 to 1.0 as fadeAnimation goes from 0 to 1
              final scale = 0.7 + 0.3 * fadeAnimation.value;
              return Opacity(
                opacity: fadeAnimation.value,
                child: Transform.scale(
                  scale: scale,
                  child: Text(
                    'RW',
                    style: TextStyle(
                      fontFamily: 'RW', // Use your custom font family as in pubspec.yaml
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
