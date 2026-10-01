import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_constants.dart';
import 'connectivity_service.dart';
import 'local_database.dart';

enum SyncStatus { idle, syncing, error }

/// Référence à une clé étrangère d'une entité vers une autre, utilisée pour
/// remapper un id local (uuid) vers l'id définitif attribué par le serveur une
/// fois qu'une dépendance créée hors-ligne est synchronisée (ex. une portée créée
/// hors-ligne référence une mère elle-même créée hors-ligne).
class _ForeignKeyRef {
  final SyncEntity entity;
  final String field;
  final SyncEntity target;
  final bool isList;
  const _ForeignKeyRef(this.entity, this.field, this.target, {this.isList = false});
}

class _EntityConfig {
  final String Function() listUrl;
  final String Function(String id) detailUrl;
  const _EntityConfig({required this.listUrl, required this.detailUrl});
}

/// Orchestre la synchronisation hors-ligne du cheptel : pousse les opérations en
/// attente vers le serveur (dans l'ordre où elles doivent être rejouées, avec
/// remapping des id temporaires) puis récupère les changements distants.
///
/// Communauté et messagerie ne passent pas par ce service : elles restent en ligne
/// uniquement, comme avant.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  final LocalDatabase _db = LocalDatabase.instance;
  String? _token;
  bool _isSyncing = false;
  SyncStatus _status = SyncStatus.idle;
  int _pendingCount = 0;
  String? _lastError;
  DateTime? _lastSyncedAt;
  StreamSubscription<bool>? _connectivitySub;

  SyncStatus get status => _status;
  int get pendingCount => _pendingCount;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;

  static final Map<SyncEntity, _EntityConfig> _configs = {
    SyncEntity.rabbit: _EntityConfig(
      listUrl: () => ApiConstants.rabbitsUrl,
      detailUrl: ApiConstants.rabbitDetailUrl,
    ),
    SyncEntity.cage: _EntityConfig(
      listUrl: () => ApiConstants.cagesUrl,
      detailUrl: ApiConstants.cageDetailUrl,
    ),
    SyncEntity.mating: _EntityConfig(
      listUrl: () => ApiConstants.matingsUrl,
      detailUrl: ApiConstants.matingDetailUrl,
    ),
    SyncEntity.litter: _EntityConfig(
      listUrl: () => ApiConstants.littersUrl,
      detailUrl: ApiConstants.litterDetailUrl,
    ),
    SyncEntity.careTreatment: _EntityConfig(
      listUrl: () => ApiConstants.careTreatmentsUrl,
      detailUrl: ApiConstants.careTreatmentDetailUrl,
    ),
    SyncEntity.careRecord: _EntityConfig(
      listUrl: () => ApiConstants.careRecordsUrl,
      detailUrl: ApiConstants.careRecordDetailUrl,
    ),
    SyncEntity.careEvent: _EntityConfig(
      listUrl: () => ApiConstants.careEventsUrl,
      detailUrl: ApiConstants.careEventDetailUrl,
    ),
    SyncEntity.finance: _EntityConfig(
      listUrl: () => ApiConstants.financesUrl,
      detailUrl: ApiConstants.financeDetailUrl,
    ),
  };

  /// Toutes les clés étrangères connues du cheptel, utilisées pour résoudre les
  /// id temporaires avant envoi et pour les remapper une fois une dépendance créée.
  static const List<_ForeignKeyRef> _foreignKeys = [
    _ForeignKeyRef(SyncEntity.mating, 'male', SyncEntity.rabbit),
    _ForeignKeyRef(SyncEntity.mating, 'female', SyncEntity.rabbit),
    _ForeignKeyRef(SyncEntity.litter, 'mating', SyncEntity.mating),
    _ForeignKeyRef(SyncEntity.litter, 'mother', SyncEntity.rabbit),
    _ForeignKeyRef(SyncEntity.litter, 'father', SyncEntity.rabbit),
    _ForeignKeyRef(SyncEntity.careEvent, 'rabbit', SyncEntity.rabbit),
    _ForeignKeyRef(SyncEntity.careRecord, 'treatment', SyncEntity.careTreatment),
    _ForeignKeyRef(SyncEntity.careRecord, 'rabbits', SyncEntity.rabbit, isList: true),
    _ForeignKeyRef(SyncEntity.rabbit, 'sire', SyncEntity.rabbit),
    _ForeignKeyRef(SyncEntity.rabbit, 'dam', SyncEntity.rabbit),
    _ForeignKeyRef(SyncEntity.rabbit, 'cage', SyncEntity.cage),
  ];

  void setToken(String? token) {
    _token = token;
  }

  void start() {
    ConnectivityService.instance.start();
    _connectivitySub ??= ConnectivityService.instance.onOnlineChanged.listen((online) {
      if (online) syncNow();
    });
    refreshPendingCount();
  }

  void disposeService() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> refreshPendingCount() async {
    _pendingCount = await _db.pendingCount();
    notifyListeners();
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  /// Enregistre une création (en ligne ou non) : écrit en local, enfile l'opération,
  /// puis tente une synchro immédiate si une connexion est disponible.
  Future<void> recordCreate(SyncEntity entity, String localId, Map<String, dynamic> payload) async {
    final body = {...payload, 'client_uuid': localId};
    await _db.upsertLocal(entity, localId, body, isDirty: true);
    await _db.enqueue(entity: entity, localId: localId, operation: 'create', payload: body, clientUuid: localId);
    await refreshPendingCount();
    await _syncIfOnline();
  }

  /// Enregistre une modification. Si l'enregistrement n'a encore jamais été
  /// synchronisé (création encore en attente), la modification est fusionnée dans
  /// cette création plutôt que d'être mise en file à part.
  Future<void> recordUpdate(SyncEntity entity, String localId, Map<String, dynamic> payload) async {
    final queue = await _db.pendingQueue();
    final pendingCreate = queue.where((q) => q.entity == entity && q.localId == localId && q.operation == 'create');
    if (pendingCreate.isNotEmpty) {
      final item = pendingCreate.first;
      final merged = {...item.payload, ...payload};
      await _db.updateQueuePayload(item.id, merged);
      await _db.upsertLocal(entity, localId, merged, isDirty: true);
      await _syncIfOnline();
      return;
    }
    await _db.upsertLocal(entity, localId, payload, isDirty: true, serverId: localId);
    await _db.enqueue(entity: entity, localId: localId, operation: 'update', payload: payload, clientUuid: localId);
    await refreshPendingCount();
    await _syncIfOnline();
  }

  /// Enregistre une suppression. Si la création correspondante n'a jamais été
  /// synchronisée, elle n'a jamais existé côté serveur : on annule simplement tout.
  Future<void> recordDelete(SyncEntity entity, String localId) async {
    final queue = await _db.pendingQueue();
    final pendingCreate = queue.where((q) => q.entity == entity && q.localId == localId && q.operation == 'create');
    if (pendingCreate.isNotEmpty) {
      await _db.dequeue(pendingCreate.first.id);
      await _db.removeLocal(entity, localId);
      await refreshPendingCount();
      return;
    }
    for (final q in queue.where((q) => q.entity == entity && q.localId == localId && q.operation == 'update')) {
      await _db.dequeue(q.id);
    }
    await _db.markDeletedLocal(entity, localId);
    await _db.enqueue(entity: entity, localId: localId, operation: 'delete', payload: const {}, clientUuid: localId);
    await refreshPendingCount();
    await _syncIfOnline();
  }

  Future<void> _syncIfOnline() async {
    if (await ConnectivityService.instance.isOnline()) {
      await syncNow();
    }
  }

  /// Pousse la file d'attente puis récupère les changements distants. Sans effet
  /// si aucun jeton n'est disponible (déconnecté) ou si une synchro est déjà en cours.
  Future<void> syncNow() async {
    if (_isSyncing || _token == null || _token!.isEmpty) return;
    _isSyncing = true;
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();
    try {
      await _push();
      await _pull();
      _lastSyncedAt = DateTime.now();
      // _push() s'arrête sans lever d'exception dès qu'un item échoue (réseau ou
      // serveur) pour ne pas bloquer les suivants indéfiniment : s'il reste des
      // éléments en file, ce n'est donc pas un vrai succès même sans exception.
      final stillPending = await _db.pendingCount();
      _status = stillPending == 0 ? SyncStatus.idle : SyncStatus.error;
      if (stillPending == 0) _lastError = null;
    } catch (e) {
      debugPrint('Sync error: $e');
      _status = SyncStatus.error;
      _lastError ??= 'Erreur de synchronisation : $e';
    } finally {
      _isSyncing = false;
      await refreshPendingCount();
      notifyListeners();
    }
  }

  bool _looksUnresolved(dynamic value) => value != null && int.tryParse(value.toString()) == null;

  bool _hasUnresolvedForeignKey(SyncQueueItem item) {
    for (final ref in _foreignKeys.where((r) => r.entity == item.entity)) {
      final value = item.payload[ref.field];
      if (ref.isList && value is List) {
        if (value.any(_looksUnresolved)) return true;
      } else if (!ref.isList && _looksUnresolved(value)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _push() async {
    final stuck = <int>{};
    while (true) {
      final queue = await _db.pendingQueue();
      final candidates = queue.where((q) => !stuck.contains(q.id)).toList();
      if (candidates.isEmpty) break;
      final item = candidates.first;

      if (_hasUnresolvedForeignKey(item)) {
        stuck.add(item.id);
        continue;
      }

      final progressed = await _processQueueItem(item);
      if (!progressed) break;
    }
  }

  /// Traite une opération de la file. Renvoie `false` pour arrêter cette passe de
  /// synchro (erreur réseau/serveur, à retenter plus tard) ; `true` sinon, y compris
  /// quand l'opération a été abandonnée pour une erreur de validation définitive.
  Future<bool> _processQueueItem(SyncQueueItem item) async {
    final config = _configs[item.entity]!;
    http.Response response;
    try {
      switch (item.operation) {
        case 'create':
          response = await http.post(
            Uri.parse(config.listUrl()),
            headers: _headers(),
            body: jsonEncode(item.payload),
          );
          break;
        case 'update':
          response = await http.patch(
            Uri.parse(config.detailUrl(item.localId)),
            headers: _headers(),
            body: jsonEncode(item.payload),
          );
          break;
        case 'delete':
          response = await http.delete(
            Uri.parse(config.detailUrl(item.localId)),
            headers: _headers(),
          );
          break;
        default:
          await _db.dequeue(item.id);
          return true;
      }
    } catch (e) {
      debugPrint('Network error syncing ${item.entity.name} ${item.operation}: $e');
      _lastError = 'Connexion au serveur impossible ($e).';
      return false;
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (item.operation == 'delete') {
        await _db.dequeue(item.id);
        return true;
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final data = Map<String, dynamic>.from(body['data']);
      final serverId = data['id'].toString();
      if (item.operation == 'create' && serverId != item.localId) {
        await _db.confirmSynced(item.entity, item.localId, serverId, data);
        await _remapEverywhere(item.entity, item.localId, serverId);
      } else {
        await _db.upsertLocal(item.entity, serverId, data, isDirty: false, serverId: serverId);
      }
      await _db.dequeue(item.id);
      return true;
    }

    if (response.statusCode == 404 && item.operation != 'create') {
      // Déjà supprimé côté serveur : on abandonne aussi localement.
      await _db.dequeue(item.id);
      if (item.operation == 'update') await _db.removeLocal(item.entity, item.localId);
      return true;
    }

    if (response.statusCode >= 400 && response.statusCode < 500) {
      // Erreur de validation définitive : inutile de retenter à l'identique. On la
      // consigne sur l'enregistrement local pour qu'elle reste consultable et on
      // retire l'opération de la file pour ne pas bloquer les suivantes.
      final error = _extractError(response);
      final current = Map<String, dynamic>.from(item.payload)..['_syncError'] = error;
      await _db.upsertLocal(item.entity, item.localId, current, isDirty: true);
      await _db.dequeue(item.id);
      return true;
    }

    debugPrint('Sync push failed (${response.statusCode}) for ${item.entity.name}: ${response.body}');
    _lastError = 'Le serveur a renvoyé une erreur (${response.statusCode}).';
    return false;
  }

  String _extractError(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        return first is List && first.isNotEmpty ? '${first.first}' : '$first';
      }
      final msg = body['message'];
      if (msg is Map && msg['default'] != null) return '${msg['default']}';
    } catch (_) {}
    return 'Erreur ${response.statusCode}';
  }

  /// Remplace [fromId] par [toId] partout où une entité peut y faire référence :
  /// dans les données déjà en base locale, et dans les opérations encore en file
  /// (pas encore envoyées) qui pointaient vers cet id temporaire.
  Future<void> _remapEverywhere(SyncEntity syncedEntity, String fromId, String toId) async {
    final refs = _foreignKeys.where((r) => r.target == syncedEntity);
    for (final ref in refs) {
      await _db.remapForeignKey(ref.entity, ref.field, fromId, toId, isList: ref.isList);

      final queue = await _db.pendingQueue();
      for (final q in queue.where((q) => q.entity == ref.entity)) {
        final payload = Map<String, dynamic>.from(q.payload);
        final value = payload[ref.field];
        if (ref.isList && value is List) {
          final list = value.map((e) => e.toString()).toList();
          final idx = list.indexOf(fromId);
          if (idx != -1) {
            list[idx] = toId;
            payload[ref.field] = list;
            await _db.updateQueuePayload(q.id, payload);
          }
        } else if (!ref.isList && value?.toString() == fromId) {
          payload[ref.field] = toId;
          await _db.updateQueuePayload(q.id, payload);
        }
      }
    }
  }

  Future<void> _pull() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _configs.entries) {
      final entity = entry.key;
      final config = entry.value;
      final prefsKey = 'sync_last_${entity.name}';
      final lastSync = prefs.getString(prefsKey);
      final since = lastSync != null ? '&updated_at_from=${Uri.encodeComponent(lastSync)}' : '';
      final uri = Uri.parse('${config.listUrl()}?all=true&include_deleted=true$since');

      try {
        final response = await http.get(uri, headers: _headers());
        if (response.statusCode != 200) continue;
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list = body['data'] is List ? body['data'] : const [];

        final alive = <Map<String, dynamic>>[];
        final deletedIds = <String>[];
        for (final raw in list) {
          final record = Map<String, dynamic>.from(raw as Map);
          if (record['is_deleted'] == true) {
            deletedIds.add(record['id'].toString());
          } else {
            alive.add(record);
          }
        }

        await _db.replaceFromServer(entity, alive);
        for (final id in deletedIds) {
          await _db.deleteConfirmedByServer(entity, id);
        }
        await prefs.setString(prefsKey, DateTime.now().toUtc().toIso8601String());
      } catch (e) {
        debugPrint('Pull failed for ${entity.name}: $e');
        _lastError = 'Impossible de récupérer les dernières données du serveur ($e).';
      }
    }
  }
}
