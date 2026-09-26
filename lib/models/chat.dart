import '../services/api_constants.dart';

int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

DateTime _asDate(dynamic v) =>
    (v != null ? DateTime.tryParse(v.toString()) : null)?.toLocal() ?? DateTime.now();

class ChatUser {
  final int id;
  final String name;
  final String? farmName;
  final String? location;
  final String? avatar;

  const ChatUser({
    required this.id,
    required this.name,
    this.farmName,
    this.location,
    this.avatar,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
        id: _asInt(json['id']),
        name: (json['name'] ?? 'Éleveur').toString(),
        farmName: json['farm_name']?.toString(),
        location: json['location']?.toString(),
        avatar: json['avatar']?.toString(),
      );
}

class ChatMessage {
  /// Identifiant serveur ; 0 tant que le message n'est pas confirmé par le serveur
  final int id;
  final int senderId;
  final String content;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDurationMs;
  final DateTime createdAt;
  bool isRead;

  /// Envoi local en cours ou échoué (messages « optimistes »)
  final String? localId;
  bool sending;
  bool failed;

  /// Photo choisie sur l'appareil, pour l'afficher pendant l'envoi
  final String? localImagePath;

  /// Note vocale enregistrée sur l'appareil, pour la lire pendant l'envoi
  final String? localAudioPath;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.content = '',
    this.imageUrl,
    this.audioUrl,
    this.audioDurationMs,
    required this.createdAt,
    this.isRead = false,
    this.localId,
    this.sending = false,
    this.failed = false,
    this.localImagePath,
    this.localAudioPath,
  });

  bool get hasImage =>
      (imageUrl != null && imageUrl!.isNotEmpty) ||
      (localImagePath != null && localImagePath!.isNotEmpty);

  bool get hasAudio =>
      (audioUrl != null && audioUrl!.isNotEmpty) ||
      (localAudioPath != null && localAudioPath!.isNotEmpty);

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: _asInt(json['id']),
        senderId: _asInt(json['sender']),
        content: (json['content'] ?? '').toString(),
        imageUrl: json['image'] == null
            ? null
            : ApiConstants.formatMediaUrl(json['image'].toString()),
        audioUrl: json['audio'] == null
            ? null
            : ApiConstants.formatMediaUrl(json['audio'].toString()),
        audioDurationMs:
            json['audio_duration_ms'] == null ? null : _asInt(json['audio_duration_ms']),
        createdAt: _asDate(json['created_at']),
        isRead: json['is_read'] == true,
      );
}

/// Aperçu du dernier message d'une discussion
class ChatPreview {
  final int senderId;
  final String content;
  final bool hasImage;
  final bool hasAudio;
  final DateTime createdAt;

  const ChatPreview({
    required this.senderId,
    required this.content,
    required this.hasImage,
    this.hasAudio = false,
    required this.createdAt,
  });

  String get text {
    if (content.trim().isNotEmpty) return content;
    if (hasAudio) return '🎤 Message vocal';
    return '📷 Photo';
  }

  factory ChatPreview.fromJson(Map<String, dynamic> json) => ChatPreview(
        senderId: _asInt(json['sender']),
        content: (json['content'] ?? '').toString(),
        hasImage: json['has_image'] == true,
        hasAudio: json['has_audio'] == true,
        createdAt: _asDate(json['created_at']),
      );
}

class ChatConversation {
  final int id;
  final ChatUser other;
  ChatPreview? last;
  int unread;
  DateTime updatedAt;

  ChatConversation({
    required this.id,
    required this.other,
    this.last,
    this.unread = 0,
    required this.updatedAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) => ChatConversation(
        id: _asInt(json['id']),
        other: ChatUser.fromJson(Map<String, dynamic>.from(json['other_user'])),
        last: json['last_message'] == null
            ? null
            : ChatPreview.fromJson(Map<String, dynamic>.from(json['last_message'])),
        unread: _asInt(json['unread_count']),
        updatedAt: _asDate(json['updated_at']),
      );
}

/// Une page de messages renvoyée par le serveur
class ChatPage {
  final List<ChatMessage> messages;
  final bool hasMore;

  /// Mes messages jusqu'à cet identifiant ont été lus par mon interlocuteur
  final int? myReadUpTo;

  const ChatPage({required this.messages, this.hasMore = false, this.myReadUpTo});
}
