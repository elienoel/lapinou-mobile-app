import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/marketplace_listing.dart';
import '../services/api_constants.dart';

/// Petites annonces entre éleveurs. Données partagées entre tous les comptes,
/// donc lues et écrites en ligne uniquement (pas de file hors-ligne).
class MarketplaceProvider extends ChangeNotifier {
  MarketplaceProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;

  List<MarketplaceListing> _listings = [];
  bool _isLoading = false;
  String? _error;

  List<MarketplaceListing> get listings => List.unmodifiable(_listings);
  bool get isLoading => _isLoading;

  /// Erreur du dernier chargement (null si tout va bien)
  String? get error => _error;

  /// Annonces encore disponibles (compteur de la carte d'accueil)
  int get availableCount => _listings.where((l) => l.isAvailable).length;

  void setToken(String? token) {
    if (token == _token) return;
    _token = token;
    if (token == null) {
      _listings = [];
      _error = null;
    }
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static dynamic _decode(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  /// Premier message d'erreur de champ renvoyé par l'API, sinon le message général
  static String _errorFrom(http.Response r, String fallback) {
    try {
      final data = _decode(r);
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        return (first is List ? first.first : first).toString();
      }
      return data['message']?['default'] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> fetchListings() async {
    _isLoading = true;
    notifyListeners();
    try {
      final r = await _client.get(
        Uri.parse('${ApiConstants.marketplaceUrl}?all=true&order_by=-created_at'),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        final List list = _decode(r)['data'] ?? [];
        _listings =
            list
                .map(
                  (e) =>
                      MarketplaceListing.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
        _error = null;
      } else {
        _error = 'Impossible de charger les annonces.';
      }
    } catch (e) {
      debugPrint('Marketplace fetch error: $e');
      _error = 'Pas de connexion : les annonces ne peuvent pas être chargées.';
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Crée ([existing] null) ou modifie une annonce. [photo] remplace la photo.
  /// Renvoie null en cas de succès, sinon le message d'erreur.
  Future<String?> saveListing({
    MarketplaceListing? existing,
    required String title,
    required ListingType type,
    required String description,
    double? price,
    String? location,
    File? photo,
  }) async {
    if (_token == null) return 'Vous n\'êtes pas connecté.';
    try {
      final request = http.MultipartRequest(
        existing == null ? 'POST' : 'PATCH',
        Uri.parse(
          existing == null
              ? ApiConstants.marketplaceUrl
              : ApiConstants.marketplaceDetailUrl(existing.id),
        ),
      );
      request.headers['Authorization'] = 'Bearer $_token';
      request.fields.addAll({
        'title': title.trim(),
        'listing_type': type.api,
        'description': description.trim(),
        // Champ vide = pas de prix (« à débattre »)
        'price': price == null ? '' : price.toStringAsFixed(2),
        'location': location?.trim() ?? '',
      });
      if (photo != null) {
        request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
      }

      final r = await http.Response.fromStream(await _client.send(request));
      if (r.statusCode == 200 || r.statusCode == 201) {
        final saved = MarketplaceListing.fromJson(
          Map<String, dynamic>.from(_decode(r)['data']),
        );
        _replaceOrInsert(saved);
        return null;
      }
      return _errorFrom(r, 'L\'annonce n\'a pas pu être enregistrée.');
    } catch (e) {
      debugPrint('Marketplace save error: $e');
      return 'Pas de connexion : réessayez une fois en ligne.';
    }
  }

  /// Passe une annonce à Disponible / Réservé / Vendu.
  Future<String?> setStatus(
    MarketplaceListing listing,
    ListingStatus status,
  ) async {
    try {
      final r = await _client.patch(
        Uri.parse(ApiConstants.marketplaceDetailUrl(listing.id)),
        headers: _headers,
        body: jsonEncode({'status': status.api}),
      );
      if (r.statusCode == 200) {
        _replaceOrInsert(
          MarketplaceListing.fromJson(
            Map<String, dynamic>.from(_decode(r)['data']),
          ),
        );
        return null;
      }
      return _errorFrom(r, 'Le statut n\'a pas pu être modifié.');
    } catch (e) {
      return 'Pas de connexion : réessayez une fois en ligne.';
    }
  }

  Future<String?> deleteListing(MarketplaceListing listing) async {
    try {
      final r = await _client.delete(
        Uri.parse(ApiConstants.marketplaceDetailUrl(listing.id)),
        headers: _headers,
      );
      if (r.statusCode == 200 || r.statusCode == 204) {
        _listings.removeWhere((l) => l.id == listing.id);
        notifyListeners();
        return null;
      }
      return _errorFrom(r, 'L\'annonce n\'a pas pu être supprimée.');
    } catch (e) {
      return 'Pas de connexion : réessayez une fois en ligne.';
    }
  }

  void _replaceOrInsert(MarketplaceListing listing) {
    final i = _listings.indexWhere((l) => l.id == listing.id);
    if (i >= 0) {
      _listings[i] = listing;
    } else {
      _listings.insert(0, listing);
    }
    notifyListeners();
  }
}
