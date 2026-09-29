import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Entités du cheptel gérées hors-ligne (communauté et messagerie en sont exclues).
enum SyncEntity {
  rabbit,
  cage,
  mating,
  litter,
  careTreatment,
  careRecord,
  careEvent,
  finance,
}

extension SyncEntityTable on SyncEntity {
  String get table => 'entity_$name';
}

/// Une ligne locale d'une entité : `data` est l'objet complet tel que
/// `toJson()`/`fromJson()` le manipulent déjà côté modèles.
class LocalRecord {
  final String localId;
  final String? serverId;
  final Map<String, dynamic> data;
  final bool isDirty;
  final bool isDeleted;
  final String updatedAt;

  const LocalRecord({
    required this.localId,
    required this.serverId,
    required this.data,
    required this.isDirty,
    required this.isDeleted,
    required this.updatedAt,
  });

  factory LocalRecord.fromRow(Map<String, Object?> row) {
    return LocalRecord(
      localId: row['local_id'] as String,
      serverId: row['server_id'] as String?,
      data: jsonDecode(row['data'] as String) as Map<String, dynamic>,
      isDirty: (row['is_dirty'] as int) == 1,
      isDeleted: (row['is_deleted'] as int) == 1,
      updatedAt: row['updated_at'] as String,
    );
  }
}

/// Une opération en attente de synchronisation avec le serveur.
class SyncQueueItem {
  final int id;
  final SyncEntity entity;
  final String localId;
  final String operation; // create | update | delete
  final Map<String, dynamic> payload;
  final String clientUuid;
  final int retryCount;

  const SyncQueueItem({
    required this.id,
    required this.entity,
    required this.localId,
    required this.operation,
    required this.payload,
    required this.clientUuid,
    required this.retryCount,
  });

  factory SyncQueueItem.fromRow(Map<String, Object?> row) {
    return SyncQueueItem(
      id: row['id'] as int,
      entity: SyncEntity.values.firstWhere((e) => e.name == row['entity_type']),
      localId: row['local_id'] as String,
      operation: row['operation'] as String,
      payload: jsonDecode(row['payload_json'] as String) as Map<String, dynamic>,
      clientUuid: row['client_uuid'] as String,
      retryCount: row['retry_count'] as int,
    );
  }
}

