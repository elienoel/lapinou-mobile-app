import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/community_post.dart';
import '../services/api_constants.dart';
import '../services/validators.dart';

class CommunityProvider extends ChangeNotifier {
  List<CommunityPost> _posts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CommunityPost> get posts => _posts;

  /// Motif du dernier refus côté app (fichier trop lourd, texte vide...), à afficher.
  String? lastError;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  CommunityProvider() {
    fetchPosts();
  }

  Map<String, String> _headers(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// 1. Récupérer le fil d'actualité
  /// Déconnexion : on ne garde pas les publications du compte précédent à l'écran.
  void clear() {
    if (_posts.isEmpty) return;
    _posts = [];
    notifyListeners();
  }

  Future<void> fetchPosts({String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse(ApiConstants.postsUrl),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List results =
            data['data'] is List
                ? data['data']
                : (data['results'] is List ? data['results'] : []);

        _posts = results.map((p) => CommunityPost.fromJson(p)).toList();
        _isLoading = false;
        notifyListeners();
      } else {
        _isLoading = false;
        _errorMessage = 'Impossible de charger le fil d\'actualité';
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Erreur réseau: $e';
      notifyListeners();
    }
  }

  /// 2. Publier un nouveau post (texte et/ou photos/vidéos)
  Future<bool> createPost({
    required String token,
    String content = '',
    String? tags,
    List<File> mediaFiles = const [],
  }) async {
    lastError =
        Validators.postContent(
          content: content,
          mediaCount: mediaFiles.length,
        ) ??
        Validators.postMediaCount(mediaFiles.length);
    if (lastError == null) {
      for (final file in mediaFiles) {
        lastError = Validators.postMedia(file);
        if (lastError != null) break;
      }
    }
    if (lastError != null) return false;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.postsUrl),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['content'] = content;
      if (tags != null && tags.isNotEmpty) request.fields['tags'] = tags;
      for (final file in mediaFiles) {
        request.files.add(
          await http.MultipartFile.fromPath('media', file.path),
        );
      }

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        _posts.insert(0, CommunityPost.fromJson(data['data']));
        notifyListeners();
        return true;
      }
      debugPrint('Create post error ${response.statusCode}: ${response.body}');
    } catch (e) {
      debugPrint('Create post error: $e');
    }
    return false;
  }

  /// Supprimer une de ses publications
  Future<bool> deletePost({required int postId, required String token}) async {
    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.postDetailUrl(postId)),
        headers: _headers(token),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Delete post error: $e');
    }
    return false;
  }

  /// 3. Réagir à une publication avec un emoji.
  /// Même emoji que la réaction actuelle = retrait, autre emoji = remplacement.
  Future<void> reactToPost({
    required int postId,
    required String emoji,
    required String token,
  }) async {
    if (!Validators.reactionEmojis.contains(emoji)) return;
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final oldMine = post.myReaction;
    final oldReactions = post.reactions;
    final oldCount = post.likesCount;
    final newMine = oldMine == emoji ? null : emoji;

    // Mise à jour optimiste
    post.myReaction = newMine;
    post.reactions = applyReactionChange(oldReactions, oldMine, newMine);
    post.likesCount = post.reactions.fold(0, (sum, r) => sum + r.count);
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.postLikeUrl(postId)),
        headers: _headers(token),
        body: jsonEncode({'emoji': emoji}),
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(response.bodyBytes))['data'];
        post.myReaction = payload['my_reaction']?.toString();
        post.reactions = parseReactions(payload['reactions']);
        post.likesCount = payload['likes_count'] ?? post.likesCount;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('React to post error: $e');
    }
    // Échec : retour à l'état précédent
    post.myReaction = oldMine;
    post.reactions = oldReactions;
    post.likesCount = oldCount;
    notifyListeners();
  }

  /// Réagir à un commentaire (même logique que pour une publication).
  /// Le commentaire est modifié sur place ; renvoie false en cas d'échec (état restauré).
  Future<bool> reactToComment({
    required PostComment comment,
    required String emoji,
    required String token,
  }) async {
    if (!Validators.reactionEmojis.contains(emoji)) return false;
    final oldMine = comment.myReaction;
    final oldReactions = comment.reactions;
    final oldCount = comment.likesCount;
    final newMine = oldMine == emoji ? null : emoji;

    comment.myReaction = newMine;
    comment.reactions = applyReactionChange(oldReactions, oldMine, newMine);
    comment.likesCount = comment.reactions.fold(0, (sum, r) => sum + r.count);
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.commentReactUrl(comment.id)),
        headers: _headers(token),
        body: jsonEncode({'emoji': emoji}),
      );
      if (response.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(response.bodyBytes))['data'];
        comment.myReaction = payload['my_reaction']?.toString();
        comment.reactions = parseReactions(payload['reactions']);
        comment.likesCount = payload['likes_count'] ?? comment.likesCount;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('React to comment error: $e');
    }
    comment.myReaction = oldMine;
    comment.reactions = oldReactions;
    comment.likesCount = oldCount;
    notifyListeners();
    return false;
  }

  /// 4. Charger les commentaires d'un post
  Future<List<PostComment>> fetchComments(int postId, {String? token}) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.postCommentsUrl(postId)),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List list = data['data'] ?? [];
        return list.map((c) => PostComment.fromJson(c)).toList();
      }
    } catch (e) {
      debugPrint('Fetch comments error: $e');
    }
    return [];
  }

  /// 5. Ajouter un commentaire
  Future<PostComment?> addComment({
    required int postId,
    required String token,
    required String content,
    int? parentId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.postCommentsUrl(postId)),
        headers: _headers(token),
        body: jsonEncode({
          'content': content,
          if (parentId != null) 'parent': parentId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final comment = PostComment.fromJson(data['data']);

        // Mettre à jour le compteur sur le post
        final postIndex = _posts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          _posts[postIndex].commentsCount += 1;
          notifyListeners();
        }
        return comment;
      }
    } catch (e) {
      debugPrint('Add comment error: $e');
    }
    return null;
  }
}
