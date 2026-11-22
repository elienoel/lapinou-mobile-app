import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/breeding_settings_provider.dart';
import 'providers/rabbit_provider.dart';
import 'providers/community_provider.dart';
import 'providers/category_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/pharmacy_provider.dart';
import 'providers/marketplace_provider.dart';
import 'providers/promotions_provider.dart';
import 'providers/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/phone_login_screen.dart';
import 'services/auth_http_client.dart';
import 'services/reminder_notifications.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';

void main() {
  // Toutes les requêtes HTTP de l'app passent par ce client : il renouvelle
  // la session expirée et rejoue la requête, sans déconnecter l'éleveur.
  // Le vrai client est créé hors de la zone, sinon il se renverrait à lui-même.
  final inner = http.Client();
  // Tout le démarrage se fait dans la zone du client : Flutter exige que
  // `ensureInitialized` et `runApp` s'exécutent dans la même zone.
  http.runWithClient(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr_FR', null);
    await ReminderNotifications.instance.init();
    SyncService.instance.start();
    runApp(const ClapInApp());
  }, () => AuthHttpClient(inner));
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
        ChangeNotifierProvider(create: (_) => PromotionsProvider()),
        ChangeNotifierProvider(create: (_) => BreedingSettingsProvider()),
        ChangeNotifierProxyProvider<AuthProvider, MarketplaceProvider>(
          create: (_) => MarketplaceProvider(),
          update:
              (_, auth, market) =>
                  (market ?? MarketplaceProvider())..setToken(auth.token),
        ),
        ChangeNotifierProxyProvider<AuthProvider, SubscriptionProvider>(
          create: (_) => SubscriptionProvider(),
          update:
              (_, auth, sub) =>
                  (sub ?? SubscriptionProvider())..setToken(auth.token),
        ),
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
