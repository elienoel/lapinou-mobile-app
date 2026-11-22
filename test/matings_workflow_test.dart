import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clap_in/services/connectivity_service.dart';
import 'package:clap_in/models/mating.dart';
import 'package:clap_in/providers/auth_provider.dart';
import 'package:clap_in/providers/breeding_settings_provider.dart';
import 'package:clap_in/providers/rabbit_provider.dart';
import 'package:clap_in/models/litter.dart';
import 'package:clap_in/screens/mating_detail_screen.dart';
import 'package:clap_in/screens/matings_screen.dart';
import 'package:clap_in/widgets/litter_form.dart';

DateTime _daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

Mating _mating(int daysAgo, {MatingStatus status = MatingStatus.pending}) =>
    Mating(id: 'm', maleId: 'a', femaleId: 'b', matingDate: _daysAgo(daysAgo), status: status);

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Fausse API : palpation et annulation renvoient l'accouplement mis à jour.
class _Api {
  final requests = <String>[];
  int? failWith;

  MockClient client() => MockClient((req) async {
        requests.add('${req.method} ${req.url.path} ${req.body}');
        final headers = {'content-type': 'application/json; charset=utf-8'};
        if (failWith != null && req.method == 'POST') {
          return http.Response(
            jsonEncode({'success': false, 'errors': {'status': ["Cette saillie n'est plus en attente de palpation."]}}),
            failWith!,
            headers: headers,
          );
        }
        if (req.method == 'POST' && req.url.path.contains('/matings/')) {
          final id = req.url.pathSegments[req.url.pathSegments.length - 3];
          final step = req.url.pathSegments[req.url.pathSegments.length - 2];
          final today = _iso(DateTime.now());
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': id,
                'male': 'p-m-2',
                'female': 'p-f-2',
                'mating_date': _iso(_daysAgo(8)),
                'status': switch (step) {
                  'palpation' || 'nest-box' => 'confirmed',
                  'complete' => 'completed',
                  _ => 'failed',
                },
                'palpation_done_at': step == 'palpation' ? today : null,
                'nest_box_done_at': step == 'nest-box' ? today : null,
              },
            }),
            200,
            headers: headers,
          );
        }
        return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: headers);
      });

  String last(String method) => requests.lastWhere((r) => r.startsWith(method), orElse: () => '');
  Map<String, dynamic> body(String request) =>
      jsonDecode(request.substring(request.indexOf('{'))) as Map<String, dynamic>;
}

Future<RabbitProvider> _pump(
  WidgetTester tester, {
  Widget home = const MatingsScreen(),
  void Function(RabbitProvider)? setUp,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Seed : mat-1 (Bella x Flash, saillie il y a 29 j, gestation confirmée)
  //        mat-2 (Luna x Goliath, saillie il y a 8 j, en attente de palpation)
  //        lit-1 (portée de Luna enregistrée sans accouplement, 18 j)
  final provider = RabbitProvider()..seedForTesting();
  provider.setTokenForTesting('tok');
  setUp?.call(provider);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<RabbitProvider>.value(value: provider),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => BreedingSettingsProvider()),
    ],
    child: MaterialApp(home: home),
  ));
  await tester.pumpAndSettle();
  return provider;
}

Future<RabbitProvider> _detail(WidgetTester tester, String matingId,
        {void Function(RabbitProvider)? setUp}) =>
    _pump(tester, home: MatingDetailScreen(matingId: matingId), setUp: setUp);

