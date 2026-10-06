import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapinou/models/cage.dart';
import 'package:lapinou/models/rabbit.dart';
import 'package:lapinou/widgets/cage_diagram.dart';

Cage _cage(
  int count, {
  Map<int, String> occupants = const {},
  int columns = 1,
}) {
  return Cage.fromJson({
    'id': 7,
    'name': 'A1',
    'rows_count': count,
    'columns_count': columns,
    'compartments': [
      for (int i = 1; i <= count * columns; i++)
        {
          'number': i,
          'rabbit':
              occupants.containsKey(i)
                  ? {
                    'id': 100 + i,
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

void main() {
  test('Cage.fromJson reads compartments and occupancy', () {
    final cage = _cage(3, occupants: {2: 'Bella'});
    expect(cage.compartmentsCount, 3);
    expect(cage.occupiedCount, 1);
    expect(cage.freeCount, 2);
    expect(cage.slots[1].occupant?.name, 'Bella');
    expect(cage.slots[1].occupant?.gender, RabbitGender.female);
  });

  test('Cage without detail falls back to free compartments', () {
    final cage = Cage.fromJson({
      'id': 1,
      'name': 'B2',
      'rows_count': 2,
      'columns_count': 2,
    });
    expect(cage.slots.length, 4);
    expect(cage.compartmentsCount, 4);
    expect(cage.occupiedCount, 0);
  });

  test('Rabbit serialises its cage and compartment', () {
    final rabbit = Rabbit.fromJson({
      'id': 1,
      'name': 'Flash',
      'tag_number': 'M1',
      'gender': 'M',
      'birth_date': '2025-01-01',
      'cage': 7,
      'compartment_number': 2,
    });
    expect(rabbit.cageId, '7');
    expect(rabbit.compartmentNumber, 2);
    expect(rabbit.toJson()['cage'], 7);
    expect(rabbit.toJson()['compartment_number'], 2);
    expect(rabbit.copyWith(clearCage: true).toJson()['cage'], isNull);
  });

  test(
    'a rabbit assigned to a not-yet-synced cage keeps the local id in its '
    'payload instead of dropping it, so SyncService can defer the push '
    'until the cage itself has synced (regression: used to silently send '
    'cage: null, losing the assignment)',
    () {
      final rabbit = Rabbit.fromJson({
        'id': 1,
        'name': 'Flash',
        'tag_number': 'M1',
        'gender': 'M',
        'birth_date': '2025-01-01',
      }).copyWith(cageId: 'cage-1727700000000', compartmentNumber: 2);

      expect(rabbit.toJson()['cage'], 'cage-1727700000000');
      expect(rabbit.toJson()['compartment_number'], 2);
    },
  );

  test(
    'a rabbit assigned to a not-yet-synced sire/dam keeps their local id too',
    () {
      final rabbit = Rabbit.fromJson({
        'id': 1,
        'name': 'Flash',
        'tag_number': 'M1',
        'gender': 'M',
        'birth_date': '2025-01-01',
      }).copyWith(sireId: 'rab-1727700000000', damId: 'rab-1727700000001');

      expect(rabbit.toJson()['sire'], 'rab-1727700000000');
      expect(rabbit.toJson()['dam'], 'rab-1727700000001');
    },
  );

  for (final count in [1, 3, 6]) {
    testWidgets('CageDiagram draws $count compartments', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: CageDiagram(cage: _cage(count, occupants: {1: 'Bella'})),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Libre'), findsNWidgets(count - 1));
      for (int i = 1; i <= count; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });
  }

  testWidgets('CageDiagram reports the tapped compartment', (tester) async {
    CageCompartment? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: CageDiagram(
                cage: _cage(3, occupants: {1: 'Bella'}),
                onCompartmentTap: (c) => tapped = c,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Libre').first, warnIfMissed: false);
    expect(tapped?.number, 2);
    expect(tapped?.isFree, isTrue);
  });

  test('grid numbering is row by row, left to right', () {
    final cage = _cage(2, columns: 3);
    expect(cage.compartmentsCount, 6);
    expect(cage.slotAt(1, 3).number, 3);
    expect(cage.slotAt(2, 1).number, 4);
    expect(cage.compartmentLabel(5), 'Loge 5 (ligne 2, colonne 2)');
  });

  testWidgets('CageDiagram draws a rows x columns grid', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: CageDiagram(
                cage: _cage(2, columns: 3, occupants: {5: 'Luna'}),
              ),
            ),
          ),
        ),
      ),
    );
    for (int i = 1; i <= 6; i++) {
      expect(find.text('$i'), findsOneWidget);
    }
    expect(find.text('Luna'), findsOneWidget);
  });
}
