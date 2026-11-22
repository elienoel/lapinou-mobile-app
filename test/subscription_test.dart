import 'dart:convert';

import 'package:clap_in/models/subscription.dart';
import 'package:clap_in/providers/auth_provider.dart';
import 'package:clap_in/providers/rabbit_provider.dart';
import 'package:clap_in/providers/subscription_provider.dart';
import 'package:clap_in/screens/subscription_screen.dart';
import 'package:clap_in/services/breeding_notifications.dart';
import 'package:clap_in/widgets/plan_limit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SubscriptionStatus _status({String plan = 'free', int? limit = 4, int count = 4, DateTime? end}) =>
    SubscriptionStatus(
      plan: plan,
      planName: {'free': 'Gratuit', 'breeder': 'Éleveur', 'pro': 'Pro'}[plan]!,
      limit: limit,
      rabbitCount: count,
      periodEnd: end,
      daysLeft: end == null ? 0 : end.difference(DateTime.now()).inDays,
      requiredPlan: 'free',
    );

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR', null));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('model', () {
    test('limits and plan ranges', () {
      final free = _status();
      expect(free.canAdd(3), isTrue);
      expect(free.canAdd(4), isFalse);
      expect(free.canAdd(2, 3), isFalse);
      expect(_status(plan: 'pro', limit: null).canAdd(500, 10), isTrue);
      expect(free.planFor(5).code, 'breeder');
      expect(free.planFor(11).code, 'pro');
      const all = PlanOffer.defaults;
      expect(all.map((p) => p.rangeLabel(all)), ["Jusqu'à 4 lapins", 'De 5 à 10 lapins', 'Plus de 10 lapins']);
      expect(formatFcfa(1200), '1 200 F');
    });

    test('parses the server status', () {
      final s = SubscriptionStatus.fromJson({
        'plan': 'breeder', 'plan_name': 'Éleveur', 'limit': 10, 'rabbit_count': 7,
        'current_period_end': '2026-12-21T10:00:00Z', 'days_left': 30, 'required_plan': 'breeder',
        'plans': [
          {'code': 'free', 'name': 'Gratuit', 'price': 0, 'max_rabbits': 4},
          {'code': 'breeder', 'name': 'Éleveur', 'price': 1200, 'max_rabbits': 10},
          {'code': 'pro', 'name': 'Pro', 'price': 2500, 'max_rabbits': null},
        ],
      });
      expect((s.isPaid, s.limit, s.rabbitCount, s.plans.last.maxRabbits), (true, 10, 7, null));
      expect(s.periodEnd!.toUtc(), DateTime.utc(2026, 12, 21, 10));
    });

    test('expiry reminders 3 days before and on the day', () {
      final end = DateTime.now().add(const Duration(days: 10));
      final reminders = subscriptionNotifications(_status(plan: 'breeder', limit: 10, end: end));
      expect(reminders.map((r) => r.day.difference(DateTime(end.year, end.month, end.day)).inDays), [-3, 0]);
      expect(subscriptionNotifications(_status()), isEmpty);
    });
  });

  Future<(RabbitProvider, SubscriptionProvider)> pump(
    WidgetTester tester,
    Widget home, {
    SubscriptionStatus? status,
    http.Client? client,
  }) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final rabbits = RabbitProvider()..seedForTesting();
    final subs = SubscriptionProvider(client: client)..setToken('tok');
    if (status != null) subs.setStatusForTesting(status);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: rabbits),
        ChangeNotifierProvider.value(value: subs),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(home: home),
    ));
    await tester.pumpAndSettle();
    return (rabbits, subs);
  }

  Widget guardButton(int adding, List<bool> results) => Scaffold(
    body: Builder(
      builder: (context) => ElevatedButton(
        key: const ValueKey('try-add'),
        onPressed: () async => results.add(await guardRabbitQuota(context, adding)),
        child: const Text('Ajouter'),
      ),
    ),
  );

  testWidgets('the guard blocks additions beyond the plan and explains why', (tester) async {
    final results = <bool>[];
    final (rabbits, _) = await pump(tester, guardButton(1, results), status: _status(count: 0));
    final count = rabbits.rabbits.length;
    expect(count, greaterThanOrEqualTo(4), reason: 'données de démonstration');

    await tester.tap(find.byKey(const ValueKey('try-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-limit-title')), findsOneWidget);
    expect(find.textContaining('formule Gratuit permet 4 lapins et vous en avez $count'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('the guard lets additions through with room or an unknown plan', (tester) async {
    final results = <bool>[];
    await pump(tester, guardButton(2, results), status: _status(plan: 'pro', limit: null));
    await tester.tap(find.byKey(const ValueKey('try-add')));
    await tester.pumpAndSettle();
    await pump(tester, guardButton(2, results));
    await tester.tap(find.byKey(const ValueKey('try-add')));
    await tester.pumpAndSettle();
    expect(results, [true, true]);
  });

  testWidgets('the subscription screen lists the three plans and pays through GeniusPay', (tester) async {
    final opened = <Uri>[];
    openPaymentPage = (url) async {
      opened.add(url);
      return true;
    };
    final requests = <String>[];
    var completed = false;
    final client = MockClient((req) async {
      requests.add('${req.method} ${req.url.path} ${req.body}');
      if (req.url.path.endsWith('/status/')) {
        return _json({'success': true, 'data': _status(count: 6).toJson()..['required_plan'] = 'breeder'}, 200);
      }
      if (req.url.path.endsWith('/checkout/')) {
        return _json({
          'success': true,
          'data': {'reference': 'MTX-1', 'checkout_url': 'https://pay.genius.ci/checkout/MTX-1', 'status': 'pending'},
        }, 201);
      }
      completed = true;
      return _json({
        'success': true,
        'data': {
          'payment': {'reference': 'MTX-1', 'status': 'completed'},
          'subscription': _status(plan: 'breeder', limit: 10, count: 6,
              end: DateTime.now().add(const Duration(days: 30))).toJson(),
        },
      }, 200);
    });

    await pump(tester, const SubscriptionScreen(), client: client);
    expect(find.byKey(const ValueKey('plan-free')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-breeder')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-pro')), findsOneWidget);
    expect(find.text('6 lapins sur 4 autorisés'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('plan-breeder')), matching: find.text('Recommandée')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pay-breeder')));
    await tester.pumpAndSettle();
    expect(requests.last, contains('"plan":"breeder"'));
    expect(opened.single.toString(), 'https://pay.genius.ci/checkout/MTX-1');

    // retour dans l'app après paiement
    await tester.tap(find.byKey(const ValueKey('subscription-check-payment')));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(requests.last, contains('/subscriptions/payments/MTX-1/refresh/'));
    expect(find.textContaining('Abonnement activé jusqu’au'), findsOneWidget);
    expect(find.text('6 lapins sur 10 autorisés'), findsOneWidget);
  });

  testWidgets('a checkout error is shown to the breeder', (tester) async {
    final client = MockClient((req) async {
      if (req.method == 'GET') return _json({'success': true, 'data': _status(count: 2).toJson()}, 200);
      return _json({
        'success': false,
        'message': {'default': 'Paiement indisponible', 'details': 'Le service de paiement ne répond pas, réessayez dans un instant.'},
      }, 502);
    });
    await pump(tester, const SubscriptionScreen(), client: client);
    await tester.tap(find.byKey(const ValueKey('pay-pro')));
    await tester.pumpAndSettle();
    expect(find.text('Le service de paiement ne répond pas, réessayez dans un instant.'), findsOneWidget);
  });
}
