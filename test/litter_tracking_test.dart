import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/models/cage.dart';
import 'package:lapinou/models/litter.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/screens/add_rabbit_screen.dart';
import 'package:lapinou/screens/cages_screen.dart';
import 'package:lapinou/screens/matings_screen.dart';
import 'package:lapinou/screens/rabbit_detail_screen.dart';
import 'package:lapinou/screens/rabbit_list_screen.dart';
import 'package:lapinou/widgets/cage_diagram.dart';

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

DateTime _daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

Litter _litter(
  String id, {
  int daysOld = 10,
  int alive = 6,
  int stillBorn = 0,
  int died = 0,
  int? weaned,
  String mother = 'p-f-2',
  String? father = 'p-m-2',
  DateTime? weaningDate,
}) =>
    Litter(
      id: id,
      motherId: mother,
      fatherId: father,
      birthDate: _daysAgo(daysOld),
      bornAlive: alive,
      stillBorn: stillBorn,
      diedCount: died,
      weanedCount: weaned,
      weaningDate: weaningDate,
    );

Map<String, dynamic> _occ(int id, String name, {int kits = 0}) => {
      'id': id,
      'name': name,
      'tag_number': 'T$id',
      'gender': 'F',
      'status': 'lactating',
      'photo': null,
      'nursing_kits': kits,
    };

Cage _cage({List<Map<String, dynamic>> inSlot1 = const []}) => Cage.fromJson({
      'id': 1,
      'name': 'A1',
      'rows_count': 3,
      'columns_count': 1,
      'compartments': [
        {'number': 1, 'rabbits': inSlot1},
        {'number': 2, 'rabbits': []},
        {'number': 3, 'rabbits': []},
      ],
    });

class _Api {
  final requests = <String>[];
  int? postStatus;
  String? postBody;

  MockClient client() => MockClient((req) async {
        requests.add('${req.method} ${req.url.path} ${req.body}');
        if (req.method == 'POST' && postStatus != null) {
          return http.Response(postBody ?? '{}', postStatus!, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        final ok = req.method == 'GET' ? {'success': true, 'data': []} : {'success': true, 'data': {}};
        return http.Response(jsonEncode(ok), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      });

  String? last(String method) => requests.lastWhere((r) => r.startsWith(method), orElse: () => '');
  Map<String, dynamic> bodyOf(String request) =>
      jsonDecode(request.substring(request.indexOf('{'))) as Map<String, dynamic>;
}

Future<RabbitProvider> _pump(
  WidgetTester tester,
  Widget home, {
  List<Litter>? litters,
  List<Cage> cages = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(420, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final provider = RabbitProvider()..seedForTesting();
  if (litters != null) provider.setLittersForTesting(litters);
  provider.setCagesForTesting(cages);
  provider.setTokenForTesting('tok');
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<RabbitProvider>.value(value: provider),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
    ],
    child: MaterialApp(home: home),
  ));
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Litter model', () {
    test('kits remaining, age, countdown and status', () {
      final nursing = _litter('a', daysOld: 12, alive: 7);
      expect(nursing.kitsRemaining, 7);
      expect(nursing.ageDays, 12);
      expect(nursing.daysUntilWeaning, 33);
      expect(nursing.status, LitterStatus.nursing);
      expect(nursing.weaningProgress, closeTo(12 / 45, 0.001));

      final due = _litter('b', daysOld: 50, alive: 5);
      expect(due.daysUntilWeaning, -5);
      expect(due.status, LitterStatus.weaningDue);
      expect(due.isWeaned, isFalse, reason: 'le sevrage ne se déduit plus de la date');

      final weaned = _litter('c', daysOld: 60, alive: 5, weaned: 4, died: 1);
      expect(weaned.kitsRemaining, 0);
      expect(weaned.status, LitterStatus.weaned);
      expect(_litter('d', alive: 5, weaned: 2, died: 1).kitsRemaining, 2);
    });

    test('a custom planned weaning date drives the countdown', () {
      final l = _litter('e', daysOld: 10, weaningDate: DateTime.now().add(const Duration(days: 4)));
      expect(l.daysUntilWeaning, 4);
      expect(l.status, LitterStatus.nursing);
    });

    test('parses server fields and serialises edits', () {
      final l = Litter.fromJson({
        'id': 3,
        'mother': 5,
        'father': 6,
        'birth_date': '2026-09-01',
        'born_alive': 8,
        'still_born': 1,
        'died_count': 2,
        'weaned_count': 3,
        'weaned_at': '2026-10-10',
        'weaning_date': '2026-10-16',
      });
      expect((l.bornAlive, l.stillBorn, l.diedCount, l.weaned), (8, 1, 2, 3));
      expect(l.kitsRemaining, 3);
      expect(l.weanedAt, DateTime(2026, 10, 10));
      expect(l.toEditJson(), containsPair('died_count', 2));
      expect(l.toEditJson(), containsPair('weaning_date', '2026-10-16'));
      expect(l.toEditJson().containsKey('weaned_count'), isFalse, reason: 'le sevrage passe par l\'action dédiée');
    });
  });

