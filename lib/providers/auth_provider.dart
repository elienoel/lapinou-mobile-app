import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency.dart';
import '../services/api_constants.dart';

class AuthUser {
  final int id;
  final String username;
  final String? phoneNumber;
  final String? farmName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? avatar;
  final String? location;
  final String? bio;
  final String currency;
  final DateTime? createdAt;

  AuthUser({
    required this.id,
    required this.username,
    this.phoneNumber,
    this.farmName,
    this.firstName,
    this.lastName,
    this.email,
    this.avatar,
    this.location,
    this.bio,
    this.currency = 'EUR',
    this.createdAt,
  });

  AuthUser copyWith({String? currency}) => AuthUser(
        id: id,
        username: username,
        phoneNumber: phoneNumber,
        farmName: farmName,
        firstName: firstName,
        lastName: lastName,
        email: email,
        avatar: avatar,
        location: location,
        bio: bio,
        currency: currency ?? this.currency,
        createdAt: createdAt,
      );

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      username: json['username'] ?? '',
      phoneNumber: json['phone_number'],
      farmName: json['farm_name'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      email: json['email'],
      avatar: json['avatar'],
      location: json['location'],
      bio: json['bio'],
      currency: (json['currency'] ?? 'EUR').toString(),
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'phone_number': phoneNumber,
    'farm_name': farmName,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'avatar': avatar,
    'location': location,
    'bio': bio,
    'currency': currency,
    'created_at': createdAt?.toIso8601String(),
  };

