import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat.dart';
import '../services/api_constants.dart';

/// Messagerie privée entre éleveurs. Le serveur est interrogé régulièrement
/// (pastille de non-lus ici, messages d'une discussion dans l'écran ouvert).
class ChatProvider extends ChangeNotifier {
  ChatProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _token;
  Timer? _unreadTimer;

  List<ChatConversation> _conversations = [];
  int _unreadTotal = 0;
  bool _isLoading = false;

  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  int get unreadTotal => _unreadTotal;
  bool get isLoading => _isLoading;

  static const _unreadPollInterval = Duration(seconds: 20);

  /// Appelé à la connexion / déconnexion : démarre ou arrête la surveillance des non-lus.
  void setToken(String? token) {
    if (_token == token) return;
    _token = token;
    _unreadTimer?.cancel();
    _unreadTimer = null;

    if (token == null || token.isEmpty) {
      _conversations = [];
      _unreadTotal = 0;
      notifyListeners();
      return;
    }
    fetchUnread();
    _unreadTimer = Timer.periodic(_unreadPollInterval, (_) => fetchUnread());
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    _client.close();
    super.dispose();
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  bool get _hasToken => _token != null && _token!.isNotEmpty;

  dynamic _decode(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  Future<void> fetchUnread() async {
    if (!_hasToken) return;
    try {
      final r = await _client.get(Uri.parse(ApiConstants.chatUnreadUrl), headers: _headers);
      if (r.statusCode == 200) {
        final n = _decode(r)['data']['unread'];
        final value = n is int ? n : 0;
        if (value != _unreadTotal) {
          _unreadTotal = value;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Chat unread error: $e');
    }
  }

  Future<void> fetchConversations() async {
    if (!_hasToken) return;
    _isLoading = _conversations.isEmpty;
    if (_isLoading) notifyListeners();
    try {
      final r = await _client.get(Uri.parse(ApiConstants.chatConversationsUrl), headers: _headers);
      if (r.statusCode == 200) {
        final list = _decode(r)['data'] as List;
        _conversations = list
            .map((c) => ChatConversation.fromJson(Map<String, dynamic>.from(c)))
            .toList();
        _unreadTotal = _conversations.fold(0, (sum, c) => sum + c.unread);
      }
    } catch (e) {
      debugPrint('Chat conversations error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Ouvre (ou retrouve) la discussion avec un éleveur.
  Future<ChatConversation?> openConversation(int userId) async {
    if (!_hasToken) return null;
    try {
      final r = await _client.post(
        Uri.parse(ApiConstants.chatConversationsUrl),
        headers: _headers,
        body: jsonEncode({'user': userId}),
      );
      if (r.statusCode == 200 || r.statusCode == 201) {
        return ChatConversation.fromJson(
            Map<String, dynamic>.from(_decode(r)['data']));
      }
    } catch (e) {
      debugPrint('Chat open error: $e');
    }
    return null;
  }

  /// Messages d'une discussion. Sans paramètre : les plus récents ; [afterId] : uniquement les
  /// nouveaux ; [beforeId] : l'historique plus ancien. Renvoie null en cas d'erreur réseau.
  /// Lire une discussion la marque comme lue côté serveur.
  Future<ChatPage?> fetchMessages(
    int conversationId, {
    int? afterId,
    int? beforeId,
    int limit = 50,
  }) async {
    if (!_hasToken) return null;
    final query = {
      'limit': '$limit',
      if (afterId != null) 'after_id': '$afterId',
      if (beforeId != null) 'before_id': '$beforeId',
    };
    try {
      final uri = Uri.parse(ApiConstants.chatMessagesUrl(conversationId))
          .replace(queryParameters: query);
      final r = await _client.get(uri, headers: _headers);
      if (r.statusCode != 200) return null;

      final data = _decode(r)['data'];
      final messages = (data['messages'] as List)
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      // La discussion est lue : sa pastille disparaît tout de suite
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx != -1 && _conversations[idx].unread > 0) {
        _unreadTotal = (_unreadTotal - _conversations[idx].unread).clamp(0, 1 << 30);
        _conversations[idx].unread = 0;
        notifyListeners();
      }
      if (afterId == null && beforeId == null) fetchUnread();

      return ChatPage(
        messages: messages,
        hasMore: data['has_more'] == true,
        myReadUpTo: data['my_read_up_to'] is int ? data['my_read_up_to'] as int : null,
      );
    } catch (e) {
      debugPrint('Chat messages error: $e');
      return null;
    }
  }

  /// Envoie un message (texte et/ou photo). Renvoie le message enregistré, ou lance une
  /// [ChatSendException] avec un texte lisible.
  Future<ChatMessage> sendMessage(
    int conversationId, {
    String text = '',
    File? image,
    File? audio,
    int? audioDurationMs,
  }) async {
    if (!_hasToken) throw ChatSendException('Vous n\'êtes pas connecté.');
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse(ApiConstants.chatMessagesUrl(conversationId)));
      request.headers['Authorization'] = 'Bearer $_token';
      request.fields['content'] = text;
      if (image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', image.path));
      }
      if (audio != null) {
        request.files.add(await http.MultipartFile.fromPath('audio', audio.path));
        if (audioDurationMs != null) {
          request.fields['audio_duration_ms'] = '$audioDurationMs';
        }
      }
      final r = await http.Response.fromStream(await _client.send(request));

      if (r.statusCode == 201) {
        final sent = ChatMessage.fromJson(Map<String, dynamic>.from(_decode(r)['data']));
        _bumpConversation(conversationId, sent);
        return sent;
      }
      throw ChatSendException(_errorText(_decode(r)));
    } on ChatSendException {
      rethrow;
    } catch (e) {
      debugPrint('Chat send error: $e');
      throw ChatSendException('Connexion au serveur impossible.');
    }
  }

  /// Fait remonter la discussion en tête de liste avec le message qui vient d'être envoyé.
  void _bumpConversation(int id, ChatMessage sent) {
    final idx = _conversations.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    final c = _conversations.removeAt(idx);
    c.last = ChatPreview(
      senderId: sent.senderId,
      content: sent.content,
      hasImage: sent.hasImage,
      hasAudio: sent.hasAudio,
      createdAt: sent.createdAt,
    );
    c.updatedAt = sent.createdAt;
    _conversations.insert(0, c);
    notifyListeners();
  }

  String _errorText(dynamic data) {
    try {
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        return (first is List ? first.first : first).toString();
      }
      return data['message']?['default']?.toString() ?? 'Envoi impossible.';
    } catch (_) {
      return 'Envoi impossible.';
    }
  }

  /// Recherche d'éleveurs pour démarrer une discussion.
  Future<List<ChatUser>> searchUsers(String term) async {
    if (!_hasToken) return [];
    try {
      final uri = Uri.parse(ApiConstants.chatUsersUrl)
          .replace(queryParameters: {'search': term.trim()});
      final r = await _client.get(uri, headers: _headers);
      if (r.statusCode == 200) {
        return (_decode(r)['data'] as List)
            .map((u) => ChatUser.fromJson(Map<String, dynamic>.from(u)))
            .toList();
      }
    } catch (e) {
      debugPrint('Chat search error: $e');
    }
    return [];
  }
}

class ChatSendException implements Exception {
  final String message;
  ChatSendException(this.message);
  @override
  String toString() => message;
}
