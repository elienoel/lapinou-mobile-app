import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/promo_carousel.dart';
import '../services/api_constants.dart';

/// Carrousels d'annonces de la page d'accueil (endpoint public, lecture
/// seule). Comme la pharmacie : le dernier résultat est gardé en cache et
/// affiché tout de suite, puis remplacé par la réponse du serveur.
class PromotionsProvider extends ChangeNotifier {
  PromotionsProvider({http.Client? client}) : _client = client;

  final http.Client? _client;
  List<PromoCarousel> _carousels = [];
  bool _cacheLoaded = false;

  static const _cacheKey = 'cached_promo_carousels';

  /// Carrousels à afficher, dans l'ordre (ceux sans image sont exclus).
  List<PromoCarousel> get carousels => List.unmodifiable(_carousels);

  List<PromoCarousel> _parse(List list) =>
      [
        for (final e in list)
          PromoCarousel.fromJson(Map<String, dynamic>.from(e as Map)),
      ].where((c) => c.slides.isNotEmpty).toList();

  Future<void> fetchCarousels() async {
    if (!_cacheLoaded) {
      _cacheLoaded = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(_cacheKey);
        if (cached != null && _carousels.isEmpty) {
          _carousels = _parse(jsonDecode(cached) as List);
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error loading cached carousels: $e');
      }
    }

    try {
      final uri = Uri.parse(ApiConstants.promoCarouselsUrl);
      final client = _client;
      final response =
          client != null ? await client.get(uri) : await http.get(uri);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      final List list = body['data'] is List ? body['data'] : const [];
      _carousels = _parse(list);
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(list));
    } catch (e) {
      // Hors ligne : on garde le cache
      debugPrint('Error fetching carousels: $e');
    }
  }
}