/// Base de données locale (sqflite) : une table par entité du cheptel, plus la
/// file d'attente de synchronisation. Chaque enregistrement est stocké tel quel
/// (JSON) pour réutiliser les `toJson()`/`fromJson()` déjà écrits sur les modèles ;
/// le filtrage/tri fin reste fait en mémoire côté providers, comme aujourd'hui.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'lapinou_offline.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        for (final entity in SyncEntity.values) {
          await db.execute('''
            CREATE TABLE ${entity.table} (
              local_id TEXT PRIMARY KEY,
              server_id TEXT,
              data TEXT NOT NULL,
              is_dirty INTEGER NOT NULL DEFAULT 0,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_${entity.table}_server_id ON ${entity.table}(server_id)',
          );
        }
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity_type TEXT NOT NULL,
            local_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload_json TEXT NOT NULL,
            client_uuid TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
      },
    );
  }

  /// Toutes les lignes non supprimées d'une entité (ordre libre, tri fait en mémoire).
  Future<List<LocalRecord>> getAll(SyncEntity entity) async {
    final db = await database;
    final rows = await db.query(
      entity.table,
      where: 'is_deleted = 0',
    );
    return rows.map(LocalRecord.fromRow).toList();
  }

  /// Remplace le contenu local d'une entité par les données fraîchement reçues du
  /// serveur (utilisé par `fetchX`), sans toucher aux enregistrements encore `isDirty`
  /// (une modification hors-ligne pas encore poussée ne doit pas être écrasée).
  Future<void> replaceFromServer(
    SyncEntity entity,
    List<Map<String, dynamic>> serverRecords,
  ) async {
    final db = await database;
    final dirtyLocalIds = (await db.query(
      entity.table,
      columns: ['local_id'],
      where: 'is_dirty = 1',
    )).map((r) => r['local_id'] as String).toSet();

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final record in serverRecords) {
        final serverId = record['id'].toString();
        if (dirtyLocalIds.contains(serverId)) continue;
        batch.insert(
          entity.table,
          {
            'local_id': serverId,
            'server_id': serverId,
            'data': jsonEncode(record),
            'is_dirty': 0,
            'is_deleted': 0,
            'updated_at': (record['updated_at'] ?? DateTime.now().toIso8601String()).toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Enregistre localement une création/modification faite par l'utilisateur (en
  /// ligne ou non) ; `isDirty` marque qu'elle doit encore être poussée au serveur.
  Future<void> upsertLocal(
    SyncEntity entity,
    String localId,
    Map<String, dynamic> data, {
    required bool isDirty,
    String? serverId,
  }) async {
    final db = await database;
    await db.insert(
      entity.table,
      {
        'local_id': localId,
        'server_id': serverId,
        'data': jsonEncode(data),
        'is_dirty': isDirty ? 1 : 0,
        'is_deleted': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markDeletedLocal(SyncEntity entity, String localId) async {
    final db = await database;
    await db.update(
      entity.table,
      {'is_deleted': 1, 'is_dirty': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> removeLocal(SyncEntity entity, String localId) async {
    final db = await database;
    await db.delete(entity.table, where: 'local_id = ?', whereArgs: [localId]);
  }

  /// Après un push réussi : remplace l'id temporaire (uuid local) par l'id serveur
  /// définitif, et nettoie le drapeau `isDirty`.
  Future<void> confirmSynced(
    SyncEntity entity,
    String localId,
    String serverId,
    Map<String, dynamic> serverData,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(entity.table, where: 'local_id = ?', whereArgs: [localId]);
      await txn.insert(
        entity.table,
        {
          'local_id': serverId,
          'server_id': serverId,
          'data': jsonEncode(serverData),
          'is_dirty': 0,
          'is_deleted': 0,
          'updated_at': (serverData['updated_at'] ?? DateTime.now().toIso8601String()).toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> deleteConfirmedByServer(SyncEntity entity, String serverId) async {
    final db = await database;
    await db.delete(
      entity.table,
      where: 'local_id = ? AND is_dirty = 0',
      whereArgs: [serverId],
    );
  }

  /// Remplace un identifiant (local ou serveur) par un autre dans les champs FK
  /// d'un enregistrement local, ex. quand une dépendance vient d'être synchronisée.
  Future<void> remapForeignKey(
    SyncEntity entity,
    String fieldName,
    String fromId,
    String toId, {
    bool isList = false,
  }) async {
    final db = await database;
    final rows = await db.query(entity.table);
    for (final row in rows) {
      final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
      final value = data[fieldName];
      bool changed = false;
      if (isList && value is List) {
        final list = value.map((e) => e.toString()).toList();
        final idx = list.indexOf(fromId);
        if (idx != -1) {
          list[idx] = toId;
          data[fieldName] = list;
          changed = true;
        }
      } else if (!isList && value?.toString() == fromId) {
        data[fieldName] = toId;
        changed = true;
      }
      if (changed) {
        await db.update(
          entity.table,
          {'data': jsonEncode(data)},
          where: 'local_id = ?',
          whereArgs: [row['local_id']],
        );
      }
    }
  }

  Future<void> enqueue({
    required SyncEntity entity,
    required String localId,
    required String operation,
    required Map<String, dynamic> payload,
    required String clientUuid,
  }) async {
    final db = await database;
    await db.insert('sync_queue', {
      'entity_type': entity.name,
      'local_id': localId,
      'operation': operation,
      'payload_json': jsonEncode(payload),
      'client_uuid': clientUuid,
      'created_at': DateTime.now().toIso8601String(),
      'retry_count': 0,
    });
  }

  Future<List<SyncQueueItem>> pendingQueue() async {
    final db = await database;
    final rows = await db.query('sync_queue', orderBy: 'id ASC');
    return rows.map(SyncQueueItem.fromRow).toList();
  }

  Future<int> pendingCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> dequeue(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markQueueError(int id, String error) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  Future<void> updateQueuePayload(int id, Map<String, dynamic> payload) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'payload_json': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
