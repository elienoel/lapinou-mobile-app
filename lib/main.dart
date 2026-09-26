import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/rabbit_provider.dart';
import 'providers/community_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/phone_login_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const LapinouApp());
}

class LapinouApp extends StatelessWidget {
  const LapinouApp({super.key});

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
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) => (chat ?? ChatProvider())..setToken(auth.token),
        ),
      ],
      child: MaterialApp(
        title: 'Lapinou - Élevage de Lapins',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) {
      return const MainNavigationScreen();
    }
    return const PhoneLoginScreen();
  }
}