void main() {
  setUpAll(() async {
    ConnectivityService.instance.debugOnlineOverride = true;
    await initializeDateFormatting('fr_FR', null);
  });

  group('21-day rule (model)', () {
    test('kindling is only possible from 21 days after the mating', () {
      expect(_mating(20).canRegisterKindling, isFalse);
      expect(_mating(21).canRegisterKindling, isTrue);
      expect(_mating(35).canRegisterKindling, isTrue);
      expect(_mating(0).canRegisterKindling, isFalse);
    });

    test('only running matings can register a kindling', () {
      expect(_mating(30, status: MatingStatus.confirmed).canRegisterKindling, isTrue);
      expect(_mating(30, status: MatingStatus.kindled).canRegisterKindling, isFalse);
      expect(_mating(30, status: MatingStatus.failed).canRegisterKindling, isFalse);
      expect(_mating(30, status: MatingStatus.completed).canRegisterKindling, isFalse);
    });

    test('earliest kindling date, palpation state and palpation date parsing', () {
      final m = _mating(5);
      final d = DateTime.now();
      expect(m.earliestKindlingDate, DateTime(d.year, d.month, d.day - 5 + 21));
      expect(m.daysSinceMating, 5);
      expect(m.palpationDone, isFalse);
      expect(_mating(5, status: MatingStatus.confirmed).palpationDone, isTrue);

      final parsed = Mating.fromJson({
        'id': 1, 'male': 2, 'female': 3, 'mating_date': '2026-09-01',
        'status': 'confirmed', 'palpation_done_at': '2026-09-14',
      });
      expect(parsed.palpationDoneAt, DateTime(2026, 9, 14));
      expect(parsed.palpationDone, isTrue);
      expect(parsed.copyWith(notes: 'x').palpationDoneAt, DateTime(2026, 9, 14));

      final done = Mating.fromJson({
        'id': 1, 'male': 2, 'female': 3, 'mating_date': '2026-09-01',
        'status': 'completed', 'nest_box_done_at': '2026-09-28',
      });
      expect(done.status, MatingStatus.completed);
      expect(done.nestBoxDoneAt, DateTime(2026, 9, 28));
      expect(done.isOngoing, isFalse);
      expect(_mating(5).isOngoing, isTrue);
      expect(_mating(40, status: MatingStatus.kindled).isOngoing, isTrue);
    });
  });

  group('single list', () {
    testWidgets('one page without tabs: matings and litters together', (tester) async {
      await _pump(tester);
      expect(find.text('Accouplements & Mises bas'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Nouvel accouplement'), findsOneWidget);
      expect(find.byKey(const ValueKey('mating-mat-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('mating-mat-2')), findsOneWidget);
      // ancienne portée sans accouplement : dans la même liste
      expect(find.byKey(const ValueKey('litter-lit-1')), findsOneWidget);
      expect(find.text('En cours (3)'), findsOneWidget);
      expect(find.text('Terminés (0)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mating-filter-finished')));
      await tester.pumpAndSettle();
      expect(find.text('Aucun accouplement terminé.'), findsOneWidget);
    });

    testWidgets('a card is a summary: names, date and countdown to kindling', (tester) async {
      await _pump(tester);
      final card = find.byKey(const ValueKey('mating-mat-2'));
      expect(find.descendant(of: card, matching: find.text('Saillie le ${_fmt(_daysAgo(8))}')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('J-23')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('mating-mat-1')), matching: find.text('J-2')), findsOneWidget);
      // les actions sont dans le détail, pas sur la carte
      expect(find.byKey(const ValueKey('palpation-positive-mat-2')), findsNothing);
      expect(find.byKey(const ValueKey('kindle-mat-2')), findsNothing);
    });

    testWidgets('tapping a card opens its steps', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('mating-mat-2')));
      await tester.pumpAndSettle();
      expect(find.byType(MatingDetailScreen), findsOneWidget);
      expect(find.text('Étapes'), findsOneWidget);
      for (final step in ['Saillie', 'Palpation', 'Pose de la boîte à nid', 'Mise bas', 'Sevrage', 'Réussi']) {
        expect(find.text(step), findsOneWidget, reason: step);
      }
    });
  });

  group('steps in the detail', () {
    testWidgets('kindling is greyed out under 21 days, with the reason', (tester) async {
      await _detail(tester, 'mat-2');
      final early = tester.widget<FilledButton>(find.byKey(const ValueKey('kindle-mat-2')));
      expect(early.onPressed, isNull);
      final earliest = _daysAgo(8).add(const Duration(days: 21));
      expect(
        find.text('Possible à partir du ${_fmt(earliest)} (21 jours après la saillie).'),
        findsOneWidget,
      );
    });

    testWidgets('kindling is possible from 21 days and opens the form on that mating', (tester) async {
      await _detail(tester, 'mat-1');
      expect(find.byKey(const ValueKey('kindle-hint-mat-1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kindle-mat-1')));
      await tester.pumpAndSettle();
      expect(find.text('Enregistrer une Mise Bas'), findsOneWidget);
      expect(find.byKey(const ValueKey('litter-mating-dropdown')), findsNothing, reason: 'accouplement imposé');
      expect(find.textContaining('Mère : Bella'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('litter-submit'))).onPressed, isNotNull);
    });

    testWidgets('palpation: positive or negative only while it is pending', (tester) async {
      await _detail(tester, 'mat-2');
      expect(find.byKey(const ValueKey('palpation-positive-mat-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('palpation-negative-mat-2')), findsOneWidget);
    });

    testWidgets('a positive palpation records it and confirms the pregnancy', (tester) async {
      final api = _Api();
      final provider = await _detail(tester, 'mat-2');
      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('palpation-positive-mat-2')));
        await tester.pumpAndSettle();
        expect(find.text(_fmt(DateTime.now())), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('palpation-confirm')));
        await tester.pumpAndSettle();
      }, api.client);

      final post = api.last('POST');
      expect(post, contains('/matings/mat-2/palpation/'));
      expect(api.body(post)['done_at'], _iso(DateTime.now()));
      expect(provider.getMatingById('mat-2')!.status, MatingStatus.confirmed);
      expect(find.text('Palpation enregistrée : gestation confirmée'), findsOneWidget);
      expect(find.byKey(const ValueKey('palpation-positive-mat-2')), findsNothing, reason: 'étape faite');
      expect(find.textContaining('Positive · le'), findsOneWidget);
    });

    testWidgets('a refused palpation shows the server message', (tester) async {
      final api = _Api()..failWith = 400;
      await _detail(tester, 'mat-2');
      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('palpation-positive-mat-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('palpation-confirm')));
        await tester.pumpAndSettle();
      }, api.client);
      expect(find.text("Cette saillie n'est plus en attente de palpation."), findsOneWidget);
      expect(find.byKey(const ValueKey('palpation-positive-mat-2')), findsOneWidget);
    });

    testWidgets('a negative palpation marks the mating as not successful', (tester) async {
      final api = _Api();
      final provider = await _detail(tester, 'mat-2');
      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('palpation-negative-mat-2')));
        await tester.pumpAndSettle();
        expect(find.text("Déclarer l'échec ?"), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('cancel-confirm')));
        await tester.pumpAndSettle();
      }, api.client);

      final post = api.last('POST');
      expect(post, contains('/matings/mat-2/cancel/'));
      expect(api.body(post), {'reason': 'Palpation négative'});
      expect(provider.getMatingById('mat-2')!.status, MatingStatus.failed);
      expect(find.text('Non réussi'), findsOneWidget);
      expect(find.byKey(const ValueKey('kindle-mat-2')), findsNothing, reason: 'plus d\'actions une fois échoué');
    });

    testWidgets('going back from the failure dialog changes nothing', (tester) async {
      final api = _Api();
      final provider = await _detail(tester, 'mat-2');
      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('palpation-negative-mat-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retour'));
        await tester.pumpAndSettle();
      }, api.client);
      expect(api.requests.where((r) => r.startsWith('POST')), isEmpty);
      expect(provider.getMatingById('mat-2')!.status, MatingStatus.pending);
    });

    testWidgets('the nest box is recorded with its date', (tester) async {
      final api = _Api();
      final provider = await _detail(tester, 'mat-1');
      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('nestbox-mat-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }, api.client);
      final post = api.last('POST');
      expect(post, contains('/matings/mat-1/nest-box/'));
      expect(api.body(post)['done_at'], _iso(DateTime.now()));
      expect(provider.getMatingById('mat-1')!.nestBoxDone, isTrue);
      expect(find.byKey(const ValueKey('nestbox-mat-1')), findsNothing);
      expect(find.textContaining('Posée le'), findsOneWidget);
    });

    testWidgets('once the litter is weaned, the mating can be marked successful', (tester) async {
      final api = _Api();
      final provider = await _detail(tester, 'mat-1', setUp: (p) {
        final m = p.getMatingById('mat-1')!;
        p.setMatingsForTesting([
          m.copyWith(status: MatingStatus.kindled),
          p.getMatingById('mat-2')!,
        ]);
        p.setLittersForTesting([
          Litter(
            id: 'lit-9',
            matingId: 'mat-1',
            motherId: m.femaleId,
            fatherId: m.maleId,
            birthDate: _daysAgo(50),
            bornAlive: 4,
            weanedCount: 4,
            weanedAt: _daysAgo(2),
          ),
        ]);
      });
      // mise bas et sevrage faits : les étapes en tiennent compte
      expect(find.byKey(const ValueKey('wean-lit-9')), findsNothing);
      expect(find.textContaining('Sevrage terminé le'), findsOneWidget);

      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('complete-mat-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Marquer comme réussi').last);
        await tester.pumpAndSettle();
      }, api.client);
      expect(api.last('POST'), contains('/matings/mat-1/complete/'));
      expect(provider.getMatingById('mat-1')!.status, MatingStatus.completed);
      expect(find.text('Accouplement terminé avec succès'), findsOneWidget);
    });

    testWidgets('the menu offers edit, failure and delete', (tester) async {
      await _detail(tester, 'mat-2');
      // Police de test très large : le formulaire d'édition a besoin de plus de largeur
      tester.view.physicalSize = const Size(1800, 3200);
      await tester.tap(find.byKey(const ValueKey('mating-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Déclarer un échec'), findsOneWidget);
      expect(find.text('Supprimer'), findsOneWidget);

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      expect(find.text("Modifier l'accouplement"), findsOneWidget);
      expect(find.text('Date de la saillie / accouplement'), findsOneWidget);
      expect(find.text('Statut'), findsNothing, reason: 'le statut suit les étapes');
    });
  });

  group('litter form checks the dates', () {
    Future<RabbitProvider> openForm(WidgetTester tester, {Mating? mating}) async {
      final provider = await _pump(tester);
      // sans accouplement imposé, le formulaire propose la liste des accouplements
      final ctx = tester.element(find.byType(Scaffold).first);
      showLitterForm(ctx, provider, mating: mating);
      await tester.pumpAndSettle();
      return provider;
    }

    testWidgets('without a given mating, the too-early mating is greyed out in the list and not selected', (tester) async {
      await openForm(tester);
      // mat-1 (29 j) est présélectionné, mat-2 (8 j) est grisé dans la liste
      expect(find.byKey(const ValueKey('litter-too-early')), findsNothing);
      expect(find.byKey(const ValueKey('litter-birth-date')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('litter-mating-dropdown')));
      await tester.pumpAndSettle();
      final earliest = _daysAgo(8).add(const Duration(days: 21));
      final greyed = find.textContaining('(dès le ${earliest.day.toString().padLeft(2, '0')}/${earliest.month.toString().padLeft(2, '0')})');
      expect(greyed, findsOneWidget);
      // toucher l'entrée grisée ne change pas la sélection
      await tester.tap(greyed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('litter-too-early')), findsNothing);
    });

    testWidgets('a mating under 21 days blocks the form with an explanation', (tester) async {
      await openForm(tester, mating: _mating(10));
      final earliest = _daysAgo(10).add(const Duration(days: 21));
      expect(find.byKey(const ValueKey('litter-too-early')), findsOneWidget);
      expect(find.textContaining('à partir du ${_fmt(earliest)}'), findsOneWidget);
      expect(find.byKey(const ValueKey('litter-birth-date')), findsNothing);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('litter-submit'))).onPressed, isNull);
    });

    testWidgets('exactly 21 days after the mating the form is usable and starts at today', (tester) async {
      await openForm(tester, mating: _mating(21));
      expect(find.byKey(const ValueKey('litter-too-early')), findsNothing);
      expect(find.text(_fmt(DateTime.now())), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('litter-submit'))).onPressed, isNotNull);
    });
  });
}
