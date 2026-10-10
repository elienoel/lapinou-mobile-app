import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/community_post.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../utils/time_ago.dart';
import '../widgets/author_avatar.dart';
import '../widgets/chat_icon_button.dart';
import 'chat_screen.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/post_media.dart';
import '../widgets/reaction_picker.dart';

class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  String _selectedFilter = 'Tous';
  final List<String> _filters = [
    'Tous',
    'Santé',
    'Alimentation',
    'Reproduction',
    'Conseils',
    'Équipement',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<CommunityProvider>().fetchPosts(token: auth.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final communityProvider = context.watch<CommunityProvider>();

    final filteredPosts =
        _selectedFilter == 'Tous'
            ? communityProvider.posts
            : communityProvider.posts.where((post) {
              final tags = post.tagList.map((t) => t.toLowerCase()).toList();
              return tags.contains(_selectedFilter.toLowerCase()) ||
                  post.title.toLowerCase().contains(
                    _selectedFilter.toLowerCase(),
                  ) ||
                  post.content.toLowerCase().contains(
                    _selectedFilter.toLowerCase(),
                  );
            }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Fil d\'actualité',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Communauté des éleveurs',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          const ChatIconButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Actualiser',
            onPressed: () {
              communityProvider.fetchPosts(token: auth.token);
            },
          ),
        ],
      ),
      // Fil façon discussion de groupe : les messages s'empilent du plus ancien (haut)
      // au plus récent (bas), la barre de rédaction est en bas.
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildMessages(context, communityProvider, filteredPosts),
          ),
          _buildComposer(context, auth),
        ],
      ),
    );
  }

  /// Barre de filtres par thématique
  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children:
              _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.backgroundGrey,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color:
                            isSelected
                                ? AppColors.primary
                                : AppColors.cardBorder,
                      ),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  /// Barre de rédaction en bas de l'écran : « Quoi de neuf ? » + photo / vidéo
  Widget _buildComposer(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          AuthorAvatar(
            name: auth.user?.displayName ?? '',
            url: auth.user?.avatar,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              key: const ValueKey('feed-composer'),
              borderRadius: BorderRadius.circular(24),
              onTap: () => _showCreatePostSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Text(
                  'Quoi de neuf ?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Photo / vidéo',
            icon: const Icon(
              Icons.photo_library_rounded,
              color: AppColors.primary,
            ),
            onPressed: () => _showCreatePostSheet(context, openGallery: true),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(
    BuildContext context,
    CommunityProvider communityProvider,
    List<CommunityPost> posts,
  ) {
    final auth = context.read<AuthProvider>();

    if (communityProvider.isLoading && communityProvider.posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (posts.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => communityProvider.fetchPosts(token: auth.token),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 380,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFilter == 'Tous'
                          ? 'Aucun message pour le moment'
                          : 'Aucun message dans "$_selectedFilter"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Soyez le premier éleveur à publier !',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // `posts` va du plus récent au plus ancien : la liste inversée place donc
    // le plus récent en bas, comme dans une discussion.
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => communityProvider.fetchPosts(token: auth.token),
      child: ListView.builder(
        key: const ValueKey('feed-messages'),
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          // Un séparateur de jour précède le premier message de chaque journée
          final older = index + 1 < posts.length ? posts[index + 1] : null;
          final newDay =
              older == null ||
              !_sameDay(older.createdAt.toLocal(), post.createdAt.toLocal());
          return Column(
            children: [
              if (newDay) _buildDaySeparator(post.createdAt.toLocal()),
              _buildPostBubble(context, post),
            ],
          );
        },
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDaySeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.cardBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            chatDayLabel(date),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  /// Un message du fil : bulle blanche pour les autres éleveurs (avec leur avatar et leur nom),
  /// bulle noire à droite pour ses propres messages. J'aime / Commenter / Partager restent
  /// disponibles en bas de chaque bulle.
  Widget _buildPostBubble(BuildContext context, CommunityPost post) {
    final auth = context.watch<AuthProvider>();
    final communityProvider = context.read<CommunityProvider>();
    final isMine = auth.user != null && post.authorId == auth.user!.id;

    // Ses propres messages : fond primaire à très faible opacité, texte foncé comme les autres
    const fg = AppColors.textPrimary;
    const sub = AppColors.textSecondary;
    const divider = AppColors.cardBorder;
    final maxBubble = MediaQuery.of(context).size.width * 0.84;

    Widget action({
      required Widget icon,
      required String label,
      required Color color,
      VoidCallback? onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubble),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isMine ? AppColors.primaryTint : Colors.white,
        border: Border.all(
          color: isMine ? AppColors.primaryTint : AppColors.cardBorder,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auteur (pas pour ses propres messages) et menu
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 2, 0),
            child: Row(
              children: [
                Expanded(
                  child:
                      isMine
                          ? const SizedBox(height: 24)
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: AppColors.primary,
                                ),
                              ),
                              if (post.authorFarm != null &&
                                  post.authorFarm!.isNotEmpty)
                                Text(
                                  '🏡 ${post.authorFarm}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: sub),
                                ),
                            ],
                          ),
                ),
                if (isMine || (post.authorId != null && auth.user != null))
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    icon: Icon(Icons.more_horiz_rounded, color: sub),
                    onSelected: (v) {
                      if (v == 'delete') _confirmDelete(context, post);
                      if (v == 'message' && post.authorId != null) {
                        startChatWithUser(context, post.authorId!);
                      }
                    },
                    itemBuilder:
                        (_) => [
                          if (isMine)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Supprimer la publication'),
                                ],
                              ),
                            )
                          else
                            PopupMenuItem(
                              value: 'message',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Écrire à ${post.authorName}'),
                                ],
                              ),
                            ),
                        ],
                  )
                else
                  const SizedBox(width: 10),
              ],
            ),
          ),

          // Titre (anciennes publications)
          if (post.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(
                post.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                  color: fg,
                  height: 1.25,
                ),
              ),
            ),

          // Texte
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: _ExpandableText(
                text: post.content,
                color: fg,
                moreColor: sub,
              ),
            ),

          // Tags
          if (post.tagList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Wrap(
                spacing: 8,
                children:
                    post.tagList
                        .map(
                          (tag) => Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),

          // Photos / vidéos
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: PostMediaGrid(
                  media: post.media,
                  onOpen:
                      (i) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MediaViewerScreen(
                                media: post.media,
                                initialIndex: i,
                              ),
                        ),
                      ),
                ),
              ),
            ),

          // Réactions, commentaires et heure (comme l'heure d'un message)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Row(
              children: [
                ReactionSummary(
                  reactions: post.reactions,
                  total: post.likesCount,
                  color: sub,
                ),
                const Spacer(),
                if (post.commentsCount > 0) ...[
                  GestureDetector(
                    onTap: () => _showCommentsBottomSheet(context, post),
                    child: Text(
                      '${post.commentsCount} commentaire${post.commentsCount > 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, color: sub),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  DateFormat('HH:mm').format(post.createdAt.toLocal()),
                  key: ValueKey('post-time-${post.id}'),
                  style: TextStyle(fontSize: 11, color: sub),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.8, color: divider),

          // Actions : J'aime / Commenter / Partager
          Row(
            children: [
              Expanded(
                child: ReactionTrigger(
                  myReaction: post.myReaction,
                  onReact: (emoji) {
                    final token = auth.token;
                    if (token == null || token.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Veuillez vous connecter pour réagir à ce post',
                          ),
                        ),
                      );
                      return;
                    }
                    communityProvider.reactToPost(
                      postId: post.id,
                      emoji: emoji,
                      token: token,
                    );
                  },
                  child: action(
                    color: fg,
                    icon:
                        post.myReaction != null
                            ? Text(
                              post.myReaction!,
                              style: const TextStyle(fontSize: 17),
                            )
                            : Icon(
                              Icons.favorite_outline_rounded,
                              color: fg,
                              size: 18,
                            ),
                    label:
                        post.myReaction != null
                            ? (kReactionLabels[post.myReaction] ?? "J'aime")
                            : "J'aime",
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  key: ValueKey('post-comment-${post.id}'),
                  onTap: () => _showCommentsBottomSheet(context, post),
                  child: action(
                    color: fg,
                    icon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: fg,
                      size: 18,
                    ),
                    label: 'Commenter',
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  key: ValueKey('post-share-${post.id}'),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(
                        text: '${post.authorName} : ${post.content}'.trim(),
                      ),
                    );
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Texte de la publication copié'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: action(
                    color: fg,
                    icon: Icon(Icons.share_outlined, color: fg, size: 18),
                    label: 'Partager',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            AuthorAvatar(
              name: post.authorName,
              url: post.authorAvatar,
              radius: 16,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CommunityPost post) async {
    final token = context.read<AuthProvider>().token;
    final provider = context.read<CommunityProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (token == null || token.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer la publication ?'),
            content: const Text('Cette action est définitive.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    final ok = await provider.deletePost(postId: post.id, token: token);
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Publication supprimée' : 'Suppression impossible'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // --- Modal: Commentaires ---
  void _showCommentsBottomSheet(BuildContext context, CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return CommentsSheet(post: post);
      },
    );
  }

  // --- Modal: Créer un post ---
  void _showCreatePostSheet(BuildContext context, {bool openGallery = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CreatePostSheet(openGalleryOnStart: openGallery),
    );
  }
}

/// Texte tronqué avec « Voir plus », comme sur Facebook.
class _ExpandableText extends StatefulWidget {
  final String text;
  final Color color;
  final Color moreColor;
  const _ExpandableText({
    required this.text,
    this.color = const Color(0xFF1F2937),
    this.moreColor = AppColors.textSecondary,
  });

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  TextStyle get _style =>
      TextStyle(fontSize: 14, color: widget.color, height: 1.45);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: _style),
          maxLines: 5,
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: _style,
              maxLines: _expanded ? null : 5,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (overflows && !_expanded)
              GestureDetector(
                onTap: () => setState(() => _expanded = true),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Voir plus',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: widget.moreColor,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PickedMedia {
  final File file;
  final bool isVideo;
  _PickedMedia(this.file, this.isVideo);
}

/// Éditeur de publication : texte + photos/vidéos (galerie ou appareil photo).
class _CreatePostSheet extends StatefulWidget {
  final bool openGalleryOnStart;
  const _CreatePostSheet({this.openGalleryOnStart = false});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  static const _maxMedia = 10;
  static const _maxVideoBytes = 100 * 1024 * 1024;
  static const _videoExtensions = {'.mp4', '.mov', '.m4v', '.webm', '.3gp'};

  final _picker = ImagePicker();
  final _textController = TextEditingController();
  final List<_PickedMedia> _media = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() => setState(() {}));
    if (widget.openGalleryOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickFromGallery());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      !_isSubmitting &&
      (_textController.text.trim().isNotEmpty || _media.isNotEmpty);

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  Future<void> _addFiles(List<XFile> picked) async {
    for (final x in picked) {
      if (_media.length >= _maxMedia) {
        _toast('Maximum $_maxMedia photos/vidéos par publication.');
        break;
      }
      final dot = x.path.lastIndexOf('.');
      final ext = dot == -1 ? '' : x.path.substring(dot).toLowerCase();
      final isVideo = _videoExtensions.contains(ext);
      final file = File(x.path);
      if (isVideo && await file.length() > _maxVideoBytes) {
        _toast(
          '« ${x.name} » dépasse 100 Mo, choisissez une vidéo plus courte.',
        );
        continue;
      }
      _media.add(_PickedMedia(file, isVideo));
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxMedia - _media.length;
    if (remaining <= 0) {
      _toast('Maximum $_maxMedia photos/vidéos par publication.');
      return;
    }
    try {
      final picked = await _picker.pickMultipleMedia(
        imageQuality: 85,
        maxWidth: 1920,
        limit: remaining,
      );
      await _addFiles(picked);
    } catch (e) {
      _toast('Impossible d\'accéder à la galerie.');
    }
  }

  Future<void> _capture({required bool video}) async {
    try {
      final XFile? x =
          video
              ? await _picker.pickVideo(
                source: ImageSource.camera,
                maxDuration: const Duration(minutes: 3),
              )
              : await _picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
                maxWidth: 1920,
              );
      if (x != null) await _addFiles([x]);
    } catch (e) {
      _toast('Impossible d\'utiliser l\'appareil photo.');
    }
  }

  void _showCameraChoice() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Prendre une photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _capture(video: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: const Text('Filmer une vidéo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _capture(video: true);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _publish() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null || token.isEmpty) {
      _toast('Veuillez vous connecter pour publier');
      return;
    }

    final text = _textController.text.trim();
    // Les #hashtags du texte alimentent les filtres thématiques du fil
    final tags = RegExp(
      r'#([\p{L}\p{N}_]+)',
      unicode: true,
    ).allMatches(text).map((m) => m.group(1)!).toSet().join(',');

    final provider = context.read<CommunityProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isSubmitting = true);
    final success = await provider.createPost(
      token: token,
      content: text,
      tags: tags.isNotEmpty ? tags : null,
      mediaFiles: _media.map((m) => m.file).toList(),
    );

    if (!mounted) return;
    if (success) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Publication créée avec succès !'),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      setState(() => _isSubmitting = false);
      _toast(
        provider.lastError ??
            'Erreur lors de la publication. Vérifiez votre connexion et la taille des fichiers.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName =
        (user?.firstName?.isNotEmpty ?? false)
            ? user!.firstName!
            : (user?.displayName ?? '');

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // En-tête
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Créer une publication',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _canPublish ? _publish : null,
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text(
                              'Publier',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                  ),
                ],
              ),
            ),
            if (_isSubmitting) const LinearProgressIndicator(minHeight: 2),
            const Divider(height: 1),

            // Auteur + texte + aperçus
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AuthorAvatar(
                          name: user?.displayName ?? '',
                          url: user?.avatar,
                          radius: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          user?.displayName ?? 'Éleveur',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textController,
                      enabled: !_isSubmitting,
                      minLines: _media.isEmpty ? 6 : 2,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(fontSize: 17),
                      decoration: InputDecoration(
                        hintText: 'Quoi de neuf, $firstName ?',
                        hintStyle: const TextStyle(
                          fontSize: 17,
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                    if (_media.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildPreviews(),
                    ],
                  ],
                ),
              ),
            ),

            // Ajouter à la publication
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ajouter à votre publication',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Photos / vidéos',
                      icon: Icon(
                        Icons.photo_library_rounded,
                        color: AppColors.primaryLight,
                      ),
                      onPressed: _isSubmitting ? null : _pickFromGallery,
                    ),
                    IconButton(
                      tooltip: 'Appareil photo',
                      icon: const Icon(
                        Icons.photo_camera_rounded,
                        color: AppColors.maleBlue,
                      ),
                      onPressed: _isSubmitting ? null : _showCameraChoice,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviews() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = _media[i];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child:
                      m.isVideo
                          ? Container(
                            color: AppColors.primary,
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          )
                          : Image.file(m.file, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap:
                      _isSubmitting
                          ? null
                          : () => setState(() => _media.removeAt(i)),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
