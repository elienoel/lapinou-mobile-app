import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/models/mating.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/screens/matings_screen.dart';
import 'package:lapinou/widgets/litter_form.dart';

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
          final palpation = req.url.path.endsWith('/palpation/');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': id,
                'male': 'p-m-2',
                'female': 'p-f-2',
                'mating_date': _iso(_daysAgo(8)),
                'status': palpation ? 'confirmed' : 'failed',
                'palpation_done_at': palpation ? _iso(DateTime.now()) : null,
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

Future<RabbitProvider> _pump(WidgetTester tester, {int initialTab = 0}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // Seed : mat-1 (Bella x Flash, saillie il y a 29 j, gestation confirmée)
  //        mat-2 (Luna x Goliath, saillie il y a 8 j, en attente de palpation)
  final provider = RabbitProvider()..seedForTesting();
  provider.setTokenForTesting('tok');
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<RabbitProvider>.value(value: provider),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
    ],
    child: MaterialApp(home: MatingsScreen(initialTab: initialTab)),
  ));
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  setUpAll(() async {
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
    });
  });

  group('combined page', () {
    testWidgets('one page, two tabs with counts', (tester) async {
      await _pump(tester);
      expect(find.text('Accouplements & Mises bas'), findsOneWidget);
      expect(find.text('Accouplements (2)'), findsOneWidget);
      expect(find.text('Mises bas (1)'), findsOneWidget);
      expect(find.text('Nouvel Accouplement'), findsOneWidget);
      expect(find.byKey(const ValueKey('mating-mat-1')), findsOneWidget);

      await tester.tap(find.text('Mises bas (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Enregistrer Mise Bas'), findsOneWidget, reason: 'le bouton suit l\'onglet');
      expect(find.text('LAPEREAUX AU NID'), findsOneWidget);
      expect(find.byKey(const ValueKey('litter-lit-1')), findsOneWidget);
    });

    testWidgets('can open directly on the litters tab', (tester) async {
      await _pump(tester, initialTab: 1);
      expect(find.text('LAPEREAUX AU NID'), findsOneWidget);
    });

    testWidgets('running and finished matings are filtered', (tester) async {
      await _pump(tester);
      expect(find.text('En cours (2)'), findsOneWidget);
      expect(find.text('Terminés (0)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mating-filter-finished')));
      await tester.pumpAndSettle();
      expect(find.text('Aucun accouplement terminé.'), findsOneWidget);
    });
  });

  group('mating card options', () {
    testWidgets('kindling is greyed out under 21 days, with the reason', (tester) async {
      await _pump(tester);

      // mat-2 : saillie il y a 8 jours
      final early = tester.widget<FilledButton>(find.byKey(const ValueKey('kindle-mat-2')));
      expect(early.onPressed, isNull);
      final earliest = _daysAgo(8).add(const Duration(days: 21));
      expect(
        find.text('Mise bas possible à partir du ${_fmt(earliest)} (21 jours après la saillie).'),
        findsOneWidget,
      );

      // mat-1 : saillie il y a 29 jours
      final ready = tester.widget<FilledButton>(find.byKey(const ValueKey('kindle-mat-1')));
      expect(ready.onPressed, isNotNull);
      expect(find.byKey(const ValueKey('kindle-hint-mat-1')), findsNothing);
    });

    testWidgets('the palpation button only shows until the palpation is done', (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('palpation-mat-2')), findsOneWidget); // en attente
      expect(find.byKey(const ValueKey('palpation-mat-1')), findsNothing); // déjà confirmée
      expect(find.text('Palpation effectuée'), findsWidgets);
    });

    testWidgets('the menu offers edit and cancel', (tester) async {
      await _pump(tester);
      // Police de test très large : le formulaire d'édition existant a besoin de plus de largeur
      tester.view.physicalSize = const Size(1800, 3200);
      await tester.tap(find.byKey(const ValueKey('mating-menu-mat-2')));
      await tester.pumpAndSettle();
      expect(find.text('Modifier'), findsOneWidget);
      expect(find.text('Annuler la saillie'), findsOneWidget);

      await tester.tap(find.text('Modifier'));
      await tester.pumpAndSettle();
      expect(find.text("Modifier l'accouplement"), findsOneWidget);
      // la date de saillie est modifiable
      expect(find.text('Date de la saillie / accouplement'), findsOneWidget);
    });

    testWidgets('confirming the palpation records it and turns the pregnancy confirmed', (tester) async {
      final api = _Api();
      final provider = await _pump(tester);

      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('palpation-mat-2')));
        await tester.pumpAndSettle();
        expect(find.text('Palpation effectuée').last, findsOneWidget); // titre du dialogue
        expect(find.text(_fmt(DateTime.now())), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('palpation-confirm')));
        await tester.pumpAndSettle();
      }, api.client);

      final post = api.last('POST');
      expect(post, contains('/matings/mat-2/palpation/'));
      expect(api.body(post)['done_at'], _iso(DateTime.now()));
      expect(provider.getMatingById('mat-2')!.status, MatingStatus.confirmed);
      expect(provider.getMatingById('mat-2')!.palpationDoneAt, isNotNull);
      expect(find.text('Palpation enregistrée : gestation confirmée'), findsOneWidget);
      expect(find.byKey(const ValueKey('palpation-mat-2')), findsNothing, reason: 'plus de bouton une fois faite');
    });

    testWidgets('a refused palpation shows the server message', (tester) async {
      final api = _Api()..failWith = 400;
      await _pump(tester);
      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('palpation-mat-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('palpation-confirm')));
        await tester.pumpAndSettle();
      }, api.client);
      expect(find.text("Cette saillie n'est plus en attente de palpation."), findsOneWidget);
      expect(find.byKey(const ValueKey('palpation-mat-2')), findsOneWidget);
    });

    testWidgets('cancelling a mating marks it failed and moves it to the finished list', (tester) async {
      final api = _Api();
      final provider = await _pump(tester);

      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('mating-menu-mat-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annuler la saillie'));
        await tester.pumpAndSettle();
        expect(find.text('Annuler la saillie ?'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('cancel-reason')), 'Non gestante à la palpation');
        await tester.tap(find.byKey(const ValueKey('cancel-confirm')));
        await tester.pumpAndSettle();
      }, api.client);

      final post = api.last('POST');
      expect(post, contains('/matings/mat-2/cancel/'));
      expect(api.body(post), {'reason': 'Non gestante à la palpation'});
      expect(provider.getMatingById('mat-2')!.status, MatingStatus.failed);
      expect(find.text('Saillie annulée'), findsOneWidget);

      // elle quitte la liste « en cours » et apparaît dans « terminés » avec le badge Infructueux
      expect(find.byKey(const ValueKey('mating-mat-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mating-filter-finished')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mating-mat-2')), findsOneWidget);
      expect(find.text('Infructueux'), findsOneWidget);
      expect(find.byKey(const ValueKey('kindle-mat-2')), findsNothing, reason: 'plus d\'actions sur une saillie terminée');
    });

    testWidgets('going back from the cancel dialog changes nothing', (tester) async {
      final api = _Api();
      final provider = await _pump(tester);
      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('mating-menu-mat-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Annuler la saillie'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Retour'));
        await tester.pumpAndSettle();
      }, api.client);
      expect(api.requests.where((r) => r.startsWith('POST')), isEmpty);
      expect(provider.getMatingById('mat-2')!.status, MatingStatus.pending);
    });

    testWidgets('the kindling button opens the form on that very mating', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('kindle-mat-1')));
      await tester.pumpAndSettle();

      expect(find.text('Enregistrer une Mise Bas 🧺'), findsOneWidget);
      expect(find.byKey(const ValueKey('litter-mating-dropdown')), findsNothing, reason: 'accouplement imposé');
      expect(find.textContaining('Mère : Bella'), findsOneWidget);
      expect(find.byKey(const ValueKey('litter-birth-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('litter-too-early')), findsNothing);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('litter-submit'))).onPressed, isNotNull);
    });
  });

  group('litter form checks the dates', () {
    Future<RabbitProvider> openForm(WidgetTester tester, {Mating? mating}) async {
      final provider = await _pump(tester);
      await tester.tap(find.text('Mises bas (1)'));
      await tester.pumpAndSettle();
      if (mating == null) {
        await tester.tap(find.text('Enregistrer Mise Bas'));
      } else {
        // formulaire ouvert directement sur un accouplement donné
        final ctx = tester.element(find.byType(Scaffold).first);
        showLitterForm(ctx, provider, mating: mating);
      }
      await tester.pumpAndSettle();
      return provider;
    }

    testWidgets('via the button, the too-early mating is greyed out in the list and not selected', (tester) async {
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
