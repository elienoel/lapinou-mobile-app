import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';
import '../models/pharmacy.dart';
import '../services/api_constants.dart';
import '../services/connectivity_service.dart';

/// Catalogue pharmacie (médicaments + répertoire de pharmacies) : référentiel
/// partagé entre tous les utilisateurs, lecture seule depuis l'app (géré via
/// l'admin Django). Provider dédié plutôt que RabbitProvider : aucune écriture,
/// aucune synchronisation hors-ligne nécessaire, pas de token requis (endpoints
/// publics). Même logique de cache que `RabbitProvider.fetchBreeds` (l'autre
/// référentiel partagé) : cache JSON brut en SharedPreferences, affiché
/// immédiatement, puis rafraîchi depuis le réseau si en ligne.
class PharmacyProvider extends ChangeNotifier {
  List<Medication> _medications = [];
  List<Pharmacy> _pharmacies = [];
  bool _isLoading = false;

  List<Medication> get medications => List.unmodifiable(_medications);
  List<Pharmacy> get pharmacies => List.unmodifiable(_pharmacies);
  bool get isLoading => _isLoading;

  static const _cachedMedicationsKey = 'cached_medications';
  static const _cachedPharmaciesKey = 'cached_pharmacies';

  Future<void> fetchAll() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([fetchMedications(), fetchPharmacies()]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMedications() async {
    if (_medications.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cachedMedicationsKey);
        if (cached != null) {
          final List list = jsonDecode(cached);
          _medications =
              list
                  .map((e) => Medication.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error loading cached medications: $e');
      }
    }

    if (!await ConnectivityService.instance.isOnline()) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.medicationsUrl}?all=true'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list = body['data'] is List ? body['data'] : [];
        _medications =
            list
                .map((e) => Medication.fromJson(Map<String, dynamic>.from(e)))
                .toList();
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cachedMedicationsKey, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('Error fetching medications: $e');
    }
  }

  Future<void> fetchPharmacies() async {
    if (_pharmacies.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cachedPharmaciesKey);
        if (cached != null) {
          final List list = jsonDecode(cached);
          _pharmacies =
              list
                  .map((e) => Pharmacy.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error loading cached pharmacies: $e');
      }
    }

    if (!await ConnectivityService.instance.isOnline()) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.pharmaciesUrl}?all=true'),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        final List list = body['data'] is List ? body['data'] : [];
        _pharmacies =
            list
                .map((e) => Pharmacy.fromJson(Map<String, dynamic>.from(e)))
                .toList();
        notifyListeners();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cachedPharmaciesKey, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('Error fetching pharmacies: $e');
    }
  }

  /// Détail enrichi (bande de prix + pharmacies) : toujours en ligne, pas mis en
  /// cache — la liste suffit hors-ligne, le détail n'est qu'un confort en ligne.
  Future<Medication?> fetchMedicationDetail(String id) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.medicationDetailUrl(id)),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return Medication.fromJson(Map<String, dynamic>.from(body['data']));
      }
    } catch (e) {
      debugPrint('Error fetching medication detail: $e');
    }
    return null;
  }

  Future<Pharmacy?> fetchPharmacyDetail(String id) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.pharmacyDetailUrl(id)),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(utf8.decode(response.bodyBytes));
        return Pharmacy.fromJson(Map<String, dynamic>.from(body['data']));
      }
    } catch (e) {
      debugPrint('Error fetching pharmacy detail: $e');
    }
    return null;
  }
}
