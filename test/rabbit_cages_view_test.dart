import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/models/cage.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/screens/cages_screen.dart';
import 'package:lapinou/screens/rabbit_list_screen.dart';

Cage _cage(String id, String name, {int rows = 3, Map<int, String> occupants = const {}}) {
  return Cage.fromJson({
    'id': id,
    'name': name,
    'location': 'Bâtiment $name',
    'rows_count': rows,
    'columns_count': 1,
    'compartments': [
      for (int i = 1; i <= rows; i++)
        {
          'number': i,
          'rabbit': occupants.containsKey(i)
              ? {
                  'id': 900 + i,
                  'name': occupants[i],
                  'tag_number': 'T$i',
                  'gender': 'F',
                  'status': 'active',
                  'photo': null,
                }
              : null,
        },
    ],
  });
}

Future<RabbitProvider> _pump(
  WidgetTester tester, {
  List<Cage> cages = const [],
  Map<String, String> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final rabbits = RabbitProvider()..seedForTesting();
  rabbits.setCagesForTesting(cages);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<RabbitProvider>.value(value: rabbits),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
    ],
    child: const MaterialApp(home: RabbitListScreen()),
  ));
  await tester.pumpAndSettle();
  return rabbits;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  testWidgets('with no cage, the very first thing is an "Ajouter une cage" button', (tester) async {
    await _pump(tester);

    expect(find.text('Mes cages'), findsOneWidget);
    expect(find.text('Ajouter une cage'), findsOneWidget);
    // au-dessus de la recherche, donc tout en haut de la page
    final addTop = tester.getTopLeft(find.text('Ajouter une cage')).dy;
    final searchTop = tester.getTopLeft(find.byType(TextField)).dy;
    expect(addTop, lessThan(searchTop));

    await tester.tap(find.text('Ajouter une cage'));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle cage'), findsOneWidget); // formulaire de création
  });

  testWidgets('cages appear as a horizontal strip above the search bar', (tester) async {
    await _pump(tester, cages: [
      _cage('1', 'A1', occupants: {1: 'Bella'}),
      _cage('2', 'B2', rows: 4),
    ]);

    expect(find.text('Cage A1'), findsOneWidget);
    expect(find.text('Cage B2'), findsOneWidget);
    expect(find.text('1/3 loges'), findsOneWidget);
    expect(find.text('1/7 loges occupées'), findsOneWidget);
    // le bouton d'ajout reste disponible à la fin de la bande
    expect(find.text('Ajouter\nune cage'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Cage A1')).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy));

    // la bande défile à l'horizontale
    final strip = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal).first;
    expect(strip, findsOneWidget);
  });

  testWidgets('tapping a cage opens its detail', (tester) async {
    await _pump(tester, cages: [_cage('1', 'A1', occupants: {1: 'Bella'})]);
    await tester.tap(find.text('Cage A1'));
    await tester.pumpAndSettle();
    expect(find.byType(CageDetailScreen), findsOneWidget);
  });

  testWidgets('grid view is the default and shows rabbit cards', (tester) async {
    await _pump(tester, cages: [_cage('1', 'A1')]);

    expect(find.text('Grille'), findsOneWidget);
    expect(find.text('Cages'), findsOneWidget);
    expect(find.text('Tous (7)'), findsOneWidget); // filtres visibles en grille
    expect(find.text('Bella'), findsOneWidget);
    expect(find.byType(CageCard), findsNothing);
  });

  testWidgets('cages view shows every cage with its rabbits, and rabbits without a cage', (tester) async {
    final provider = await _pump(tester, cages: [
      _cage('1', 'A1', occupants: {1: 'Bella', 2: 'Flash'}),
      _cage('2', 'B2'),
    ]);
    // Bella et Flash sont logés dans la cage 1 ; les autres n'ont pas de cage
    for (final name in ['Bella', 'Flash']) {
      final r = provider.rabbits.firstWhere((r) => r.name == name);
      await provider.updateRabbit(r.copyWith(cageId: '1'));
    }

    await tester.tap(find.text('Cages'));
    await tester.pumpAndSettle();

    // récapitulatif + une carte par cage, avec ses occupants dans le schéma
    expect(find.byType(CageSummaryBar), findsOneWidget);
    expect(find.byType(CageCard), findsNWidgets(2));
    expect(find.text('Cage A1'), findsWidgets);
    expect(find.text('2/3 loges occupées'), findsOneWidget);
    // les deux lapins de la cage A1 sont dessinés dans leurs loges (🐰 par loge occupée)
    final cageA1 = find.widgetWithText(CageCard, 'Cage A1');
    expect(find.descendant(of: cageA1, matching: find.text('🐰')), findsNWidgets(2));
    // ils n'apparaissent plus comme « sans cage »
    expect(find.text('Bella'), findsNothing);
    // les filtres de la grille sont masqués
    expect(find.text('Tous (7)'), findsNothing);

    // section « Sans cage » : les 5 autres lapins
    await tester.scrollUntilVisible(find.text('Sans cage'), 300,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Sans cage'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('Luna'), findsOneWidget);
  });

  testWidgets('the chosen view is remembered', (tester) async {
    await _pump(tester, cages: [_cage('1', 'A1')], prefs: {'rabbit_list_view': 'cages'});
    expect(find.byType(CageCard), findsOneWidget);
    expect(find.text('Tous (7)'), findsNothing);

    await tester.tap(find.text('Grille'));
    await tester.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('rabbit_list_view'), 'grid');
    expect(find.byType(CageCard), findsNothing);
    expect(find.text('Tous (7)'), findsOneWidget);
  });

  testWidgets('search narrows the cages view to matching cages and rabbits', (tester) async {
    await _pump(tester, cages: [
      _cage('1', 'A1', occupants: {1: 'Bella'}),
      _cage('2', 'B2', occupants: {1: 'Zorro'}),
    ], prefs: {'rabbit_list_view': 'cages'});
    expect(find.byType(CageCard), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'zorro');
    await tester.pumpAndSettle();
    expect(find.byType(CageCard), findsOneWidget);
    expect(find.widgetWithText(CageCard, 'Cage B2'), findsOneWidget);
    expect(find.widgetWithText(CageCard, 'Cage A1'), findsNothing);

    await tester.enterText(find.byType(TextField), 'introuvable-xyz');
    await tester.pumpAndSettle();
    expect(find.byType(CageCard), findsNothing);
    expect(find.text('Aucun lapin trouvé'), findsOneWidget);
  });

  testWidgets('cages view with no cage invites to add one', (tester) async {
    await _pump(tester, prefs: {'rabbit_list_view': 'cages'});
    expect(find.text('Ajouter une cage'), findsWidgets);
    expect(find.byType(CageCard), findsNothing);
  });
}
