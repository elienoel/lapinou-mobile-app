import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapinou/models/rabbit.dart';
import 'package:lapinou/models/mating.dart';
import 'package:lapinou/models/litter.dart';
import 'package:lapinou/providers/rabbit_provider.dart';
import 'package:lapinou/providers/auth_provider.dart';
import 'package:lapinou/providers/community_provider.dart';
import 'package:lapinou/providers/chat_provider.dart';
import 'package:lapinou/screens/home_dashboard_screen.dart';
import 'package:lapinou/screens/main_navigation_screen.dart';
import 'package:lapinou/screens/profile_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });
  test('RabbitProvider calculates genealogy tree and offspring correctly', () {
    final provider = RabbitProvider()..seedForTesting();

    // Check pre-seeded data
    expect(provider.rabbits.isNotEmpty, isTrue);
    expect(provider.males.isNotEmpty, isTrue);
    expect(provider.females.isNotEmpty, isTrue);

    // Find young rabbit Caramel who has Flash (father) and Bella (mother)
    final caramel = provider.rabbits.firstWhere((r) => r.name == 'Caramel');
    expect(caramel.sireId, isNotNull);
    expect(caramel.damId, isNotNull);

    // Build pedigree
    final pedigree = provider.buildPedigree(caramel);
    expect(pedigree.rabbit.name, equals('Caramel'));
    expect(pedigree.father?.rabbit.name, equals('Flash'));
    expect(pedigree.mother?.rabbit.name, equals('Bella'));

    // Check grandparents through father
    expect(pedigree.father?.father?.rabbit.name, equals('Titan'));
    expect(pedigree.father?.mother?.rabbit.name, equals('Sultane'));

    // Add a new rabbit with Caramel as father
    final baby = Rabbit(
      id: 'baby-01',
      name: 'Noisette',
      tagNumber: 'FB-2024-99',
      gender: RabbitGender.female,
      breed: 'Fauve de Bourgogne',
      birthDate: DateTime.now(),
      color: 'Fauve clair',
      cageNumber: 'E-01',
      sireId: caramel.id,
    );
    provider.addRabbit(baby);

    final caramelOffspring = provider.getChildren(caramel.id);
    expect(caramelOffspring.length, equals(1));
    expect(caramelOffspring.first.name, equals('Noisette'));
  });

  testWidgets('App smoke test: loads Dashboard and navigation', (
    WidgetTester tester,
  ) async {
    final rabbitProvider = RabbitProvider();
    final authProvider = AuthProvider();
    final communityProvider = CommunityProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RabbitProvider>.value(value: rabbitProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<CommunityProvider>.value(
            value: communityProvider,
          ),
          ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ],
        child: const MaterialApp(home: HomeDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bonjour, Éleveur 🐰'), findsOneWidget);
    expect(find.text('Résumé de l\'activité'), findsOneWidget);
    expect(find.text('Mes lapins'), findsOneWidget);
    // Accouplements et mises bas sont regroupés sur une seule carte / une seule page
    expect(find.text('Accouplements & Mises bas'), findsOneWidget);
    // La communauté vit dans la barre de navigation du bas, plus dans le menu principal
    expect(find.text('Communauté d\'éleveurs'), findsNothing);
    expect(find.text('Soins & entretien'), findsOneWidget);
  });

  testWidgets('Community is a tab of the bottom navigation bar', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<RabbitProvider>(create: (_) => RabbitProvider()),
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<CommunityProvider>(
            create: (_) => CommunityProvider(),
          ),
          ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ],
        child: const MaterialApp(home: MainNavigationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Row),
        matching: find.text('Communauté'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Communauté'));
    await tester.pumpAndSettle();
    expect(find.text('Fil d\'actualité'), findsOneWidget);

    // Le profil reste accessible depuis l'avatar de l'accueil
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mon profil'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  test(
    'Mating gestation milestones calculations (palpation, nest box, birth)',
    () {
      final now = DateTime.now();
      final matingDate = now.subtract(const Duration(days: 28));
      final mating = Mating(
        id: 'm-test',
        maleId: 'm1',
        femaleId: 'f1',
        matingDate: matingDate,
      );

      // Gestation day should be ~29
      expect(mating.gestationDay, equals(29));
      // At Day 28, nest box should be installed
      expect(mating.shouldInstallNestBox, isTrue);
      // Estimated days until birth should be ~3
      expect(mating.daysUntilKindling, inInclusiveRange(2, 4));
    },
  );

  test(
    'Past mating registration date serialization and milestone tracking',
    () {
      final pastDate = DateTime(2026, 9, 10);
      final mating = Mating(
        id: 'mat-past-1',
        maleId: '1',
        femaleId: '2',
        matingDate: pastDate,
        notes: 'Accouplement noté a posteriori',
      );

      expect(mating.matingDate, equals(pastDate));
      expect(mating.palpationDate, equals(DateTime(2026, 9, 22)));
      expect(mating.nestBoxDate, equals(DateTime(2026, 10, 8)));
      expect(mating.expectedKindlingDate, equals(DateTime(2026, 10, 11)));

      final json = mating.toJson();
      expect(json['mating_date'], equals('2026-09-10'));
      final fromJson = Mating.fromJson(json);
      expect(fromJson.matingDate.year, equals(2026));
      expect(fromJson.matingDate.month, equals(9));
      expect(fromJson.matingDate.day, equals(10));
    },
  );

  test('Rabbit filtering and eligible parents logic', () {
    final provider = RabbitProvider()..seedForTesting();
    final maleCount = provider.males.length;
    final femaleCount = provider.females.length;
    expect(maleCount + femaleCount, equals(provider.totalRabbitsCount));

    final eligibleFathers = provider.getEligibleFathers();
    expect(eligibleFathers.every((r) => r.isMale), isTrue);

    final eligibleMothers = provider.getEligibleMothers();
    expect(eligibleMothers.every((r) => r.isFemale), isTrue);
  });
  test('Mating edit via copyWith and kindling selection by mating', () async {
    final provider = RabbitProvider()..seedForTesting();

    // Seed: mat-1 (confirmed) and mat-2 (pending), both awaiting kindling
    expect(
      provider.matingsAwaitingKindling.map((m) => m.id),
      equals(['mat-1', 'mat-2']),
    );

    // Editing a mating keeps its id and changes only the requested fields
    final mat2 = provider.getMatingById('mat-2')!;
    final newDate = DateTime(2026, 1, 1);
    final edited = mat2.copyWith(matingDate: newDate, notes: 'Corrigé');
    expect(edited.id, equals('mat-2'));
    expect(edited.maleId, equals(mat2.maleId));
    expect(edited.expectedKindlingDate, equals(DateTime(2026, 2, 1)));
    expect(mat2.copyWith(clearNotes: true).notes, isNull);
    expect(await provider.updateMating(edited), isTrue);
    expect(provider.getMatingById('mat-2')!.notes, equals('Corrigé'));

    // Recording a litter from a mating removes it from the selectable list
    final mat1 = provider.getMatingById('mat-1')!;
    await provider.addLitter(
      Litter(
        id: 'lit-x',
        matingId: mat1.id,
        motherId: mat1.femaleId,
        fatherId: mat1.maleId,
        birthDate: DateTime.now(),
        bornAlive: 6,
      ),
    );
    expect(
      provider.getMatingById('mat-1')!.status,
      equals(MatingStatus.kindled),
    );
    expect(
      provider.getRabbitById(mat1.femaleId)!.status,
      equals(RabbitStatus.lactating),
    );
    expect(
      provider.matingsAwaitingKindling.map((m) => m.id),
      equals(['mat-2']),
    );
  });
}
