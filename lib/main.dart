import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/rabbit_provider.dart';
import 'providers/community_provider.dart';
import 'providers/category_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/pharmacy_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/phone_login_screen.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  SyncService.instance.start();
  runApp(const ClapInApp());
}

class ClapInApp extends StatelessWidget {
  const ClapInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, RabbitProvider>(
          create: (_) => RabbitProvider(),
          update:
              (_, auth, rabbitProvider) =>
                  (rabbitProvider ?? RabbitProvider())..setToken(auth.token),
        ),
        ChangeNotifierProvider.value(value: SyncService.instance),
        ChangeNotifierProxyProvider<AuthProvider, CommunityProvider>(
          create: (_) => CommunityProvider(),
          update: (_, auth, community) {
            if (auth.token == null) (community ?? CommunityProvider()).clear();
            return community ?? CommunityProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => PharmacyProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update:
              (_, auth, chat) => (chat ?? ChatProvider())..setToken(auth.token),
        ),
      ],
      child: MaterialApp(
        title: "Clap'in - Élevage de Lapins",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// null tant que la préférence locale n'est pas lue.
  bool? _onboardingSeen;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    var seen = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(kOnboardingSeenKey) ?? false;
    } catch (_) {}
    if (mounted) setState(() => _onboardingSeen = seen);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      return const MainNavigationScreen();
    }
    if (_onboardingSeen == null) {
      return const Scaffold(backgroundColor: AppColors.secondary);
    }
    if (!_onboardingSeen!) {
      return OnboardingScreen(
        onFinished: () => setState(() => _onboardingSeen = true),
      );
    }
    return const PhoneLoginScreen();
  }
}
