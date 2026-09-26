import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/rabbit.dart';
import '../models/cage.dart';
import '../models/mating.dart';
import '../models/litter.dart';
import '../models/care.dart';
import '../models/care_event.dart';
import '../models/finance_transaction.dart';
import '../services/api_constants.dart';

class PedigreeNode {
  final Rabbit rabbit;
  final PedigreeNode? father;
  final PedigreeNode? mother;

  PedigreeNode({required this.rabbit, this.father, this.mother});
}

class RabbitProvider extends ChangeNotifier {
  List<Rabbit> _rabbits = [];
  List<Cage> _cages = [];
  List<Mating> _matings = [];
  List<Litter> _litters = [];
  List<CareEvent> _careEvents = [];
  List<CareTreatment> _careTreatments = [];
  List<CareRecord> _careRecords = [];
  List<UpcomingCare> _upcomingCares = [];
  List<FinanceTransaction> _finances = [];

  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  RabbitProvider() {
    // Initial state is empty, synced with Django backend
  }

  void setToken(String? token) {
    if (_token != token) {
      _token = token;
      if (token != null && token.isNotEmpty) {
        fetchAll(token: token);
      }
    }
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Rabbit> get rabbits => List.unmodifiable(_rabbits);
  List<Cage> get cages => List.unmodifiable(_cages);
  List<Mating> get matings => List.unmodifiable(_matings);
  List<Litter> get litters => List.unmodifiable(_litters);
  List<CareEvent> get careEvents => List.unmodifiable(_careEvents);
  List<CareTreatment> get careTreatments => List.unmodifiable(_careTreatments);
  List<CareRecord> get careRecords => List.unmodifiable(_careRecords);
  List<UpcomingCare> get upcomingCares => List.unmodifiable(_upcomingCares);
  List<FinanceTransaction> get finances => List.unmodifiable(_finances);

  Map<String, String> _headers([String? token]) {
    final t = token ?? _token;
    return {
      'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  // Filtered rabbit lists
  List<Rabbit> get males =>
      _rabbits.where((r) => r.gender == RabbitGender.male).toList();

  List<Rabbit> get females =>
      _rabbits.where((r) => r.gender == RabbitGender.female).toList();

  List<Rabbit> get pregnantFemales =>
      _rabbits.where((r) => r.status == RabbitStatus.pregnant).toList();

  int get totalRabbitsCount => _rabbits.length;
  int get activePregnanciesCount =>
      _rabbits.where((r) => r.status == RabbitStatus.pregnant).length;
  /// Lapereaux encore au nid (nés vivants, ni sevrés ni morts), toutes portées confondues.
  int get totalKitsInNests => _litters.fold(0, (sum, l) => sum + l.kitsRemaining);

  /// Portées dont la date de sevrage prévue est passée et qui attendent d'être sevrées.
  int get littersToWeanCount =>
      _litters.where((l) => l.status == LitterStatus.weaningDue).length;

  /// Lapereaux non sevrés qui vivent avec cette lapine (ils la suivent quand on la déplace).
  int nursingKitsOf(String rabbitId) => _litters
      .where((l) => l.motherId == rabbitId)
      .fold(0, (sum, l) => sum + l.kitsRemaining);

  /// Portées d'un lapin (comme mère ou comme père), la plus récente d'abord.
  List<Litter> littersOf(String rabbitId) {
    final list =
        _litters.where((l) => l.motherId == rabbitId || l.fatherId == rabbitId).toList()
          ..sort((a, b) => b.birthDate.compareTo(a.birthDate));
    return list;
  }

  /// Soins en retard ou à faire dans la semaine.
  int get pendingCareCount =>
      _upcomingCares.where((c) => c.status != DueStatus.upcoming).length;

  /// Soins effectués sur un lapin, le plus récent d'abord.
  List<CareRecord> careRecordsOf(String rabbitId) =>
      _careRecords.where((c) => c.rabbits.any((r) => r.id == rabbitId)).toList();

  /// Prochains soins d'un lapin, du plus urgent au plus lointain.
  List<UpcomingCare> upcomingCaresOf(String rabbitId) =>
      _upcomingCares.where((c) => c.rabbits.any((r) => r.id == rabbitId)).toList();

  Rabbit? getRabbitById(String? id) {
    if (id == null) return null;
    try {
      return _rabbits.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Synchronisation complète avec le backend
  Future<void> fetchAll({String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.wait([
      fetchRabbits(token: token),
      fetchCages(token: token),
      fetchMatings(token: token),
      fetchLitters(token: token),
      fetchCareEvents(token: token),
      fetchCare(token: token),
      fetchFinances(token: token),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  /// 1. Lapins (CRUD)
  Future<void> fetchRabbits({String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConstants.rabbitsUrl),
        headers: _headers(t),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list =
            body['data'] is List
                ? body['data']
                : (body['results'] is List ? body['results'] : []);
        if (list.isNotEmpty) {
          _rabbits = list.map((item) => Rabbit.fromJson(item)).toList();
          notifyListeners();
        }
        _rabbits = list.map((item) => Rabbit.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching rabbits: $e');
    }
  }

  Future<bool> addRabbit(
    Rabbit rabbit, {
    File? photoFile,
    String? token,
  }) async {
    // Optimistic local update
    _rabbits.insert(0, rabbit);
    notifyListeners();

    final t = token ?? _token;
    if (t == null || t.isEmpty) return true;

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.rabbitsUrl),
        headers: _headers(t),
        body: jsonEncode(rabbit.toJson()),
      );
      if (response.statusCode == 201) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final created = Rabbit.fromJson(body['data']);
        final idx = _rabbits.indexWhere((r) => r.id == rabbit.id);
        if (idx != -1) {
          _rabbits[idx] = created;
          notifyListeners();
        }

        // Si une photo a été fournie lors de la création, la téléverser
        if (photoFile != null) {
          await uploadRabbitPhoto(
            created.id,
            photoFile,
            isPrimary: true,
            token: t,
          );
        }

        return true;
      }
    } catch (e) {
      debugPrint('Error creating rabbit: $e');
    }
    return false;
  }

  Future<bool> uploadRabbitPhoto(
    String rabbitId,
    File photoFile, {
    bool isPrimary = true,
    String? caption,
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return false;

    try {
      final uri = Uri.parse(ApiConstants.rabbitUploadPhotoUrl(rabbitId));
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $t';

      request.fields['is_primary'] = isPrimary ? 'true' : 'false';
      if (caption != null && caption.isNotEmpty) {
        request.fields['caption'] = caption;
      }

      final multipartFile = await http.MultipartFile.fromPath(
        'photo',
        photoFile.path,
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body['data'] != null) {
          final updatedRabbit = Rabbit.fromJson(body['data']);
          final idx = _rabbits.indexWhere((r) => r.id == rabbitId);
          if (idx != -1) {
            _rabbits[idx] = updatedRabbit;
          } else {
            _rabbits.add(updatedRabbit);
          }
          notifyListeners();
          return true;
        }
      } else {
        debugPrint(
          'Error uploading photo status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Exception uploading rabbit photo: $e');
    }
    return false;
  }

  Future<bool> setPrimaryPhoto(
    String rabbitId,
    int imageId, {
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return false;

    try {
      final uri = Uri.parse(
        ApiConstants.rabbitSetPrimaryPhotoUrl(rabbitId, imageId),
      );
      final response = await http.post(uri, headers: _headers(t));

      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body['data'] != null) {
          final updatedRabbit = Rabbit.fromJson(body['data']);
          final idx = _rabbits.indexWhere((r) => r.id == rabbitId);
          if (idx != -1) {
            _rabbits[idx] = updatedRabbit;
            notifyListeners();
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error setting primary photo: $e');
    }
    return false;
  }

  Future<bool> deleteRabbitPhoto(
    String rabbitId,
    int imageId, {
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return false;

    try {
      final uri = Uri.parse(
        ApiConstants.rabbitDeletePhotoUrl(rabbitId, imageId),
      );
      final response = await http.delete(uri, headers: _headers(t));

      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        if (body['data'] != null) {
          final updatedRabbit = Rabbit.fromJson(body['data']);
          final idx = _rabbits.indexWhere((r) => r.id == rabbitId);
          if (idx != -1) {
            _rabbits[idx] = updatedRabbit;
            notifyListeners();
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error deleting rabbit photo: $e');
    }
    return false;
  }

  Future<bool> updateRabbit(Rabbit rabbit, {String? token}) async {
    final index = _rabbits.indexWhere((r) => r.id == rabbit.id);
    if (index != -1) {
      _rabbits[index] = rabbit;
      notifyListeners();
    }

    final t = token ?? _token;
    if (t == null || t.isEmpty) return true;

    try {
      final response = await http.patch(
        Uri.parse(ApiConstants.rabbitDetailUrl(rabbit.id)),
        headers: _headers(t),
        body: jsonEncode(rabbit.toJson()),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final updated = Rabbit.fromJson(body['data']);
        final idx = _rabbits.indexWhere((r) => r.id == rabbit.id);
        if (idx != -1) {
          _rabbits[idx] = updated;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error updating rabbit: $e');
    }
    return false;
  }

  Future<bool> deleteRabbit(String id, {String? token}) async {
    _rabbits.removeWhere((r) => r.id == id);
    notifyListeners();

    final t = token ?? _token;
    if (t == null || t.isEmpty) return true;

    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.rabbitDetailUrl(id)),
        headers: _headers(t),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting rabbit: $e');
    }
    return false;
  }

  /// Cages (CRUD) et occupation des loges
  Cage? getCageById(String? id) {
    if (id == null) return null;
    for (final c in _cages) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> fetchCages({String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.cagesUrl}?all=true'),
        headers: _headers(t),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list = body['data'] is List ? body['data'] : [];
        _cages = list.map((item) => Cage.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching cages: $e');
    }
  }

  /// Retourne null en cas de succès, sinon le message d'erreur à afficher.
  Future<String?> saveCage(
    Cage cage, {
    bool isNew = true,
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';

    try {
      final response =
          isNew
              ? await http.post(
                Uri.parse(ApiConstants.cagesUrl),
                headers: _headers(t),
                body: jsonEncode(cage.toJson()),
              )
              : await http.patch(
                Uri.parse(ApiConstants.cageDetailUrl(cage.id)),
                headers: _headers(t),
                body: jsonEncode(cage.toJson()),
              );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCages(token: t);
        return null;
      }
      return _extractError(response);
    } catch (e) {
      debugPrint('Error saving cage: $e');
      return 'Impossible de joindre le serveur';
    }
  }

  Future<bool> deleteCage(String id, {String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return false;

    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.cageDetailUrl(id)),
        headers: _headers(t),
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        // Les lapins de la cage supprimée sont désormais sans cage.
        await Future.wait([fetchCages(token: t), fetchRabbits(token: t)]);
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting cage: $e');
    }
    return false;
  }

  /// Place un lapin dans une loge (ou le retire de sa cage si [cageId] est null).
  /// Retourne null en cas de succès, sinon le message d'erreur à afficher.
  Future<String?> assignRabbitToCompartment(
    String rabbitId, {
    String? cageId,
    int? compartmentNumber,
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';

    try {
      final response = await http.patch(
        Uri.parse(ApiConstants.rabbitDetailUrl(rabbitId)),
        headers: _headers(t),
        body: jsonEncode({
          'cage': cageId == null ? null : int.tryParse(cageId),
          'compartment_number': cageId == null ? null : compartmentNumber,
          if (cageId == null) 'cage_number': 'Non assigné',
        }),
      );
      if (response.statusCode == 200) {
        await Future.wait([fetchRabbits(token: t), fetchCages(token: t)]);
        return null;
      }
      return _extractError(response);
    } catch (e) {
      debugPrint('Error assigning rabbit to compartment: $e');
      return 'Impossible de joindre le serveur';
    }
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

  /// 2. Accouplements (Saillies)
  Future<void> fetchMatings({String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConstants.matingsUrl),
        headers: _headers(t),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list =
            body['data'] is List
                ? body['data']
                : (body['results'] is List ? body['results'] : []);
        if (list.isNotEmpty) {
          _matings = list.map((item) => Mating.fromJson(item)).toList();
          notifyListeners();
        }
        _matings = list.map((item) => Mating.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching matings: $e');
    }
  }

  Future<bool> addMating(Mating mating, {String? token}) async {
    _matings.insert(0, mating);
    _setLocalRabbitStatus(mating.femaleId, RabbitStatus.pregnant);
    notifyListeners();

    final t = token ?? _token;
    if (t == null || t.isEmpty) return true;

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.matingsUrl),
        headers: _headers(t),
        body: jsonEncode(mating.toJson()),
      );
      if (response.statusCode == 201) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final created = Mating.fromJson(body['data']);
        final idx = _matings.indexWhere((m) => m.id == mating.id);
        if (idx != -1) {
          _matings[idx] = created;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error creating mating: $e');
    }
    return false;
  }

  /// Modifie un accouplement (mâle, femelle, date de saillie, statut, notes).
  /// Le backend recalcule les échéances et resynchronise le statut des femelles.
  Future<bool> updateMating(Mating mating, {String? token}) async {
    final index = _matings.indexWhere((m) => m.id == mating.id);
    final previous = index != -1 ? _matings[index] : null;
    if (index != -1) {
      _matings[index] = mating;
      notifyListeners();
    }

    final t = token ?? _token;
    if (t == null || t.isEmpty) return true;

    try {
      final response = await http.patch(
        Uri.parse(ApiConstants.matingDetailUrl(mating.id)),
        headers: _headers(t),
        body: jsonEncode(mating.toJson()),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final updated = Mating.fromJson(body['data']);
        final idx = _matings.indexWhere((m) => m.id == mating.id);
        if (idx != -1) {
          _matings[idx] = updated;
          notifyListeners();
        }
        // Les statuts des femelles concernées ont pu changer côté serveur
        await fetchRabbits(token: t);
        return true;
      }
      debugPrint(
        'Error updating mating ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('Error updating mating: $e');
    }

    // Échec : restaurer l'état précédent
    if (previous != null) {
      final idx = _matings.indexWhere((m) => m.id == mating.id);
      if (idx != -1) {
        _matings[idx] = previous;
        notifyListeners();
      }
    }
    return false;
  }

  /// Confirme que la palpation a été effectuée (gestation confirmée) à la date [doneAt].
  /// Renvoie null en cas de succès, sinon le message d'erreur.
  Future<String?> confirmPalpation(Mating mating, {DateTime? doneAt, String? token}) {
    final d = doneAt ?? DateTime.now();
    return _matingAction(
      ApiConstants.matingPalpationUrl(mating.id),
      {
        'done_at':
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      },
      token: token,
    );
  }

  /// Annule la saillie (échec constaté, par exemple à la palpation) ; [reason] est ajouté aux notes.
  Future<String?> cancelMating(Mating mating, {String? reason, String? token}) {
    return _matingAction(
      ApiConstants.matingCancelUrl(mating.id),
      {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()},
      token: token,
    );
  }

  Future<String?> _matingAction(String url, Map<String, dynamic> body, {String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _headers(t),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final updated = Mating.fromJson(Map<String, dynamic>.from(data['data']));
        final idx = _matings.indexWhere((m) => m.id == updated.id);
        if (idx != -1) _matings[idx] = updated;
        notifyListeners();
        // Le statut de la femelle (gestante / active) a pu changer côté serveur
        await fetchRabbits(token: t);
        return null;
      }
      return _extractError(response);
    } catch (e) {
      debugPrint('Error on mating action: $e');
      return 'Impossible de joindre le serveur';
    }
  }

  /// Accouplements pouvant encore donner lieu à une mise bas
  /// (en cours de gestation et sans portée déjà enregistrée).
  List<Mating> get matingsAwaitingKindling {
    final withLitter =
        _litters.map((l) => l.matingId).whereType<String>().toSet();
    final list =
        _matings
            .where(
              (m) =>
                  (m.status == MatingStatus.pending ||
                      m.status == MatingStatus.confirmed) &&
                  !withLitter.contains(m.id),
            )
            .toList();
    list.sort(
      (a, b) => a.expectedKindlingDate.compareTo(b.expectedKindlingDate),
    );
    return list;
  }

  Mating? getMatingById(String? id) {
    if (id == null) return null;
    try {
      return _matings.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  void _setLocalRabbitStatus(String rabbitId, RabbitStatus status) {
    final idx = _rabbits.indexWhere((r) => r.id == rabbitId);
    if (idx != -1) {
      _rabbits[idx] = _rabbits[idx].copyWith(status: status);
    }
  }

  /// 3. Mises bas (Portées)
  Future<void> fetchLitters({String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConstants.littersUrl),
        headers: _headers(t),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list =
            body['data'] is List
                ? body['data']
                : (body['results'] is List ? body['results'] : []);
        if (list.isNotEmpty) {
          _litters = list.map((item) => Litter.fromJson(item)).toList();
          notifyListeners();
        }
        _litters = list.map((item) => Litter.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching litters: $e');
    }
  }

  Future<bool> addLitter(Litter litter, {String? token}) async {
    _litters.insert(0, litter);
    _setLocalRabbitStatus(litter.motherId, RabbitStatus.lactating);
    final matingIdx = _matings.indexWhere((m) => m.id == litter.matingId);
    if (matingIdx != -1) {
      _matings[matingIdx] = _matings[matingIdx].copyWith(
        status: MatingStatus.kindled,
      );
    }
    notifyListeners();

    final t = token ?? _token;
    if (t == null || t.isEmpty) return true;

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.littersUrl),
        headers: _headers(t),
        body: jsonEncode(litter.toJson()),
      );
      if (response.statusCode == 201) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final created = Litter.fromJson(body['data']);
        final idx = _litters.indexWhere((l) => l.id == litter.id);
        if (idx != -1) {
          _litters[idx] = created;
          notifyListeners();
        }
        // Le backend a mis à jour l'accouplement (mise bas réalisée) et la mère
        await Future.wait([
          fetchMatings(token: t),
          fetchRabbits(token: t),
          fetchCages(token: t),
        ]);
        return true;
      }
      debugPrint(
        'Error creating litter ${response.statusCode}: ${response.body}',
      );
    } catch (e) {
      debugPrint('Error creating litter: $e');
    }
    // Échec : resynchroniser pour annuler la mise à jour optimiste
    await fetchAll(token: t);
    return false;
  }

  /// Corrige une portée (effectifs, morts au nid, date de sevrage prévue, notes).
  /// Renvoie null en cas de succès, sinon le message d'erreur.
  Future<String?> updateLitter(Litter litter, {String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';
    try {
      final response = await http.patch(
        Uri.parse(ApiConstants.litterDetailUrl(litter.id)),
        headers: _headers(t),
        body: jsonEncode(litter.toEditJson()),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final updated = Litter.fromJson(Map<String, dynamic>.from(body['data']));
        final idx = _litters.indexWhere((l) => l.id == litter.id);
        if (idx != -1) _litters[idx] = updated;
        notifyListeners();
        await fetchRabbits(token: t);
        return null;
      }
      return _extractError(response);
    } catch (e) {
      debugPrint('Error updating litter: $e');
      return 'Impossible de joindre le serveur';
    }
  }

  /// Enregistre un sevrage (total ou partiel) de [count] lapereaux ; si [kits] est renseigné,
  /// une fiche lapin est créée par lapereau sevré (rattachée à la mère et au père, dans la loge
  /// de la mère). Renvoie null en cas de succès, sinon le message d'erreur à afficher.
  Future<String?> weanLitter(
    String litterId, {
    required int count,
    required DateTime weanedAt,
    List<WeanedKit> kits = const [],
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.litterWeanUrl(litterId)),
        headers: _headers(t),
        body: jsonEncode({
          'count': count,
          'weaned_at':
              '${weanedAt.year.toString().padLeft(4, '0')}-${weanedAt.month.toString().padLeft(2, '0')}-${weanedAt.day.toString().padLeft(2, '0')}',
          if (kits.isNotEmpty) 'rabbits': kits.map((k) => k.toJson()).toList(),
        }),
      );
      if (response.statusCode == 200) {
        // Portées, lapins (nouvelles fiches, mère) et cages (🍼) ont changé
        await Future.wait([
          fetchLitters(token: t),
          fetchRabbits(token: t),
          fetchCages(token: t),
        ]);
        return null;
      }
      return _weanError(response);
    } catch (e) {
      debugPrint('Error weaning litter: $e');
      return 'Impossible de joindre le serveur';
    }
  }

  /// Message lisible d'un refus de sevrage ; les erreurs par fiche indiquent le lapereau concerné.
  String _weanError(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final errors = body['errors'];
      if (errors is Map && errors['rabbits'] is Map) {
        final perKit = errors['rabbits'] as Map;
        final first = perKit.entries.first;
        final fieldErrors = first.value is Map ? (first.value as Map).values.first : first.value;
        final text = fieldErrors is List && fieldErrors.isNotEmpty ? fieldErrors.first : fieldErrors;
        final index = int.tryParse('${first.key}');
        return index == null ? '$text' : 'Lapereau ${index + 1} : $text';
      }
    } catch (_) {}
    return _extractError(response);
  }

  /// 4. Soins et Vaccinations
  Future<void> fetchCareEvents({String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(ApiConstants.careEventsUrl),
        headers: _headers(t),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list =
            body['data'] is List
                ? body['data']
                : (body['results'] is List ? body['results'] : []);
        if (list.isNotEmpty) {
          _careEvents = list.map((item) => CareEvent.fromJson(item)).toList();
          notifyListeners();
        }
        _careEvents = list.map((item) => CareEvent.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching care events: $e');
    }
  }

  Future<bool> addCareEvent(CareEvent event, {String? token}) async {
    _careEvents.insert(0, event);
    notifyListeners();

    final t = token ?? _token;
    if (t == null || t.isEmpty) return true;

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.careEventsUrl),
        headers: _headers(t),
        body: jsonEncode(event.toJson()),
      );
      if (response.statusCode == 201) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final created = CareEvent.fromJson(body['data']);
        final idx = _careEvents.indexWhere((c) => c.id == event.id);
        if (idx != -1) {
          _careEvents[idx] = created;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error creating care event: $e');
    }
    return false;
  }

  /// Soins & entretien : types de soins, soins effectués et rappels des prochains soins.
  Future<void> fetchCare({String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    Future<List?> load(String url) async {
      try {
        final response = await http.get(Uri.parse(url), headers: _headers(t));
        if (response.statusCode != 200) return null;
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return body['data'] is List ? body['data'] : const [];
      } catch (e) {
        debugPrint('Error fetching care ($url): $e');
        return null;
      }
    }

    final results = await Future.wait([
      load('${ApiConstants.careTreatmentsUrl}?all=true'),
      load('${ApiConstants.careRecordsUrl}?all=true'),
      load(ApiConstants.careUpcomingUrl),
    ]);
    if (results[0] != null) {
      _careTreatments = [
        for (final j in results[0]!)
          CareTreatment.fromJson(Map<String, dynamic>.from(j)),
      ];
    }
    if (results[1] != null) {
      _careRecords = [
        for (final j in results[1]!)
          CareRecord.fromJson(Map<String, dynamic>.from(j)),
      ];
    }
    if (results[2] != null) {
      _upcomingCares = [
        for (final j in results[2]!)
          UpcomingCare.fromJson(Map<String, dynamic>.from(j)),
      ];
    }
    notifyListeners();
  }

  /// Crée ou modifie (si [id] est fourni) un type de soin.
  /// Retourne null en cas de succès, sinon le message d'erreur à afficher.
  Future<String?> saveCareTreatment({
    String? id,
    required String name,
    required CareCategory category,
    int? renewalDays,
    String? notes,
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';
    try {
      final body = jsonEncode({
        'name': name,
        'category': category.apiValue,
        'renewal_days': renewalDays,
        'notes': notes,
      });
      final response =
          id == null
              ? await http.post(
                Uri.parse(ApiConstants.careTreatmentsUrl),
                headers: _headers(t),
                body: body,
              )
              : await http.patch(
                Uri.parse(ApiConstants.careTreatmentDetailUrl(id)),
                headers: _headers(t),
                body: body,
              );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCare(token: t);
        return null;
      }
      return _extractError(response);
    } catch (e) {
      debugPrint('Error saving care treatment: $e');
      return 'Impossible de joindre le serveur';
    }
  }

  /// Supprime un type de soin jamais utilisé. Retourne null en cas de succès, sinon le motif du refus.
  Future<String?> deleteCareTreatment(String id, {String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';
    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.careTreatmentDetailUrl(id)),
        headers: _headers(t),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchCare(token: t);
        return null;
      }
      return _extractError(response);
    } catch (e) {
      debugPrint('Error deleting care treatment: $e');
      return 'Impossible de joindre le serveur';
    }
  }

  /// Enregistre (ou corrige, si [id] est fourni) un soin effectué sur [rabbitIds] à la date [date].
  /// La prochaine échéance est calculée par le serveur d'après la durée de renouvellement.
  /// Retourne null en cas de succès, sinon le message d'erreur à afficher.
  Future<String?> saveCareRecord({
    String? id,
    required String treatmentId,
    required List<String> rabbitIds,
    required DateTime date,
    String purpose = '',
    String? notes,
    String? token,
  }) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';
    try {
      final body = jsonEncode({
        'treatment': int.tryParse(treatmentId) ?? treatmentId,
        'rabbits': [for (final r in rabbitIds) int.tryParse(r) ?? r],
        'date': isoDate(date),
        'purpose': purpose,
        'notes': notes,
      });
      final response =
          id == null
              ? await http.post(
                Uri.parse(ApiConstants.careRecordsUrl),
                headers: _headers(t),
                body: body,
              )
              : await http.patch(
                Uri.parse(ApiConstants.careRecordDetailUrl(id)),
                headers: _headers(t),
                body: body,
              );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCare(token: t);
        return null;
      }
      return _extractError(response);
    } catch (e) {
      debugPrint('Error saving care record: $e');
      return 'Impossible de joindre le serveur';
    }
  }

  Future<String?> deleteCareRecord(String id, {String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return 'Session expirée';
    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.careRecordDetailUrl(id)),
        headers: _headers(t),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchCare(token: t);
        return null;
      }
      return _extractError(response);
    } catch (e) {
      debugPrint('Error deleting care record: $e');
      return 'Impossible de joindre le serveur';
    }
  }

  /// 5. Finances
  Future<void> fetchFinances({String? token}) async {
    final t = token ?? _token;
    if (t == null || t.isEmpty) return;

    try {
      final response = await http.get(
        // Toutes les transactions : les totaux par période ne doivent pas se limiter à la 1re page
        Uri.parse('${ApiConstants.financesUrl}?all=true'),
        headers: _headers(t),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list =
            body['data'] is List
                ? body['data']
                : (body['results'] is List ? body['results'] : []);
        if (list.isNotEmpty) {
          _finances =
              list.map((item) => FinanceTransaction.fromJson(item)).toList();
          notifyListeners();
        }
        _finances =
            list.map((item) => FinanceTransaction.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching finances: $e');
    }
  }

  Future<bool> addFinanceTransaction(
    FinanceTransaction transaction, {
    String? token,
  }) async {
    _finances.insert(0, transaction);
    notifyListeners();

    final t = token ?? _token;
    if (t == null || t.isEmpty) return true;

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.financesUrl),
        headers: _headers(t),
        body: jsonEncode(transaction.toJson()),
      );
      if (response.statusCode == 201) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final created = FinanceTransaction.fromJson(body['data']);
        final idx = _finances.indexWhere((f) => f.id == transaction.id);
        if (idx != -1) {
          _finances[idx] = created;
          notifyListeners();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error creating finance transaction: $e');
    }
    return false;
  }

  List<Rabbit> getEligibleFathers({String? excludeId}) {
    return _rabbits
        .where((r) => r.gender == RabbitGender.male && r.id != excludeId)
        .toList();
  }

  List<Rabbit> getEligibleMothers({String? excludeId}) {
    return _rabbits
        .where((r) => r.gender == RabbitGender.female && r.id != excludeId)
        .toList();
  }

  List<Rabbit> getChildren(String rabbitId) {
    return _rabbits
        .where((r) => r.sireId == rabbitId || r.damId == rabbitId)
        .toList();
  }

  PedigreeNode buildPedigree(Rabbit rabbit, {int maxDepth = 2}) {
    if (maxDepth <= 0) {
      return PedigreeNode(rabbit: rabbit);
    }

    PedigreeNode? fatherNode;
    if (rabbit.sireId != null) {
      final father = getRabbitById(rabbit.sireId);
      if (father != null) {
        fatherNode = buildPedigree(father, maxDepth: maxDepth - 1);
      }
    }

    PedigreeNode? motherNode;
    if (rabbit.damId != null) {
      final mother = getRabbitById(rabbit.damId);
      if (mother != null) {
        motherNode = buildPedigree(mother, maxDepth: maxDepth - 1);
      }
    }

    return PedigreeNode(rabbit: rabbit, father: fatherNode, mother: motherNode);
  }

  Mating? getNextImminentKindling() {
    final active =
        _matings
            .where(
              (m) =>
                  m.status == MatingStatus.pending ||
                  m.status == MatingStatus.confirmed,
            )
            .toList();
    if (active.isEmpty) return null;
    active.sort(
      (a, b) => a.expectedKindlingDate.compareTo(b.expectedKindlingDate),
    );
    return active.first;
  }

  /// Fixe le jeton sans lancer la synchronisation complète (tests).
  @visibleForTesting
  void setTokenForTesting(String? token) => _token = token;

  @visibleForTesting
  void setLittersForTesting(List<Litter> litters) {
    _litters = List.of(litters);
    notifyListeners();
  }

  @visibleForTesting
  void setFinancesForTesting(List<FinanceTransaction> finances) {
    _finances = List.of(finances);
    notifyListeners();
  }

  @visibleForTesting
  void setCagesForTesting(List<Cage> cages) {
    _cages = List.of(cages);
    notifyListeners();
  }

  // Seed helper reserved for unit testing
  @visibleForTesting
  void seedForTesting() {
    final now = DateTime.now();

    // 1. Grandparents (Generation 0)
    final grandFather1 = Rabbit(
      id: 'gp-m-1',
      name: 'Titan',
      tagNumber: 'FB-2022-01',
      gender: RabbitGender.male,
      breed: 'Fauve de Bourgogne',
      birthDate: now.subtract(const Duration(days: 850)),
      color: 'Fauve chaud',
      cageNumber: 'A-01',
      status: RabbitStatus.active,
      weightKg: 4.8,
      avatarColorIndex: 0,
      notes: 'Grand reproducteur champion de race.',
    );

    final grandMother1 = Rabbit(
      id: 'gp-f-1',
      name: 'Sultane',
      tagNumber: 'FB-2022-02',
      gender: RabbitGender.female,
      breed: 'Fauve de Bourgogne',
      birthDate: now.subtract(const Duration(days: 820)),
      color: 'Fauve unicolore',
      cageNumber: 'A-02',
      status: RabbitStatus.active,
      weightKg: 4.6,
      avatarColorIndex: 1,
      notes: 'Excellente laitière, portées régulières de 8.',
    );

    // 2. Parents (Generation 1)
    final father1 = Rabbit(
      id: 'p-m-1',
      name: 'Flash',
      tagNumber: 'FB-2023-10',
      gender: RabbitGender.male,
      breed: 'Fauve de Bourgogne',
      birthDate: now.subtract(const Duration(days: 480)),
      color: 'Fauve doré',
      cageNumber: 'B-01',
      sireId: grandFather1.id,
      damId: grandMother1.id,
      status: RabbitStatus.active,
      weightKg: 4.5,
      avatarColorIndex: 2,
      notes: 'Mâle très docile et vigoureux.',
    );

    final mother1 = Rabbit(
      id: 'p-f-1',
      name: 'Bella',
      tagNumber: 'FB-2023-14',
      gender: RabbitGender.female,
      breed: 'Fauve de Bourgogne',
      birthDate: now.subtract(const Duration(days: 450)),
      color: 'Fauve vif',
      cageNumber: 'B-04',
      status: RabbitStatus.pregnant,
      weightKg: 4.4,
      avatarColorIndex: 3,
      notes: 'Gestante, boîte à nid déjà inspectée.',
    );

    // Other breeders
    final father2 = Rabbit(
      id: 'p-m-2',
      name: 'Goliath',
      tagNumber: 'GF-2023-05',
      gender: RabbitGender.male,
      breed: 'Géant des Flandres',
      birthDate: now.subtract(const Duration(days: 520)),
      color: 'Gris garenne',
      cageNumber: 'C-01',
      status: RabbitStatus.active,
      weightKg: 7.2,
      avatarColorIndex: 4,
      notes: 'Gabarit exceptionnel, calme.',
    );

    final mother2 = Rabbit(
      id: 'p-f-2',
      name: 'Luna',
      tagNumber: 'NZ-2023-22',
      gender: RabbitGender.female,
      breed: 'Néo-Zélandais',
      birthDate: now.subtract(const Duration(days: 390)),
      color: 'Blanc pur',
      cageNumber: 'B-08',
      status: RabbitStatus.lactating,
      weightKg: 4.2,
      avatarColorIndex: 5,
      notes: 'En allaitement avec sa portée de 7.',
    );

    // 3. Child (Generation 2)
    final youngRabbit = Rabbit(
      id: 'c-m-1',
      name: 'Caramel',
      tagNumber: 'FB-2024-03',
      gender: RabbitGender.male,
      breed: 'Fauve de Bourgogne',
      birthDate: now.subtract(const Duration(days: 90)),
      color: 'Fauve soutenu',
      cageNumber: 'D-02',
      sireId: father1.id,
      damId: mother1.id,
      status: RabbitStatus.active,
      weightKg: 2.8,
      avatarColorIndex: 6,
      notes: 'Futur reproducteur prometteur.',
    );

    _rabbits.addAll([
      mother1,
      father1,
      mother2,
      father2,
      youngRabbit,
      grandFather1,
      grandMother1,
    ]);

    // Matings
    // Imminent birth in 2 days (mating 29 days ago)
    _matings.add(
      Mating(
        id: 'mat-1',
        maleId: father1.id,
        femaleId: mother1.id,
        matingDate: now.subtract(const Duration(days: 29)),
        status: MatingStatus.confirmed,
        notes: 'Saillie réussie, 2 sauts observés. Boîte à nid installée.',
      ),
    );

    // Recent mating
    _matings.add(
      Mating(
        id: 'mat-2',
        maleId: father2.id,
        femaleId: mother2.id,
        matingDate: now.subtract(const Duration(days: 8)),
        status: MatingStatus.pending,
        notes: 'Palpation prévue dans 4 jours.',
      ),
    );

    // Litters
    _litters.add(
      Litter(
        id: 'lit-1',
        motherId: mother2.id,
        fatherId: father2.id,
        birthDate: now.subtract(const Duration(days: 18)),
        bornAlive: 7,
        stillBorn: 1,
        notes: 'Nid bien garni de poils, lapereaux vigoureux.',
      ),
    );

    // Care events
    _careEvents.addAll([
      CareEvent(
        id: 'care-1',
        rabbitId: mother1.id,
        type: CareType.checkup,
        title: 'Contrôle boîte à nid & litière propre',
        date: now.subtract(const Duration(days: 1)),
        isCompleted: true,
      ),
      CareEvent(
        id: 'care-2',
        rabbitId: father1.id,
        type: CareType.vaccine,
        title: 'Rappel annuel VHD 1 & 2',
        date: now.add(const Duration(days: 3)),
        reminderDate: now.add(const Duration(days: 2)),
        isCompleted: false,
        notes: 'Vaccin Filavac VHD C+K',
      ),
      CareEvent(
        id: 'care-3',
        rabbitId: youngRabbit.id,
        type: CareType.coccidiosis,
        title: 'Cure préventive anti-coccidiose',
        date: now.add(const Duration(days: 5)),
        isCompleted: false,
      ),
    ]);

    // Finances
    _finances.addAll([
      FinanceTransaction(
        id: 'fin-1',
        type: TransactionType.income,
        title: 'Vente 2 jeunes reproducteurs FB',
        amount: 80.0,
        date: now.subtract(const Duration(days: 3)),
        category: 'Vente reproducteurs',
      ),
      FinanceTransaction(
        id: 'fin-2',
        type: TransactionType.expense,
        title: 'Sac 25kg granulés élevage + luzerne',
        amount: 32.5,
        date: now.subtract(const Duration(days: 6)),
        category: 'Alimentation',
      ),
      FinanceTransaction(
        id: 'fin-3',
        type: TransactionType.expense,
        title: 'Vaccins Filavac (5 doses)',
        amount: 45.0,
        date: now.subtract(const Duration(days: 10)),
        category: 'Vétérinaire / Soins',
      ),
    ]);
  }
}

/// Un lapereau sevré pour lequel on crée une fiche lapin.
class WeanedKit {
  final String name;
  final String tagNumber;
  final RabbitGender gender;
  final String? color;

  const WeanedKit({
    required this.name,
    required this.tagNumber,
    required this.gender,
    this.color,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'tag_number': tagNumber,
        'gender': gender == RabbitGender.male ? 'M' : 'F',
        if (color != null && color!.isNotEmpty) 'color': color,
      };
}
