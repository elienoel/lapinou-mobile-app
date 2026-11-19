import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clap_in/models/litter.dart';
import 'package:clap_in/models/mating.dart';
import 'package:clap_in/models/rabbit.dart';
import 'package:clap_in/providers/breeding_settings_provider.dart';
import 'package:clap_in/providers/rabbit_provider.dart';
import 'package:clap_in/screens/breeding_settings_screen.dart';
import 'package:clap_in/services/breeding_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BreedingSettings and Provider', () {
    test('Default values match rabbit farming standards', () {
      final s = BreedingSettings.defaults;
      expect(s.gestationDays, 31);
      expect(s.palpationDays, 12);
      expect(s.nestBoxDaysBeforeKindling, 3);
      expect(s.weaningDays, 45);
      expect(s.palpationNoticeDays, 0);
      expect(s.nestBoxNoticeDays, 0);
      expect(s.kindlingNoticeDays, 1);
      expect(s.weaningNoticeDays, 3);
      expect(s.nestBoxDaysAfterMating, 28);
    });

    test('Serialization and deserialization', () {
      const s = BreedingSettings(
        gestationDays: 30,
        palpationDays: 14,
        nestBoxDaysBeforeKindling: 2,
        weaningDays: 42,
        palpationNoticeDays: 1,
        nestBoxNoticeDays: 1,
        kindlingNoticeDays: 2,
        weaningNoticeDays: 5,
        notificationHour: 9,
      );

      final map = s.toMap();
      final restored = BreedingSettings.fromMap(map);

      expect(restored.gestationDays, 30);
      expect(restored.palpationDays, 14);
      expect(restored.nestBoxDaysBeforeKindling, 2);
      expect(restored.weaningDays, 42);
      expect(restored.palpationNoticeDays, 1);
      expect(restored.nestBoxNoticeDays, 1);
      expect(restored.kindlingNoticeDays, 2);
      expect(restored.weaningNoticeDays, 5);
      expect(restored.notificationHour, 9);
      expect(restored.nestBoxDayOfCycle, 28);
    });

    test('Provider persists to SharedPreferences and notifies', () async {
      final provider = BreedingSettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));

      bool notified = false;
      provider.addListener(() => notified = true);

      await provider.updateSettings(
        const BreedingSettings(
          gestationDays: 32,
          palpationDays: 13,
          nestBoxDaysBeforeKindling: 4,
          weaningDays: 50,
        ),
      );

      expect(notified, isTrue);
      expect(provider.settings.gestationDays, 32);
      expect(provider.settings.palpationDays, 13);
      expect(provider.settings.nestBoxDaysBeforeKindling, 4);
      expect(provider.settings.weaningDays, 50);

      // Verify loaded from fresh instance
      final fresh = BreedingSettingsProvider();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fresh.settings.gestationDays, 32);
      expect(fresh.settings.weaningDays, 50);
    });
  });

  group('Mating and Litter dynamic date calculations', () {
    final mating = Mating(
      id: 'm-1',
      femaleId: 'f-1',
      maleId: 'm-1',
      matingDate: DateTime(2026, 5, 1),
    );

    test('Calculates dates based on custom settings', () {
      const custom = BreedingSettings(
        gestationDays: 30,
        palpationDays: 10,
        nestBoxDaysBeforeKindling: 2,
        weaningDays: 40,
      );

      expect(mating.palpationDateWith(custom.palpationDays), DateTime(2026, 5, 11));
      // custom.nestBoxDaysAfterMating = 30 - 2 = 28
      expect(mating.nestBoxDateWith(custom.nestBoxDaysAfterMating), DateTime(2026, 5, 29));
      expect(mating.expectedKindlingDateWith(custom.gestationDays), DateTime(2026, 5, 31));

      final litter = Litter(
        id: 'l-1',
        birthDate: DateTime(2026, 5, 31),
        motherId: 'f-1',
        bornAlive: 6,
      );
      expect(litter.calculatedWeaningDateWith(custom.weaningDays), DateTime(2026, 7, 10));
    });
  });

  group('Breeding Notifications with custom delays', () {
    DateTime day(int fromToday) {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day + fromToday);
    }

    test('Schedules notifications based on custom notice days', () {
      final rabbitProvider = RabbitProvider()..seedForTesting();
      // mat-2 : Luna × Goliath, saillie il y a 8 jours
      // Par défaut J12 palpation (dans 4 jours).
      // Si palpationDays = 10, alors c'est dans 2 jours (J+2).
      // Si palpationNoticeDays = 1, on aura une notification "demain" pour la palpation dans 1 jour (J+1).
      const customSettings = BreedingSettings(
        gestationDays: 30,
        palpationDays: 10,
        palpationNoticeDays: 1,
        nestBoxDaysBeforeKindling: 2,
        nestBoxNoticeDays: 1,
      );

      final notifs = breedingNotifications(rabbitProvider, customSettings);
      expect(notifs, isNotEmpty);
      final palpationNotif = notifs.firstWhere((n) => n.title.contains('Palpation'));
      expect(palpationNotif.title, 'Palpation de Luna dans 1 jour');
      expect(DateTime(palpationNotif.day.year, palpationNotif.day.month, palpationNotif.day.day), day(1));
    });
  });

  group('BreedingSettingsScreen widget', () {
    testWidgets('Renders all setting controls and allows incrementing', (tester) async {
      final settingsProvider = BreedingSettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<BreedingSettingsProvider>.value(value: settingsProvider),
          ],
          child: const MaterialApp(
            home: BreedingSettingsScreen(),
          ),
        ),
      );

      // Pump single frame
      await tester.pump();

      expect(find.text('Cycles & Rappels d\'élevage'), findsOneWidget);
      expect(find.text('Durée de gestation (mise bas)'), findsOneWidget);
      expect(find.text('Palpation post-saillie'), findsOneWidget);
      expect(find.text('Pose de la boîte à nid'), findsOneWidget);
      expect(find.text('Âge au sevrage des lapereaux'), findsOneWidget);

      // Verify incrementing weaning days
      final incWeaning = find.byKey(const ValueKey('step-weaning-inc'));
      expect(incWeaning, findsOneWidget);
      await tester.tap(incWeaning);
      await tester.pump();

      expect(find.text('46'), findsOneWidget);
    });
  });
}
