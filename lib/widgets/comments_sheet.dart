import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/community_post.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../theme/colors.dart';
import '../utils/time_ago.dart';
import 'author_avatar.dart';
import 'reaction_picker.dart';

/// Feuille des commentaires d'une publication : réactions emoji sur chaque commentaire
/// et réponses (un niveau d'imbrication, comme sur Facebook).
class CommentsSheet extends StatefulWidget {
  final CommunityPost post;

  const CommentsSheet({super.key, required this.post});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<PostComment> _comments = [];
  final Set<int> _expandedThreads = {};
  PostComment? _replyingTo;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthProvider>().token;
    final list = await context.read<CommunityProvider>().fetchComments(
      widget.post.id,
      token: token,
    );
    if (!mounted) return;
    setState(() {
      _comments = list;
      _isLoading = false;
    });
  }

  List<PostComment> get _roots =>
      _comments.where((c) => c.parentId == null).toList();

  List<PostComment> _repliesOf(int rootId) =>
      _comments.where((c) => c.parentId == rootId).toList();

  void _startReply(PostComment target) {
    setState(() {
      _replyingTo = target;
      // Répondre à une réponse : on la mentionne pour garder le contexte
      if (target.isReply && _controller.text.isEmpty) {
        _controller.text = '@${target.authorName} ';
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      }
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _react(PostComment comment, String emoji) async {
    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      _toast('Veuillez vous connecter pour réagir');
      return;
    }
    final provider = context.read<CommunityProvider>();
    final future = provider.reactToComment(
      comment: comment,
      emoji: emoji,
      token: token,
    );
    setState(() {}); // affichage optimiste immédiat
    final ok = await future;
    if (!mounted) return;
    setState(() {});
    if (!ok) _toast('Impossible d\'enregistrer la réaction');
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null || token.isEmpty) {
      _toast('Veuillez vous connecter pour commenter');
      return;
    }

    final target = _replyingTo;
    // Le serveur ne garde qu'un niveau : une réponse à une réponse va sous le commentaire racine
    final rootId = target == null ? null : (target.parentId ?? target.id);

    setState(() => _isSending = true);
    final comment = await context.read<CommunityProvider>().addComment(
      postId: widget.post.id,
      token: token,
      content: text,
      parentId: rootId,
    );
    if (!mounted) return;

    setState(() => _isSending = false);
    if (comment == null) {
      _toast('Erreur lors de l\'envoi du commentaire');
      return;
    }
    _controller.clear();
    setState(() {
      _comments.add(comment);
      _replyingTo = null;
      if (rootId != null) _expandedThreads.add(rootId);
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final roots = _roots;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                    : roots.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: roots.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => _buildThread(roots[i]),
                    ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final count = _isLoading ? widget.post.commentsCount : _comments.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Commentaires ($count)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('💬', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text(
            'Aucun commentaire pour le moment',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          SizedBox(height: 4),
          Text(
            'Soyez le premier à réagir !',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThread(PostComment root) {
    final replies = _repliesOf(root.id);
    final expanded = _expandedThreads.contains(root.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildComment(root),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 6),
            child:
                expanded
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final r in replies)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _buildComment(r),
                          ),
                      ],
                    )
                    : InkWell(
                      onTap:
                          () => setState(() => _expandedThreads.add(root.id)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '↳ Voir ${replies.length} réponse${replies.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
          ),
      ],
    );
  }

  Widget _buildComment(PostComment c) {
    final reacted = c.myReaction != null;
    final radius = c.isReply ? 13.0 : 16.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthorAvatar(name: c.authorName, url: c.authorAvatar, radius: radius),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrey,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      c.content,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Row(
                  children: [
                    Text(
                      timeAgo(c.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ReactionTrigger(
                      myReaction: c.myReaction,
                      onReact: (emoji) => _react(c, emoji),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          reacted
                              ? '${c.myReaction} ${kReactionLabels[c.myReaction] ?? ''}'
                              : "J'aime",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                reacted
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _startReply(c),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Text(
                          'Répondre',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    ReactionSummary(
                      reactions: c.reactions,
                      total: c.likesCount,
                      fontSize: 13,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Réponse à ${_replyingTo!.authorName}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _cancelReply,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:
                        _replyingTo == null
                            ? 'Écrire un commentaire...'
                            : 'Écrire une réponse...',
                    hintStyle: const TextStyle(fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundGrey,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon:
                    _isSending
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                        : const Icon(
                          Icons.send_rounded,
                          color: AppColors.primary,
                        ),
                onPressed: _isSending ? null : _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