  String get displayName {
    if (farmName != null && farmName!.isNotEmpty) return farmName!;
    if (firstName != null && firstName!.isNotEmpty) {
      return '$firstName ${lastName ?? ''}'.trim();
    }
    return phoneNumber ?? username;
  }
}

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingPhoneNumber;

  AuthUser? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get pendingPhoneNumber => _pendingPhoneNumber;
  bool get isAuthenticated => _token != null && _user != null;

  /// Devise d'affichage des montants (paramètre du compte, euro par défaut)
  AppCurrency get currency => currencyByCode(_user?.currency);

  AuthProvider() {
    _loadStoredSession();
  }

  Future<void> _loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('auth_token');
      final savedUserData = prefs.getString('user_data');

      if (savedToken != null && savedUserData != null) {
        _token = savedToken;
        _user = AuthUser.fromJson(jsonDecode(savedUserData));
        notifyListeners();
        refreshProfile();
      }
    } catch (e) {
      debugPrint('Erreur chargement session: $e');
    }
  }

  /// 1. Demande d'envoi du code OTP
  Future<bool> requestOtp(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    _pendingPhoneNumber = phoneNumber.trim();
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.requestOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': _pendingPhoneNumber}),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      _isLoading = false;

      if (response.statusCode == 200 && data['success'] == true) {
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            data['message']?['default'] ?? 'Erreur lors de l\'envoi du code';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage =
          'Connexion au serveur impossible. Vérifiez votre connexion.';
      notifyListeners();
      return false;
    }
  }

  /// 2. Vérification de l'OTP et connexion
  Future<bool> verifyOtp({
    required String otpCode,
    String? farmName,
    String? firstName,
    String? lastName,
  }) async {
    if (_pendingPhoneNumber == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.verifyOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone_number': _pendingPhoneNumber,
          'otp_code': otpCode.trim(),
          if (farmName != null && farmName.isNotEmpty) 'farm_name': farmName,
          if (firstName != null && firstName.isNotEmpty)
            'first_name': firstName,
          if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      _isLoading = false;

      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'];
        _token = payload['token'];
        _user = AuthUser.fromJson(payload['user']);

        // Sauvegarder la session localement
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_data', jsonEncode(_user!.toJson()));

        notifyListeners();
        return true;
      } else {
        _errorMessage =
            data['message']?['default'] ?? 'Code de vérification invalide';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Erreur lors de la validation du code';
      notifyListeners();
      return false;
    }
  }

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> _saveUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(_user!.toJson()));
  }

  /// Message d'erreur lisible depuis une réponse d'API (premier message de champ, sinon message général)
  String _errorFrom(dynamic data, String fallback) {
    try {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        final text = first is List ? first.first : first;
        return text.toString();
      }
      return data['message']?['default'] ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Recharge le profil depuis le serveur (photo, nom… modifiés ailleurs)
  Future<void> refreshProfile() async {
    if (_token == null) return;
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.currentUserUrl),
        headers: _authHeaders,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _user = AuthUser.fromJson(data['data']);
        await _saveUser();
        notifyListeners();
      } else if (response.statusCode == 401) {
        // Session expirée : retour à l'écran de connexion
        await logout();
      }
    } catch (e) {
      debugPrint('Erreur rafraîchissement profil: $e');
    }
  }

  /// Met à jour les informations du profil. Renvoie null en cas de succès, sinon le message d'erreur.
  Future<String?> updateProfile({
    required String firstName,
    required String lastName,
    required String farmName,
    required String location,
    required String email,
    required String bio,
  }) async {
    if (_token == null) return 'Vous n\'êtes pas connecté.';
    try {
      final response = await http.patch(
        Uri.parse(ApiConstants.currentUserUrl),
        headers: _authHeaders,
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'farm_name': farmName,
          'location': location,
          'email': email,
          'bio': bio,
        }),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true) {
        _user = AuthUser.fromJson(data['data']);
        await _saveUser();
        notifyListeners();
        return null;
      }
      return _errorFrom(data, 'Impossible d\'enregistrer le profil.');
    } catch (e) {
      return 'Connexion au serveur impossible. Vérifiez votre connexion.';
    }
  }

  /// Envoie une nouvelle photo de profil. Renvoie null en cas de succès, sinon le message d'erreur.
  Future<String?> updateAvatar(File photo) async {
    if (_token == null) return 'Vous n\'êtes pas connecté.';
    try {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse(ApiConstants.currentUserUrl),
      );
      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(
        await http.MultipartFile.fromPath('avatar', photo.path),
      );
      final response = await http.Response.fromStream(await request.send());
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true) {
        _user = AuthUser.fromJson(data['data']);
        await _saveUser();
        notifyListeners();
        return null;
      }
      return _errorFrom(data, 'Impossible d\'envoyer la photo.');
    } catch (e) {
      return 'Connexion au serveur impossible. Vérifiez votre connexion.';
    }
  }

  Future<String?> removeAvatar() async {
    if (_token == null) return 'Vous n\'êtes pas connecté.';
    try {
      final response = await http.patch(
        Uri.parse(ApiConstants.currentUserUrl),
        headers: _authHeaders,
        body: jsonEncode({'remove_avatar': true}),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true) {
        _user = AuthUser.fromJson(data['data']);
        await _saveUser();
        notifyListeners();
        return null;
      }
      return _errorFrom(data, 'Impossible de supprimer la photo.');
    } catch (e) {
      return 'Connexion au serveur impossible. Vérifiez votre connexion.';
    }
  }

  /// Supprime définitivement le compte et ses données. Renvoie null en cas de succès.
  Future<String?> deleteAccount() async {
    if (_token == null) return 'Vous n\'êtes pas connecté.';
    try {
      final request =
          http.Request('DELETE', Uri.parse(ApiConstants.currentUserUrl))
            ..headers.addAll(_authHeaders)
            ..body = jsonEncode({'confirm': true});
      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode == 200 || response.statusCode == 204) {
        await logout();
        return null;
      }
      return _errorFrom(
        jsonDecode(utf8.decode(response.bodyBytes)),
        'Impossible de supprimer le compte.',
      );
    } catch (e) {
      return 'Connexion au serveur impossible. Vérifiez votre connexion.';
    }
  }

  /// Change la devise d'affichage. Prise en compte tout de suite, puis enregistrée sur le compte ;
  /// en cas d'échec l'ancienne devise est rétablie. Renvoie null en cas de succès.
  Future<String?> updateCurrency(String code) async {
    final user = _user;
    if (user == null || _token == null) return 'Vous n\'êtes pas connecté.';
    if (user.currency == code) return null;

    _user = user.copyWith(currency: code);
    notifyListeners();
    await _saveUser();

    try {
      final response = await http.patch(
        Uri.parse(ApiConstants.currentUserUrl),
        headers: _authHeaders,
        body: jsonEncode({'currency': code}),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 && data['success'] == true) return null;
      return _rollbackCurrency(user, _errorFrom(data, 'Impossible d\'enregistrer la devise.'));
    } catch (e) {
      return _rollbackCurrency(user, 'Connexion au serveur impossible. La devise n\'a pas été modifiée.');
    }
  }

  String _rollbackCurrency(AuthUser previous, String message) {
    _user = previous;
    notifyListeners();
    _saveUser();
    return message;
  }

  /// Déconnexion
  Future<void> logout() async {
    _token = null;
    _user = null;
    _pendingPhoneNumber = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    notifyListeners();
  }
}
