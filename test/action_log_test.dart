import 'package:flutter_test/flutter_test.dart';
import 'package:lapinou/services/local_database.dart';
import 'package:lapinou/services/sync_service.dart';

final _run = DateTime.now().microsecondsSinceEpoch;

void main() {
  test('a new action is listed as pending with its label', () async {
    await LocalDatabase.instance.switchToUser('log-a-$_run');
    await SyncService.instance.recordCreate(SyncEntity.cage, 'cage-$_run', {
      'name': 'Cage Nord',
    });

    final pending = SyncService.instance.pendingActions;
    final entry = pending.singleWhere((a) => a.localId == 'cage-$_run');
    expect(entry.label, 'Cage Nord');
    expect(entry.operation, 'create');
    expect(entry.status, 'pending');
  });

  test(
    'deleting a not-yet-sent creation cancels its pending actions',
    () async {
      await LocalDatabase.instance.switchToUser('log-b-$_run');
      await SyncService.instance.recordCreate(SyncEntity.finance, 'fin-$_run', {
        'title': 'Granulés',
      });
      await SyncService.instance.recordDelete(SyncEntity.finance, 'fin-$_run');

      final rows =
          SyncService.instance.history
              .where((a) => a.localId == 'fin-$_run')
              .toList();
      expect(rows.where((a) => a.status == 'pending'), isEmpty);
      expect(rows.where((a) => a.status == 'cancelled'), isNotEmpty);
    },
  );

  test('the history keeps every action, most recent first', () async {
    await LocalDatabase.instance.switchToUser('log-c-$_run');
    await SyncService.instance.recordCreate(SyncEntity.rabbit, 'rab-1-$_run', {
      'name': 'Un',
    });
    await SyncService.instance.recordCreate(SyncEntity.rabbit, 'rab-2-$_run', {
      'name': 'Deux',
    });

    final history = SyncService.instance.history;
    expect(history.first.label, 'Deux');
    expect(history.map((a) => a.label), containsAll(['Un', 'Deux']));
  });
}