  group('Cage model and diagram', () {
    test('kits are counted per compartment and per cage', () {
      final cage = _cage(inSlot1: [_occ(1, 'Bella', kits: 7), _occ(2, 'Luna', kits: 4)]);
      expect(cage.slots[0].kitsCount, 11);
      expect(cage.slots[1].kitsCount, 0);
      expect(cage.kitsCount, 11);
      expect(cage.slots[0].occupants.first.nursingKits, 7);
    });

    testWidgets('compact and full diagrams show the kits of a compartment', (tester) async {
      final cage = _cage(inSlot1: [_occ(1, 'Bella', kits: 7)]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 180, child: CageDiagram(cage: cage, compact: true))),
      ));
      expect(find.text(' 🍼7'), findsOneWidget);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 380, child: CageDiagram(cage: cage)))),
      ));
      expect(find.text('🍼 7 lapereaux'), findsOneWidget);

      final none = _cage(inSlot1: [_occ(1, 'Bella')]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 380, child: CageDiagram(cage: none)))),
      ));
      expect(find.textContaining('🍼'), findsNothing);
    });

    testWidgets('a cage card announces the kits living in it', (tester) async {
      final cage = _cage(inSlot1: [_occ(1, 'Bella', kits: 5)]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CageCard(cage: cage, width: 220)),
      ));
      expect(find.text('🍼 5 lapereaux'), findsOneWidget);
    });
  });

  group('Litters screen', () {
    testWidgets('summary, filters and detailed cards', (tester) async {
      await _pump(tester, const MatingsScreen(initialTab: 1), litters: [
        _litter('n1', daysOld: 12, alive: 7, stillBorn: 1, died: 1),
        _litter('d1', daysOld: 50, alive: 5),
        _litter('w1', daysOld: 60, alive: 4, weaned: 4),
      ]);

      // 5 (7-1 mort) + ... : (7-0-1)=6 + 5 + 0 = 11 lapereaux au nid
      expect(find.text('11 lapereaux'), findsOneWidget);
      expect(find.textContaining('2 portées au nid · 1 à sevrer'), findsOneWidget);
      expect(find.text('Toutes (3)'), findsOneWidget);
      expect(find.text('Au nid (2)'), findsOneWidget);
      expect(find.text('À sevrer (1)'), findsOneWidget);
      expect(find.text('Sevrées (1)'), findsOneWidget);

      // détails de la portée au nid
      expect(find.textContaining('J12'), findsOneWidget);
      expect(find.text('Sevrage dans 33 j'), findsOneWidget);
      expect(find.text('1 mort-né · 1 mort au nid'), findsOneWidget);
      // portée à sevrer en retard, portée sevrée
      expect(find.text('Sevrage en retard de 5 j'), findsOneWidget);
      expect(find.text('Sevrage à faire'), findsOneWidget);
      expect(find.text('Sevrée'), findsOneWidget);
      // les portées sevrées n'ont plus de bouton « Sevrer »
      expect(find.byKey(const ValueKey('wean-w1')), findsNothing);
      expect(find.byKey(const ValueKey('wean-n1')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('litter-filter-toWean')));
      await tester.tap(find.byKey(const ValueKey('litter-filter-toWean')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('litter-d1')), findsOneWidget);
      expect(find.byKey(const ValueKey('litter-n1')), findsNothing);

      await tester.ensureVisible(find.byKey(const ValueKey('litter-filter-weaned')));
      await tester.tap(find.byKey(const ValueKey('litter-filter-weaned')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('litter-w1')), findsOneWidget);
      expect(find.byKey(const ValueKey('litter-d1')), findsNothing);
    });

    testWidgets('a litter shows where its mother lives', (tester) async {
      final provider = await _pump(
        tester,
        const MatingsScreen(initialTab: 1),
        litters: [_litter('n1')],
        cages: [_cage()],
      );
      final luna = provider.rabbits.firstWhere((r) => r.id == 'p-f-2');
      await provider.updateRabbit(luna.copyWith(cageId: '1', compartmentNumber: 2));
      await tester.pumpAndSettle();
      expect(find.text('📍 Cage A1 · loge 2'), findsOneWidget);
    });

    testWidgets('weaning everyone creates one record per kit', (tester) async {
      final api = _Api();
      await _pump(tester, const MatingsScreen(initialTab: 1), litters: [_litter('n1', alive: 3)]);

      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('wean-n1')));
        await tester.pumpAndSettle();
        expect(find.text('Sevrer la portée de Luna'), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey('wean-count'))).data, '3');
        for (final i in [0, 1, 2]) {
          expect(find.byKey(ValueKey('kit-row-$i')), findsOneWidget);
        }

        // sans sexe choisi : refus local, aucune requête
        await tester.tap(find.byKey(const ValueKey('wean-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Lapereau 1 : choisissez ♂ ou ♀.'), findsOneWidget);
        expect(api.requests.where((r) => r.startsWith('POST')), isEmpty);

        for (final i in [0, 1, 2]) {
          await tester.tap(find.descendant(
            of: find.byKey(ValueKey('kit-gender-$i')),
            matching: find.text(i == 1 ? '♀ Femelle' : '♂ Mâle'),
          ));
          await tester.pump();
        }
        await tester.enterText(find.byKey(const ValueKey('kit-name-0')), 'Rex');
        await tester.enterText(find.byKey(const ValueKey('kit-tag-0')), 'ab-1');
        await tester.tap(find.byKey(const ValueKey('wean-submit')));
        await tester.pumpAndSettle();
      }, api.client);

      final post = api.last('POST')!;
      expect(post, contains('/litters/n1/wean/'));
      final body = api.bodyOf(post);
      expect(body['count'], 3);
      expect(body['weaned_at'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      final kits = (body['rabbits'] as List).cast<Map<String, dynamic>>();
      expect(kits.map((k) => k['gender']), ['M', 'F', 'M']);
      expect(kits.first, containsPair('name', 'Rex'));
      expect(kits.first, containsPair('tag_number', 'AB-1'), reason: 'bague en majuscules');
      expect(find.textContaining('Sevrage enregistré'), findsOneWidget);
      expect(find.text('Sevrer la portée de Luna'), findsNothing, reason: 'feuille refermée');
    });

    testWidgets('partial weaning without creating records', (tester) async {
      final api = _Api();
      await _pump(tester, const MatingsScreen(initialTab: 1), litters: [_litter('n1', alive: 5)]);

      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('wean-n1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Moins')); // 5 -> 4
        await tester.pump();
        await tester.tap(find.byTooltip('Moins')); // 4 -> 3
        await tester.pump();
        expect(find.text('Sevrage partiel : 2 resteront au nid avec leur mère.'), findsOneWidget);
        expect(find.byKey(const ValueKey('kit-row-3')), findsNothing);

        await tester.tap(find.byKey(const ValueKey('wean-create-records')));
        await tester.pump();
        expect(find.byKey(const ValueKey('kit-row-0')), findsNothing);
        expect(find.text('Sevrer 3 lapereaux'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('wean-submit')));
        await tester.pumpAndSettle();
      }, api.client);

      final body = api.bodyOf(api.last('POST')!);
      expect(body['count'], 3);
      expect(body.containsKey('rabbits'), isFalse);
    });

    testWidgets('a server refusal is shown per kit and keeps the sheet open', (tester) async {
      final api = _Api()
        ..postStatus = 400
        ..postBody = jsonEncode({
          'success': false,
          'message': {'default': 'Sevrage impossible'},
          'errors': {
            'rabbits': {
              '1': {'tag_number': ['La bague K1 est déjà utilisée dans votre élevage.']},
            },
          },
        });
      await _pump(tester, const MatingsScreen(initialTab: 1), litters: [_litter('n1', alive: 2)]);

      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('wean-n1')));
        await tester.pumpAndSettle();
        for (final i in [0, 1]) {
          await tester.tap(find.descendant(of: find.byKey(ValueKey('kit-gender-$i')), matching: find.text('♂ Mâle')));
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('wean-submit')));
        await tester.pumpAndSettle();
      }, api.client);

      expect(find.text('Lapereau 2 : La bague K1 est déjà utilisée dans votre élevage.'), findsOneWidget);
      expect(find.text('Sevrer la portée de Luna'), findsOneWidget);
    });

    testWidgets('editing a litter sends the corrected counts', (tester) async {
      final api = _Api();
      await _pump(tester, const MatingsScreen(initialTab: 1), litters: [_litter('n1', alive: 6)]);

      await http.runWithClient(() async {
        await tester.tap(find.byKey(const ValueKey('edit-n1')));
        await tester.pumpAndSettle();
        expect(find.text('Modifier la portée'), findsOneWidget);
        await tester.tap(find.byTooltip('Plus').at(2)); // morts au nid : 0 -> 1
        await tester.pump();
        expect(find.text('Restent au nid : 5 · déjà sevrés : 0'), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('edit-notes')), 'Nid bien garni');
        await tester.tap(find.byKey(const ValueKey('edit-save')));
        await tester.pumpAndSettle();
      }, api.client);

      final patch = api.last('PATCH')!;
      expect(patch, contains('/litters/n1/'));
      final body = api.bodyOf(patch);
      expect((body['born_alive'], body['died_count'], body['notes']), (6, 1, 'Nid bien garni'));
      expect(find.text('Portée mise à jour'), findsOneWidget);
    });
  });

  group('litter form: birth date', () {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    testWidgets('defaults to today and shows the planned weaning date', (tester) async {
      await _pump(tester, const MatingsScreen(initialTab: 1), litters: const []);
      await tester.tap(find.text('Enregistrer Mise Bas'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(find.text('Date de la mise bas *'), findsOneWidget);
      expect(find.text(_fmt(now)), findsOneWidget);
      expect(find.text("Aujourd'hui"), findsOneWidget);
      expect(find.text('Sevrage prévu le ${_fmt(now.add(const Duration(days: 45)))}'), findsOneWidget);
    });

    testWidgets('a late registration keeps the real birth date and derives the weaning date from it', (tester) async {
      final api = _Api();
      await _pump(tester, const MatingsScreen(initialTab: 1), litters: const []);
      final now = DateTime.now();
      // Hier (ou aujourd'hui le 1er du mois) : après saillie + 21 jours (saillie d'il y a 29 jours)
      final target = now.day > 1 ? DateTime(now.year, now.month, now.day - 1) : now;

      await http.runWithClient(() async {
        await tester.tap(find.text('Enregistrer Mise Bas'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('litter-birth-date')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('${target.day}').last);
        await tester.pump();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text(_fmt(target)), findsOneWidget);
        expect(find.text('Sevrage prévu le ${_fmt(target.add(const Duration(days: 45)))}'), findsOneWidget);

        await tester.tap(find.text('Enregistrer la Portée'));
        await tester.pumpAndSettle();
      }, api.client);

      final body = api.bodyOf(api.last('POST')!);
      expect(body['birth_date'], iso(target));
      expect(body['born_alive'], 6);
      expect(find.textContaining('Mise bas du ${_fmt(target)} enregistrée'), findsOneWidget);
    });
  });

  group('rabbit pages', () {
    testWidgets('a doe with kits shows them in her profile and litters tab', (tester) async {
      final provider = await _pump(tester, const SizedBox(), litters: [
        _litter('n1', daysOld: 18, alive: 7),
        _litter('w1', daysOld: 120, alive: 5, weaned: 5),
      ]);
      final luna = provider.rabbits.firstWhere((r) => r.id == 'p-f-2');
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<RabbitProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: MaterialApp(home: RabbitDetailScreen(rabbit: luna)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('🍼 7 lapereaux au nid'), findsOneWidget);

      await tester.tap(find.text('Descendance'));
      await tester.pumpAndSettle();
      expect(find.text('Portées (2)'), findsOneWidget);
      final totals = find.byKey(const ValueKey('litter-totals'));
      expect(find.descendant(of: totals, matching: find.text('12')), findsOneWidget); // nés vivants
      expect(find.descendant(of: totals, matching: find.text('7')), findsOneWidget); // au nid
      expect(find.descendant(of: totals, matching: find.text('5')), findsOneWidget); // sevrés
      expect(find.text('7 nés vivants · 7 au nid · 0 sevrés'), findsOneWidget);
      expect(find.textContaining('Avec Goliath'), findsWidgets);
    });

    testWidgets('a buck sees the litters he sired', (tester) async {
      final provider = await _pump(tester, const SizedBox(), litters: [_litter('n1', alive: 4)]);
      // Police de test très large : on élargit l'écran pour la ligne de métriques de la fiche
      tester.view.physicalSize = const Size(900, 3200);
      final goliath = provider.rabbits.firstWhere((r) => r.id == 'p-m-2');
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<RabbitProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: MaterialApp(home: RabbitDetailScreen(rabbit: goliath)),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('lapereaux au nid'), findsNothing, reason: 'seule la mère héberge les lapereaux');
      await tester.tap(find.text('Descendance'));
      await tester.pumpAndSettle();
      expect(find.text('Portées (1)'), findsOneWidget);
      expect(find.textContaining('Avec la mère Luna'), findsOneWidget);
    });

    testWidgets('the rabbit list badges a doe that has kits', (tester) async {
      await _pump(tester, const RabbitListScreen(), litters: [_litter('n1', alive: 7)]);
      expect(find.byKey(const ValueKey('kits-badge-p-f-2')), findsOneWidget);
      expect(find.text('🍼 7'), findsOneWidget);
      expect(find.byKey(const ValueKey('kits-badge-p-f-1')), findsNothing);
    });
  });

  group('moving a doe with her kits', () {
    testWidgets('the picker announces that the kits follow her, and so does the confirmation', (tester) async {
      final api = _Api();
      await _pump(
        tester,
        const CageDetailScreen(cageId: '1'),
        litters: [_litter('n1', alive: 7)],
        cages: [_cage()],
      );

      await http.runWithClient(() async {
        await tester.tap(find.text('2')); // loge 2, libre
        await tester.pumpAndSettle();
        expect(find.textContaining('🍼 ses 7 lapereaux la suivront'), findsOneWidget);
        await tester.tap(find.textContaining('Luna'));
        await tester.pumpAndSettle();
      }, api.client);

      final patch = api.last('PATCH')!;
      expect(patch, contains('/rabbits/p-f-2/'));
      expect(api.bodyOf(patch), {'cage': 1, 'compartment_number': 2});
      expect(find.textContaining('Luna placé avec ses 7 lapereaux'), findsOneWidget);
    });

    testWidgets('an occupied loge shows the kits of its doe in the sheet', (tester) async {
      await _pump(
        tester,
        const CageDetailScreen(cageId: '1'),
        cages: [_cage(inSlot1: [_occ(50, 'Bella', kits: 6)])],
      );
      expect(find.text('🍼 6 lapereau(x) au nid'), findsOneWidget);
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(find.textContaining('avec 6 lapereaux'), findsOneWidget);
    });

    testWidgets('editing a doe with kits explains they come along', (tester) async {
      final provider = await _pump(tester, const SizedBox(), litters: [_litter('n1', alive: 7)], cages: [_cage()]);
      final luna = provider.rabbits.firstWhere((r) => r.id == 'p-f-2').copyWith(cageId: '1', compartmentNumber: 1);
      await provider.updateRabbit(luna);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<RabbitProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: MaterialApp(home: AddRabbitScreen(initialRabbitToEdit: luna)),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('kits-follow-note')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Ses 7 lapereaux non sevrés la suivent'), findsOneWidget);
    });
  });
}
