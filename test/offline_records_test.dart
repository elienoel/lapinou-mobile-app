import 'package:flutter_test/flutter_test.dart';
import 'package:lapinou/models/finance_transaction.dart';
import 'package:lapinou/models/litter.dart';
import 'package:lapinou/services/local_database.dart';
import 'package:lapinou/services/sync_service.dart';

final _run = DateTime.now().microsecondsSinceEpoch;

void main() {
  test(
    'an offline transaction can be read back from the local database (survives an app restart)',
    () async {
      await LocalDatabase.instance.switchToUser('offline-fin-$_run');
      final tx = FinanceTransaction(
        id: 'fin-1727700000000',
        type: TransactionType.expense,
        title: 'Granulés',
        amount: 32.5,
        date: DateTime(2026, 10, 1),
        category: 'Alimentation',
      );
      await SyncService.instance.recordCreate(
        SyncEntity.finance,
        tx.id,
        tx.toJson(),
      );

      // Simule un redémarrage : on relit uniquement ce qui est en base.
      final rows = await LocalDatabase.instance.getAll(SyncEntity.finance);
      final restored =
          rows.map((r) => FinanceTransaction.fromJson(r.data)).toList();
      expect(restored.map((t) => t.id), contains('fin-1727700000000'));
      expect(restored.single.amount, 32.5);
    },
  );

  test(
    'a litter keeps the local ids of its mating and father so the server can link them',
    () {
      final json =
          Litter(
            id: 'lit-1',
            matingId: 'mat-1727700000000',
            motherId: '12',
            fatherId: 'rab-1727700000001',
            birthDate: DateTime(2026, 10, 1),
            bornAlive: 6,
          ).toJson();

      expect(json['mating'], 'mat-1727700000000');
      expect(json['father'], 'rab-1727700000001');
      expect(json['mother'], 12);
    },
  );
}
