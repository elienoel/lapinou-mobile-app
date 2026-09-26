import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/models/finance_period.dart';
import 'package:lapinou/models/finance_transaction.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/screens/finances_screen.dart';

FinanceTransaction _tx(
  String id,
  String title,
  double amount,
  DateTime date, {
  bool income = true,
}) => FinanceTransaction(
  id: id,
  type: income ? TransactionType.income : TransactionType.expense,
  title: title,
  amount: amount,
  date: date,
  category: 'Test',
);

Future<RabbitProvider> _pump(
  WidgetTester tester,
  List<FinanceTransaction> finances,
) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(420, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final provider = RabbitProvider()..setFinancesForTesting(finances);
  provider.setTokenForTesting('tok');
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RabbitProvider>.value(value: provider),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MaterialApp(home: FinancesScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('FinancePeriod', () {
    final now = DateTime(2026, 9, 26, 15, 30);

    test('predefined periods have inclusive day bounds', () {
      final month = const FinancePeriod(FinancePeriodKind.thisMonth).range(now)!;
      expect((month.start, month.end), (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));

      final last = const FinancePeriod(FinancePeriodKind.lastMonth).range(now)!;
      expect((last.start, last.end), (DateTime(2026, 8, 1), DateTime(2026, 8, 31)));

      final year = const FinancePeriod(FinancePeriodKind.thisYear).range(now)!;
      expect((year.start, year.end), (DateTime(2026, 1, 1), DateTime(2026, 12, 31)));

      expect(FinancePeriod.all.range(now), isNull);
    });

    test('last month wraps over the new year', () {
      final january = DateTime(2026, 1, 10);
      final last = const FinancePeriod(FinancePeriodKind.lastMonth).range(january)!;
      expect((last.start, last.end), (DateTime(2025, 12, 1), DateTime(2025, 12, 31)));
    });

    test('contains ignores the time of day and includes both bounds', () {
      const month = FinancePeriod(FinancePeriodKind.thisMonth);
      expect(month.contains(DateTime(2026, 9, 1, 0, 0), now), isTrue);
      expect(month.contains(DateTime(2026, 9, 30, 23, 59), now), isTrue);
      expect(month.contains(DateTime(2026, 8, 31, 23, 59), now), isFalse);
      expect(month.contains(DateTime(2026, 10, 1), now), isFalse);
      expect(FinancePeriod.all.contains(DateTime(1999, 1, 1), now), isTrue);
    });

    test('a custom range is normalised to whole days', () {
      final p = FinancePeriod.custom(
        DateTimeRange(start: DateTime(2026, 3, 5, 18), end: DateTime(2026, 3, 9, 7)),
      );
      expect(p.contains(DateTime(2026, 3, 5, 0, 1), now), isTrue);
      expect(p.contains(DateTime(2026, 3, 9, 23, 0), now), isTrue);
      expect(p.contains(DateTime(2026, 3, 10), now), isFalse);
      expect(p.describe(), 'Du 05/03/2026 au 09/03/2026');
    });

    test('totals split income and expenses', () {
      final t = FinanceTotals.of([
        _tx('1', 'a', 1000, now),
        _tx('2', 'b', 250, now, income: false),
        _tx('3', 'c', 500, now),
      ]);
      expect((t.income, t.expense, t.balance), (1500, 250, 1250));
      expect((t.incomeCount, t.expenseCount), (2, 1));
    });
  });

  group('Finances screen', () {
    final today = DateTime.now();
    final lastMonthDay = DateTime(today.year, today.month - 1, 15);
    final longAgo = DateTime(today.year - 2, 6, 1);

    testWidgets('the period drives the list, the counters and the banner', (
      tester,
    ) async {
      await _pump(tester, [
        _tx('1', 'Vente du jour', 1000, today),
        _tx('2', 'Granulés du mois dernier', 300, lastMonthDay, income: false),
        _tx('3', 'Vente ancienne', 500, longAgo),
      ]);

      // Tout : trois transactions, aucune période
      expect(find.text('Vente du jour'), findsOneWidget);
      expect(find.text('Granulés du mois dernier'), findsOneWidget);
      expect(find.text('Vente ancienne'), findsOneWidget);
      expect(find.text('Depuis le début'), findsOneWidget);
      expect(find.text('💰 Ventes (2)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('period-thisMonth')));
      await tester.pumpAndSettle();
      expect(find.text('Vente du jour'), findsOneWidget);
      expect(find.text('Granulés du mois dernier'), findsNothing);
      expect(find.text('Vente ancienne'), findsNothing);
      expect(find.text('💰 Ventes (1)'), findsOneWidget);
      expect(find.text('📦 Dépenses (0)'), findsOneWidget);
      expect(find.text('BILAN · CE MOIS'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('period-lastMonth')));
      await tester.pumpAndSettle();
      expect(find.text('Granulés du mois dernier'), findsOneWidget);
      expect(find.text('Vente du jour'), findsNothing);
      expect(find.text('📦 Dépenses (1)'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('period-all')));
      await tester.pumpAndSettle();
      expect(find.text('Vente ancienne'), findsOneWidget);
    });

    testWidgets('an empty period says so', (tester) async {
      await _pump(tester, [_tx('3', 'Vente ancienne', 500, longAgo)]);
      await tester.tap(find.byKey(const ValueKey('period-thisMonth')));
      await tester.pumpAndSettle();
      expect(find.text('Aucune transaction sur cette période.'), findsOneWidget);
    });

    testWidgets('a custom period is chosen with the date range picker', (
      tester,
    ) async {
      await _pump(tester, [
        _tx('1', 'Vente du jour', 1000, today),
        _tx('3', 'Vente ancienne', 500, longAgo),
      ]);
      // la puce est à droite, dans la barre défilante
      await tester.ensureVisible(find.byKey(const ValueKey('period-custom')));
      await tester.tap(find.byKey(const ValueKey('period-custom')));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      // La plage proposée est « ce mois » : on valide telle quelle
      await tester.tap(find.text('Appliquer'));
      await tester.pumpAndSettle();
      expect(find.text('Vente du jour'), findsOneWidget);
      expect(find.text('Vente ancienne'), findsNothing);
      expect(find.text('BILAN · PERSONNALISÉ'), findsOneWidget);
    });

    testWidgets('the form has a date that defaults to today', (tester) async {
      final requests = <String>[];
      final client = MockClient((req) async {
        requests.add('${req.method} ${req.url.path} ${req.body}');
        return http.Response(
          jsonEncode({'success': true, 'data': {}}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        await _pump(tester, []);
        await tester.tap(find.text('Enregistrer Vente'));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const ValueKey('tx-date')),
            matching: find.text(DateFormat('dd/MM/yyyy').format(today)),
          ),
          findsOneWidget,
        );

        await tester.enterText(find.widgetWithText(TextField, 'Intitulé *'), 'Vente lapin');
        await tester.enterText(find.byType(TextField).at(1), '5000');
        await tester.tap(find.text('Valider la Vente (+)'));
        await tester.pumpAndSettle();
      }, () => client);

      final post = requests.lastWhere((r) => r.startsWith('POST'));
      final body = jsonDecode(post.substring(post.indexOf('{'))) as Map;
      expect(body['date'], DateFormat('yyyy-MM-dd').format(today));
      expect(body['title'], 'Vente lapin');
    });

    testWidgets('the date of a transaction can be set in the past', (tester) async {
      final requests = <String>[];
      final client = MockClient((req) async {
        requests.add('${req.method} ${req.url.path} ${req.body}');
        return http.Response(
          jsonEncode({'success': true, 'data': {}}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await http.runWithClient(() async {
        await _pump(tester, []);
        await tester.tap(find.text('Ajouter Dépense'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('tx-date')));
        await tester.pumpAndSettle();
        // Sélecteur de date : on choisit le 1er du mois (toujours dans le passé ou aujourd'hui)
        await tester.tap(find.text('1').first);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.enterText(find.widgetWithText(TextField, 'Intitulé *'), 'Paille');
        await tester.enterText(find.byType(TextField).at(1), '2000');
        await tester.tap(find.text('Valider la Dépense (-)'));
        await tester.pumpAndSettle();
      }, () => client);

      final post = requests.lastWhere((r) => r.startsWith('POST'));
      final body = jsonDecode(post.substring(post.indexOf('{'))) as Map;
      expect(body['date'], '${DateFormat('yyyy-MM').format(today)}-01');
    });
  });
}
