import 'package:flutter_test/flutter_test.dart';
import 'package:lapinou/services/local_database.dart';
import 'package:lapinou/services/sync_service.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

final _run = DateTime.now().microsecondsSinceEpoch;

void main() {
  test(
    'a local id is never sent as client_uuid: the queued create carries a real UUID',
    () async {
      await LocalDatabase.instance.switchToUser('uuid-test-$_run');
      await SyncService.instance.recordCreate(
        SyncEntity.rabbit,
        'rab-1727700000000',
        {'name': 'Flash'},
      );

      final queue = await LocalDatabase.instance.pendingQueue();
      final item = queue.singleWhere((q) => q.localId == 'rab-1727700000000');
      expect(item.payload['client_uuid'], matches(_uuid));
      expect(item.payload['client_uuid'], isNot('rab-1727700000000'));
    },
  );

  test('an id that is already a UUID is kept as client_uuid', () async {
    await LocalDatabase.instance.switchToUser('uuid-test-2-$_run');
    const id = '6f1c2a3e-4b5d-4e6f-8a9b-0c1d2e3f4a5b';
    await SyncService.instance.recordCreate(SyncEntity.cage, id, {
      'name': 'A1',
    });

    final item = (await LocalDatabase.instance.pendingQueue()).singleWhere(
      (q) => q.localId == id,
    );
    expect(item.payload['client_uuid'], id);
  });

  test(
    'a rejected create is listed and can be re-queued with a valid UUID',
    () async {
      await LocalDatabase.instance.switchToUser('uuid-test-3-$_run');
      await LocalDatabase.instance
          .upsertLocal(SyncEntity.cage, 'cage-1727700000001', {
            'name': 'B2',
            'client_uuid': 'cage-1727700000001',
            '_syncError': 'Erreur de validation',
          }, isDirty: true);

      await SyncService.instance.refreshPendingCount();
      await SyncService.instance.retryRejected();

      final item = (await LocalDatabase.instance.pendingQueue()).singleWhere(
        (q) => q.localId == 'cage-1727700000001',
      );
      expect(item.operation, 'create');
      expect(item.payload['client_uuid'], matches(_uuid));
      expect(item.payload.containsKey('_syncError'), isFalse);
    },
  );
}
