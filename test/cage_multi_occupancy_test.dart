import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/models/cage.dart';
import 'package:lapinou/models/rabbit.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/screens/add_rabbit_screen.dart';
import 'package:lapinou/screens/cages_screen.dart';
import 'package:lapinou/widgets/cage_diagram.dart';

Map<String, dynamic> _rabbit(int id, String name, {String gender = 'F'}) => {
      'id': id,
      'name': name,
      'tag_number': 'T$id',
      'gender': gender,
      'status': 'active',
      'photo': null,
    };

/// Cage de 3 loges ; [rabbits] associe un numéro de loge à ses lapins.
Cage _cage(Map<int, List<Map<String, dynamic>>> rabbits, {bool legacyFormat = false}) {
  return Cage.fromJson({
    'id': 1,
    'name': 'A1',
    'rows_count': 3,
    'columns_count': 1,
    'compartments': [
      for (int i = 1; i <= 3; i++)
        {
          'number': i,
          if (legacyFormat)
            'rabbit': rabbits[i]?.first
          else ...{
            'rabbits': rabbits[i] ?? [],
            'rabbit': rabbits[i]?.isEmpty ?? true ? null : rabbits[i]!.first,
          },
        },
    ],
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('model', () {
    test('a compartment can hold several rabbits', () {
      final cage = _cage({
        1: [_rabbit(10, 'Bella'), _rabbit(11, 'Flash', gender: 'M')],
        2: [_rabbit(12, 'Luna')],
      });
      expect(cage.slots[0].occupants.map((o) => o.name), ['Bella', 'Flash']);
      expect(cage.slots[0].isFree, isFalse);
      expect(cage.slots[0].occupant?.name, 'Bella', reason: 'premier lapin, pour compatibilité');
      expect(cage.slots[2].isFree, isTrue);
      expect(cage.occupiedCount, 2, reason: 'loges occupées, pas lapins');
      expect(cage.rabbitsCount, 3);
      expect(cage.freeCount, 1);
    });

    test('the old single-rabbit format is still understood', () {
      final cage = _cage({1: [_rabbit(10, 'Bella')]}, legacyFormat: true);
      expect(cage.slots[0].occupants.length, 1);
      expect(cage.slots[0].occupant?.name, 'Bella');
      expect(cage.rabbitsCount, 1);
      expect(cage.slots[1].isFree, isTrue);
    });

    test('single-occupant constructor argument still works', () {
      final c = CageCompartment(
        number: 2,
        occupant: const CageOccupant(id: '1', name: 'X', tagNumber: 'T', gender: RabbitGender.female),
      );
      expect(c.occupants.length, 1);
      expect(CageCompartment(number: 3).isFree, isTrue);
    });
  });

  group('diagram', () {
    testWidgets('compact view shows the number of rabbits sharing a compartment', (tester) async {
      final cage = _cage({
        1: [_rabbit(10, 'Bella'), _rabbit(11, 'Flash'), _rabbit(12, 'Luna')],
        2: [_rabbit(13, 'Titan', gender: 'M')],
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SizedBox(width: 180, child: CageDiagram(cage: cage, compact: true))),
      ));
      expect(find.text('🐰'), findsNWidgets(2)); // deux loges occupées
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('×1'), findsNothing);
    });

    testWidgets('full view lists the names of every rabbit in a shared compartment', (tester) async {
      final cage = _cage({
        1: [_rabbit(10, 'Bella'), _rabbit(11, 'Flash', gender: 'M')],
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 380, child: CageDiagram(cage: cage)))),
      ));
      expect(find.text('Bella, Flash'), findsOneWidget);
      expect(find.text('2 lapins'), findsOneWidget);
    });
  });

  group('cage detail', () {
    late RabbitProvider provider;
    final requests = <String>[];

    /// Fausse API : les PATCH réussissent, les GET renvoient des listes vides.
    MockClient api() => MockClient((req) async {
          requests.add('${req.method} ${req.url.path} ${req.body}');
          final ok = req.method == 'PATCH' ? {'success': true, 'data': {}} : {'success': true, 'data': []};
          return http.Response(jsonEncode(ok), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        });

    Future<void> openDetail(WidgetTester tester, Cage cage) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(420, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      requests.clear();

      provider = RabbitProvider()..seedForTesting();
      provider.setCagesForTesting([cage]);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<RabbitProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: MaterialApp(home: CageDetailScreen(cageId: cage.id)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('an occupied compartment still offers "Ajouter un lapin"', (tester) async {
      final cage = _cage({1: [_rabbit(10, 'Bella')]});
      await openDetail(tester, cage);

      expect(find.text('1 lapin(s)'), findsOneWidget);
      expect(find.text('1 loge(s) occupée(s)'), findsOneWidget);

      await http.runWithClient(() async {
        provider.setTokenForTesting('tok');

        await tester.tap(find.text('1')); // badge de la loge 1, occupée par Bella
        await tester.pumpAndSettle();

        // la feuille montre le lapin présent ET l'option d'ajout
        expect(find.text('Loge 1'), findsOneWidget);
        expect(find.text('1 lapin dans cette loge'), findsOneWidget);
        expect(find.byKey(const ValueKey('occupant-10')), findsOneWidget);
        expect(find.text('Ajouter un lapin dans cette loge'), findsOneWidget);

        await tester.tap(find.text('Ajouter un lapin dans cette loge'));
        await tester.pumpAndSettle();

        // le sélecteur propose les autres lapins, pas celui déjà dans la loge
        expect(find.textContaining('Placer un lapin : loge 1'), findsOneWidget);
        expect(find.text('Flash'), findsOneWidget);
        requests.clear();
        await tester.tap(find.text('Flash'));
        await tester.pumpAndSettle();
      }, api);

      final patch = requests.firstWhere((r) => r.startsWith('PATCH'));
      expect(patch, contains('/rabbits/p-m-1/'));
      expect(jsonDecode(patch.substring(patch.indexOf('{'))), {'cage': 1, 'compartment_number': 1});
      expect(find.textContaining('Flash placé'), findsOneWidget);
    });

    testWidgets('a rabbit already in the compartment is not offered again', (tester) async {
      // Bella (seed p-f-1) est dans la loge 1
      final cage = _cage({
        1: [
          {..._rabbit(0, 'Bella'), 'id': 'p-f-1'}
        ],
      });
      await openDetail(tester, cage);
      final bella = provider.rabbits.firstWhere((r) => r.name == 'Bella');
      await provider.updateRabbit(bella.copyWith(cageId: '1', compartmentNumber: 1));

      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un lapin dans cette loge'));
      await tester.pumpAndSettle();

      final picker = find.textContaining('Placer un lapin');
      expect(picker, findsOneWidget);
      final listTiles = find.descendant(of: find.byType(DraggableScrollableSheet), matching: find.byType(ListTile));
      expect(find.descendant(of: listTiles, matching: find.text('Bella')), findsNothing);
      expect(find.descendant(of: listTiles, matching: find.text('Flash')), findsOneWidget);
    });

    testWidgets('each rabbit of a shared compartment can be removed on its own', (tester) async {
      final cage = _cage({1: [_rabbit(10, 'Bella'), _rabbit(11, 'Flash', gender: 'M')]});
      await openDetail(tester, cage);

      await http.runWithClient(() async {
        provider.setTokenForTesting('tok');
        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();
        expect(find.text('2 lapins dans cette loge'), findsOneWidget);
        expect(find.byKey(const ValueKey('occupant-10')), findsOneWidget);
        expect(find.byKey(const ValueKey('occupant-11')), findsOneWidget);

        requests.clear();
        await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('occupant-11')),
          matching: find.byTooltip('Retirer de la loge'),
        ));
        await tester.pumpAndSettle();
      }, api);

      final patch = requests.firstWhere((r) => r.startsWith('PATCH'));
      expect(patch, contains('/rabbits/11/'));
      expect(jsonDecode(patch.substring(patch.indexOf('{')))['cage'], isNull);
      expect(find.textContaining('Flash retiré'), findsOneWidget);
    });

    testWidgets('a free compartment goes straight to the rabbit picker', (tester) async {
      await openDetail(tester, _cage({1: [_rabbit(10, 'Bella')]}));
      await tester.tap(find.text('3')); // loge libre
      await tester.pumpAndSettle();

      expect(find.textContaining('Placer un lapin : loge 3'), findsOneWidget);
      expect(find.text('Ajouter un lapin dans cette loge'), findsNothing);
    });
  });

  group('add rabbit form', () {
    testWidgets('an occupied compartment can be chosen and shows who is already there', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final provider = RabbitProvider()..seedForTesting();
      provider.setCagesForTesting([
        _cage({1: [_rabbit(10, 'Bella')], 2: []}),
      ]);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<RabbitProvider>.value(value: provider),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const MaterialApp(home: AddRabbitScreen()),
      ));
      await tester.pumpAndSettle();

      // choisir la cage A1
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Aucune cage').first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Cage A1').last);
      await tester.pumpAndSettle();

      // la première loge libre est proposée par défaut (loge 2)
      expect(find.textContaining('Loge 2 · libre'), findsOneWidget);

      // la loge occupée reste sélectionnable, avec son occupant affiché
      await tester.tap(find.textContaining('Loge 2 · libre'));
      await tester.pumpAndSettle();
      expect(find.text('Loge 1 · Bella'), findsOneWidget);
      await tester.tap(find.text('Loge 1 · Bella'));
      await tester.pumpAndSettle();
      expect(find.text('Loge 1 · Bella'), findsOneWidget);
    });
  });
}
