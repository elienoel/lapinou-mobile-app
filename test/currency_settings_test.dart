import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/models/currency.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/screens/finances_screen.dart';
import 'package:lapinou/screens/profile_screen.dart';
import 'package:lapinou/screens/settings_screen.dart';

// L'espace fine insécable que intl utilise comme séparateur de milliers en français
const _nnbsp = ' ';

Future<AuthProvider> _auth(WidgetTester tester, {String? currency}) async {
  SharedPreferences.setMockInitialValues({
    'auth_token': 'tok',
    'user_data': jsonEncode({
      'id': 7,
      'username': 'u',
      'first_name': 'Awa',
      if (currency != null) 'currency': currency,
    }),
  });
  final auth = AuthProvider();
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  return auth;
}

Widget _app(AuthProvider auth, Widget home, {RabbitProvider? rabbits}) => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<RabbitProvider>.value(value: rabbits ?? RabbitProvider()),
      ],
      child: MaterialApp(home: home),
    );

http.Response _json(Map<String, dynamic> body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('AppCurrency', () {
    test('formats with french grouping, decimals and symbol', () {
      final eur = currencyByCode('EUR');
      expect(eur.format(1250.5), '1${_nnbsp}250,50 €');
      expect(eur.format(35), '35,00 €');
      expect(currencyByCode('XOF').format(125000), '125${_nnbsp}000 FCFA');
      expect(currencyByCode('USD').format(9.9), r'9,90 $');
    });

    test('signs, rounding and decimals override', () {
      final eur = currencyByCode('EUR');
      expect(eur.format(20, showSign: true), '+20,00 €');
      expect(eur.format(-20, showSign: true), '-20,00 €');
      expect(eur.format(-20), '-20,00 €');
      expect(eur.format(0, showSign: true), '0,00 €');
      expect(eur.format(-0.001, showSign: true), '0,00 €', reason: 'pas de « -0,00 »');
      expect(eur.format(1234.567, decimals: 0), '1${_nnbsp}235 €');
      expect(currencyByCode('XAF').format(-4500, showSign: true), '-4${_nnbsp}500 FCFA');
    });

    test('unknown or missing codes fall back to the euro', () {
      expect(currencyByCode(null).code, 'EUR');
      expect(currencyByCode('???').code, 'EUR');
      expect(currencyByCode('XOF').name, contains('BCEAO'));
    });

    test('currency list matches what the server accepts, without duplicates', () {
      const serverCodes = [
        'EUR', 'XOF', 'XAF', 'USD', 'GBP', 'CHF', 'CAD', 'MAD', 'TND', 'DZD', 'NGN', 'GHS', 'GNF', 'CDF',
      ];
      expect(kCurrencies.map((c) => c.code).toList(), serverCodes);
    });

    test('AuthUser keeps the currency and defaults to euro', () {
      expect(AuthUser.fromJson({'id': 1, 'username': 'u'}).currency, 'EUR');
      final u = AuthUser.fromJson({'id': 1, 'username': 'u', 'currency': 'XOF'});
      expect(AuthUser.fromJson(u.toJson()).currency, 'XOF');
      expect(u.copyWith(currency: 'USD').currency, 'USD');
      expect(u.copyWith(currency: 'USD').username, 'u');
    });
  });

  group('SettingsScreen', () {
    testWidgets('lists the currencies and marks the current one', (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = await _auth(tester);
      await tester.pumpWidget(_app(auth, const SettingsScreen()));

      expect(find.text('Paramètres'), findsOneWidget);
      expect(find.text('Devise'), findsOneWidget);
      expect(find.text('Euro'), findsOneWidget);
      expect(find.text('Franc CFA (BCEAO)'), findsOneWidget);
      expect(find.text('Dollar américain'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('currency-preview'))).data,
        '+45${_nnbsp}000,00 €',
      );
    });

    testWidgets('choosing a currency updates the account and every amount', (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = await _auth(tester);
      final bodies = <String>[];
      final client = MockClient((req) async {
        bodies.add('${req.method} ${req.url.path} ${req.body}');
        return _json({'success': true, 'data': {'id': 7, 'username': 'u', 'currency': 'XOF'}});
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(_app(auth, const SettingsScreen()));
        await tester.tap(find.byKey(const ValueKey('currency-XOF')));
        await tester.pumpAndSettle();
      }, () => client);

      expect(bodies, hasLength(1));
      expect(bodies.single, startsWith('PATCH /api/auth/users/me/'));
      expect(jsonDecode(bodies.single.split(' ').skip(2).join(' ')), {'currency': 'XOF'});
      expect(auth.currency.code, 'XOF');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('currency-preview'))).data,
        '+45${_nnbsp}000 FCFA',
      );
      // la devise est aussi mémorisée localement (reprise au prochain lancement)
      final saved = jsonDecode((await SharedPreferences.getInstance()).getString('user_data')!);
      expect(saved['currency'], 'XOF');
    });

    testWidgets('a failed save restores the previous currency and says so', (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = await _auth(tester, currency: 'USD');
      final client = MockClient((_) async => _json({
            'success': false,
            'message': {'default': 'Erreur de validation'},
            'errors': {'currency': ['Devise non prise en charge.']},
          }, 400));

      await http.runWithClient(() async {
        await tester.pumpWidget(_app(auth, const SettingsScreen()));
        await tester.tap(find.byKey(const ValueKey('currency-GBP')));
        await tester.pumpAndSettle();
      }, () => client);

      expect(auth.currency.code, 'USD');
      expect(find.text('Devise non prise en charge.'), findsOneWidget);
    });

    testWidgets('an unreachable server also rolls back', (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = await _auth(tester);
      final client = MockClient((_) async => throw http.ClientException('offline'));

      await http.runWithClient(() async {
        await tester.pumpWidget(_app(auth, const SettingsScreen()));
        await tester.tap(find.byKey(const ValueKey('currency-XOF')));
        await tester.pumpAndSettle();
      }, () => client);

      expect(auth.currency.code, 'EUR');
      expect(find.textContaining("n'a pas été modifiée"), findsOneWidget);
    });
  });

  group('integration', () {
    testWidgets('profile has a settings button that opens the settings page', (tester) async {
      final auth = await _auth(tester);
      await tester.pumpWidget(_app(auth, const ProfileScreen(), rabbits: RabbitProvider()..seedForTesting()));
      await tester.pump();

      await tester.tap(find.byTooltip('Paramètres'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Devise'), findsOneWidget);
    });

    testWidgets('finances show amounts in the account currency', (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<void> open(String? currency) async {
        final auth = await _auth(tester, currency: currency);
        await tester.pumpWidget(_app(auth, const FinancesScreen(), rabbits: RabbitProvider()..seedForTesting()));
        await tester.pumpAndSettle();
      }

      await open(null);
      expect(find.textContaining('€'), findsWidgets);
      expect(find.textContaining('FCFA'), findsNothing);

      await open('XOF');
      expect(find.textContaining('FCFA'), findsWidgets);
      expect(find.textContaining('€'), findsNothing);
    });
  });
}
