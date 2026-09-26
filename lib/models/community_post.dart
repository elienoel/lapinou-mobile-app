import '../services/api_constants.dart';

/// Réactions proposées (identiques à la liste autorisée par le backend).
const List<String> kReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
const String kDefaultReaction = '❤️';

const Map<String, String> kReactionLabels = {
  '👍': "J'aime",
  '❤️': "J'adore",
  '😂': 'Haha',
  '😮': 'Wow',
  '😢': 'Triste',
  '🙏': 'Merci',
};

class ReactionCount {
  final String emoji;
  final int count;
  const ReactionCount(this.emoji, this.count);
}

List<ReactionCount> parseReactions(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map(
        (r) => ReactionCount(
          r['emoji']?.toString() ?? '',
          r['count'] is int
              ? r['count'] as int
              : int.tryParse('${r['count']}') ?? 0,
        ),
      )
      .where((r) => r.emoji.isNotEmpty && r.count > 0)
      .toList();
}

/// Résultat d'un changement de réaction fait localement (avant la réponse du serveur) :
/// retire l'ancienne réaction de l'utilisateur, ajoute la nouvelle, trie par fréquence.
List<ReactionCount> applyReactionChange(
  List<ReactionCount> current,
  String? oldEmoji,
  String? newEmoji,
) {
  final counts = {for (final r in current) r.emoji: r.count};
  if (oldEmoji != null) {
    final left = (counts[oldEmoji] ?? 1) - 1;
    if (left <= 0) {
      counts.remove(oldEmoji);
    } else {
      counts[oldEmoji] = left;
    }
  }
  if (newEmoji != null) counts[newEmoji] = (counts[newEmoji] ?? 0) + 1;
  final list =
      counts.entries.map((e) => ReactionCount(e.key, e.value)).toList()
        ..sort((a, b) => b.count.compareTo(a.count));
  return list;
}

class PostComment {
  final int id;
  final int postId;
  final int? parentId;
  final int? authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final DateTime createdAt;
  List<ReactionCount> reactions;
  String? myReaction;
  int likesCount;

  PostComment({
    required this.id,
    required this.postId,
    this.parentId,
    this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    required this.createdAt,
    this.reactions = const [],
    this.myReaction,
    this.likesCount = 0,
  });

  bool get isReply => parentId != null;

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      postId:
          json['post'] is int
              ? json['post']
              : int.tryParse(json['post'].toString()) ?? 0,
      parentId:
          json['parent'] is int
              ? json['parent']
              : int.tryParse(json['parent']?.toString() ?? ''),
      authorId:
          json['author'] is int
              ? json['author']
              : int.tryParse(json['author']?.toString() ?? ''),
      authorName: json['author_name'] ?? 'Éleveur',
      authorAvatar: json['author_avatar'],
      content: json['content'] ?? '',
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
              : DateTime.now(),
      reactions: parseReactions(json['reactions']),
      myReaction: json['my_reaction']?.toString(),
      likesCount: json['likes_count'] is int ? json['likes_count'] : 0,
    );
  }
}

enum PostMediaType { image, video }

/// Photo ou vidéo attachée à une publication.
class PostMedia {
  final int id;
  final PostMediaType type;
  final String url;

  const PostMedia({required this.id, required this.type, required this.url});

  bool get isVideo => type == PostMediaType.video;

  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      type:
          json['media_type'] == 'video'
              ? PostMediaType.video
              : PostMediaType.image,
      url: ApiConstants.formatMediaUrl(json['url']?.toString()),
    );
  }
}

class CommunityPost {
  final int id;
  final int? authorId;
  final String authorName;
  final String? authorFarm;
  final String? authorAvatar;
  final String title;
  final String content;
  final List<PostMedia> media;
  final String? tags;
  int commentsCount;
  int likesCount;
  String? myReaction;
  List<ReactionCount> reactions;
  final DateTime createdAt;

  CommunityPost({
    required this.id,
    this.authorId,
    required this.authorName,
    this.authorFarm,
    this.authorAvatar,
    this.title = '',
    this.content = '',
    this.media = const [],
    this.tags,
    this.commentsCount = 0,
    this.likesCount = 0,
    this.myReaction,
    this.reactions = const [],
    required this.createdAt,
  });

  bool get isLiked => myReaction != null;

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id:
          json['id'] is int
              ? json['id']
              : int.tryParse(json['id'].toString()) ?? 0,
      authorId:
          json['author'] is int
              ? json['author']
              : int.tryParse(json['author']?.toString() ?? ''),
      authorName: json['author_name'] ?? 'Éleveur',
      authorFarm: json['author_farm'],
      authorAvatar: json['author_avatar'],
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      media:
          (json['media'] is List)
              ? (json['media'] as List)
                  .map((m) => PostMedia.fromJson(Map<String, dynamic>.from(m)))
                  .toList()
              : const [],
      tags: json['tags'],
      commentsCount: json['comments_count'] is int ? json['comments_count'] : 0,
      likesCount: json['likes_count'] is int ? json['likes_count'] : 0,
      myReaction: json['my_reaction']?.toString(),
      reactions: parseReactions(json['reactions']),
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
              : DateTime.now(),
    );
  }

  List<String> get tagList {
    if (tags == null || tags!.trim().isEmpty) return [];
    return tags!
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
