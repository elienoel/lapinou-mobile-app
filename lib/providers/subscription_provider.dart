import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import '../services/api_constants.dart';

/// Formule d'abonnement de l'éleveur. Le dernier état connu est gardé en cache
/// pour appliquer la limite de fiches même hors ligne ; le serveur reste
/// l'arbitre final (il refuse toute création au-delà de la formule).
class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider({http.Client? client}) : _client = client;

  final http.Client? _client;
  String? _token;
  SubscriptionStatus? _status;
  bool _cacheLoaded = false;

  static const _cacheKey = 'cached_subscription_status';

  SubscriptionStatus? get status => _status;

  void setToken(String? token) {
    if (token == _token) return;
    _token = token;
    if (token == null) {
      _status = null;
      notifyListeners();
    }
  }

  @visibleForTesting
  void setStatusForTesting(SubscriptionStatus status) {
    _status = status;
    _cacheLoaded = true;
    notifyListeners();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null && _token!.isNotEmpty) 'Authorization': 'Bearer $_token',
  };

  Future<http.Response> _post(String url, [Map<String, dynamic>? body]) {
    final uri = Uri.parse(url);
    final encoded = body == null ? null : jsonEncode(body);
    final c = _client;
    return c != null
        ? c.post(uri, headers: _headers, body: encoded)
        : http.post(uri, headers: _headers, body: encoded);
  }

  Future<void> _loadCache() async {
    if (_cacheLoaded) return;
    _cacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null && _status == null) {
        _status = SubscriptionStatus.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached subscription: $e');
    }
  }

  Future<void> _store(Map<String, dynamic> json) async {
    _status = SubscriptionStatus.fromJson(json);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(json));
    } catch (_) {}
  }

  Future<void> fetch() async {
    await _loadCache();
    if (_token == null) return;
    try {
      final uri = Uri.parse(ApiConstants.subscriptionStatusUrl);
      final c = _client;
      final response =
          c != null
              ? await c.get(uri, headers: _headers)
              : await http.get(uri, headers: _headers);
      if (response.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body['data'] is Map) {
        await _store(Map<String, dynamic>.from(body['data'] as Map));
      }
    } catch (e) {
      // Hors ligne : on garde le dernier état connu
      debugPrint('Error fetching subscription: $e');
    }
  }

  /// Démarre le paiement d'un mois de [plan] ; renvoie le paiement à ouvrir,
  /// ou lève [SubscriptionException] avec un message lisible.
  Future<SubscriptionCheckout> startCheckout(String plan) async {
    final http.Response response;
    try {
      response = await _post(ApiConstants.subscriptionCheckoutUrl, {
        'plan': plan,
      });
    } catch (_) {
      throw const SubscriptionException(
        'Connexion impossible : le paiement demande internet.',
      );
    }
    final body = _decode(response);
    if (response.statusCode == 201 && body['data'] is Map) {
      final checkout = SubscriptionCheckout.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
      if (checkout.checkoutUrl.isNotEmpty) return checkout;
    }
    throw SubscriptionException(_message(body, response.statusCode));
  }

  /// Relit le statut d'un paiement (au retour de la page de paiement) et met
  /// la formule à jour. Renvoie le paiement, ou null si le serveur est injoignable.
  Future<SubscriptionCheckout?> refreshPayment(String reference) async {
    try {
      final response = await _post(
        ApiConstants.subscriptionPaymentRefreshUrl(reference),
      );
      if (response.statusCode != 200) return null;
      final data = _decode(response)['data'];
      if (data is! Map) return null;
      if (data['subscription'] is Map) {
        await _store(Map<String, dynamic>.from(data['subscription'] as Map));
      }
      return data['payment'] is Map
          ? SubscriptionCheckout.fromJson(
            Map<String, dynamic>.from(data['payment'] as Map),
          )
          : null;
    } catch (e) {
      debugPrint('Error refreshing payment: $e');
      return null;
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map<String, dynamic> ? body : {};
    } catch (_) {
      return {};
    }
  }

  static String _message(Map<String, dynamic> body, int status) {
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      return first is List && first.isNotEmpty ? '${first.first}' : '$first';
    }
    final msg = body['message'];
    if (msg is Map) {
      final details = msg['details']?.toString() ?? '';
      if (details.isNotEmpty) return details;
      if (msg['default'] != null) return '${msg['default']}';
    }
    return 'Paiement impossible (erreur $status).';
  }
}

class SubscriptionException implements Exception {
  final String message;
  const SubscriptionException(this.message);

  @override
  String toString() => message;
}
