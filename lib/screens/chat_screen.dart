import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../models/community_post.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/voice_services.dart';
import '../theme/colors.dart';
import '../utils/time_ago.dart';
import '../widgets/author_avatar.dart';
import '../widgets/post_media.dart';
import '../widgets/voice_message_player.dart';

/// Ouvre la discussion avec un éleveur (la crée si besoin) depuis n'importe quel écran.
Future<void> startChatWithUser(BuildContext context, int userId) async {
  final provider = context.read<ChatProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  final conversation = await provider.openConversation(userId);
  if (conversation == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Impossible d'ouvrir la discussion."),
        backgroundColor: AppColors.primary,
      ),
    );
    return;
  }
  navigator.push(
    MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation)),
  );
}

class ChatScreen extends StatefulWidget {
  final ChatConversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 3);

  final _scroll = ScrollController();
  final _input = TextEditingController();
  final _picker = ImagePicker();

  /// Ordre chronologique (le plus ancien d'abord) ; l'affichage est inversé (le plus récent en bas)
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _loadingOlder = false;
  bool _hasMore = false;
  bool _polling = false;
  File? _pendingImage;
  Timer? _timer;

  // Note vocale en cours d'enregistrement
  static const _maxRecordMs = 5 * 60 * 1000;
  static const _minRecordMs = 1000;
  VoiceRecorder? _recorder;
  Timer? _recordTimer;
  String? _recordPath;
  bool _recording = false;
  int _recordMs = 0;

  int get _meId => context.read<AuthProvider>().user?.id ?? 0;
  ChatUser get _other => widget.conversation.other;

  int get _lastServerId =>
      _messages.fold(0, (max, m) => m.id > max ? m.id : max);

  int? get _firstServerId {
    for (final m in _messages) {
      if (m.id > 0) return m.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    // Le bouton d'envoi devient un micro quand il n'y a rien à envoyer
    _input.addListener(() => setState(() {}));
    _loadInitial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _recordTimer?.cancel();
    final recorder = _recorder;
    if (recorder != null) {
      recorder.cancel().whenComplete(recorder.dispose);
    }
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _poll();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  // ---- Chargement ----

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final page = await context.read<ChatProvider>().fetchMessages(
      widget.conversation.id,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (page == null) {
        _loadFailed = true;
      } else {
        _messages = page.messages;
        _hasMore = page.hasMore;
        _applyRead(page.myReadUpTo);
      }
    });
    if (page != null) _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling || _loading || !mounted) return;
    _polling = true;
    try {
      final page = await context.read<ChatProvider>().fetchMessages(
        widget.conversation.id,
        afterId: _lastServerId,
      );
      if (!mounted || page == null) return;

      final known = _messages.map((m) => m.id).toSet();
      final fresh = page.messages.where((m) => !known.contains(m.id)).toList();
      final atBottom = !_scroll.hasClients || _scroll.position.pixels < 120;

      setState(() {
        _messages.addAll(fresh);
        _applyRead(page.myReadUpTo);
      });
      if (fresh.isNotEmpty && atBottom) _scrollToBottom();
    } finally {
      _polling = false;
    }
  }

  void _applyRead(int? upTo) {
    if (upTo == null) return;
    for (final m in _messages) {
      if (m.senderId == _meId && m.id > 0 && m.id <= upTo) m.isRead = true;
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    final before = _firstServerId;
    if (_loadingOlder || !_hasMore || before == null) return;
    setState(() => _loadingOlder = true);
    final page = await context.read<ChatProvider>().fetchMessages(
      widget.conversation.id,
      beforeId: before,
    );
    if (!mounted) return;
    setState(() {
      _loadingOlder = false;
      if (page != null) {
        _messages.insertAll(0, page.messages);
        _hasMore = page.hasMore;
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---- Envoi ----

  Future<void> _send() async {
    final text = _input.text.trim();
    final image = _pendingImage;
    if (text.isEmpty && image == null) return;

    final local = ChatMessage(
      id: 0,
      senderId: _meId,
      content: text,
      createdAt: DateTime.now(),
      localId: '${DateTime.now().microsecondsSinceEpoch}',
      sending: true,
      localImagePath: image?.path,
    );
    setState(() {
      _messages.add(local);
      _input.clear();
      _pendingImage = null;
    });
    _scrollToBottom();
    await _deliver(local);
  }

  Future<void> _deliver(ChatMessage local) async {
    try {
      final sent = await context.read<ChatProvider>().sendMessage(
        widget.conversation.id,
        text: local.content,
        image:
            local.localImagePath != null ? File(local.localImagePath!) : null,
        audio:
            local.localAudioPath != null ? File(local.localAudioPath!) : null,
        audioDurationMs: local.audioDurationMs,
      );
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m.localId == local.localId);
        // L'actualisation a pu déjà rapporter ce message : on évite le doublon
        final alreadyThere = _messages.any((m) => m.id == sent.id);
        if (idx != -1) {
          alreadyThere ? _messages.removeAt(idx) : _messages[idx] = sent;
        }
      });
      // La note est sur le serveur : la copie temporaire n'est plus utile
      if (local.localAudioPath != null) {
        File(
          local.localAudioPath!,
        ).delete().catchError((_) => File(local.localAudioPath!));
      }
    } on ChatSendException catch (e) {
      if (!mounted) return;
      setState(() {
        local.sending = false;
        local.failed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.primary),
      );
    }
  }

  void _retry(ChatMessage m) {
    setState(() {
      m.failed = false;
      m.sending = true;
    });
    _deliver(m);
  }

  void _discard(ChatMessage m) {
    setState(() => _messages.removeWhere((x) => x.localId == m.localId));
  }

  // ---- Notes vocales ----

  void _toastError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  Future<void> _startRecording() async {
    if (_recording) return;
    final recorder = VoiceServices.recorder();
    try {
      if (!await recorder.requestPermission()) {
        await recorder.dispose();
        if (mounted) {
          _toastError(
            "Autorisez l'accès au micro dans les réglages pour envoyer des notes vocales.",
          );
        }
        return;
      }
      final path =
          '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(path);
      if (!mounted) {
        await recorder.cancel();
        await recorder.dispose();
        return;
      }
      setState(() {
        _recorder = recorder;
        _recordPath = path;
        _recording = true;
        _recordMs = 0;
      });
      _recordTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() => _recordMs += 200);
        if (_recordMs >= _maxRecordMs) _finishRecording(send: true, auto: true);
      });
    } catch (e) {
      await recorder.dispose();
      if (mounted) _toastError("Impossible de démarrer l'enregistrement.");
    }
  }

  /// Termine l'enregistrement : envoie la note ([send]) ou l'abandonne.
  Future<void> _finishRecording({required bool send, bool auto = false}) async {
    final recorder = _recorder;
    if (recorder == null) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    final durationMs = _recordMs;
    final fallbackPath = _recordPath;
    setState(() {
      _recording = false;
      _recorder = null;
      _recordMs = 0;
    });

    String? path;
    try {
      if (send) {
        path = await recorder.stop();
      } else {
        await recorder.cancel();
      }
    } catch (_) {}
    await recorder.dispose();
    if (!send) return;

    path ??= fallbackPath;
    if (path == null || durationMs < _minRecordMs) {
      if (path != null) File(path).delete().catchError((_) => File(path!));
      if (mounted) _toastError('Message vocal trop court');
      return;
    }
    if (!mounted) return;
    if (auto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Durée maximale de 5 minutes atteinte : message envoyé.',
          ),
        ),
      );
    }

    final local = ChatMessage(
      id: 0,
      senderId: _meId,
      createdAt: DateTime.now(),
      localId: '${DateTime.now().microsecondsSinceEpoch}',
      sending: true,
      localAudioPath: path,
      audioDurationMs: durationMs,
    );
    setState(() => _messages.add(local));
    _scrollToBottom();
    await _deliver(local);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (x != null && mounted) setState(() => _pendingImage = File(x.path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'accéder à la photo."),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _showAttachOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Photo depuis la galerie'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Prendre une photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  // ---- Affichage ----

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user?.id ?? 0;
    final subtitle = [
      if (_other.farmName != null &&
          _other.farmName!.isNotEmpty &&
          _other.farmName != _other.name)
        _other.farmName!,
      if (_other.location != null && _other.location!.isNotEmpty)
        _other.location!,
    ].join(' · ');

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AuthorAvatar(name: _other.name, url: _other.avatar, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _other.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.normal,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(me)),
          if (_pendingImage != null) _buildPendingImage(),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildBody(int me) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            const Text('Impossible de charger les messages'),
            TextButton(onPressed: _loadInitial, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👋', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            Text(
              'Dites bonjour à ${_other.name}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    final count = _messages.length;
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: count + (_loadingOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == count) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final idx = count - 1 - i;
        final m = _messages[idx];
        final previous = idx > 0 ? _messages[idx - 1] : null;
        final newDay =
            previous == null ||
            DateUtils.dateOnly(previous.createdAt) !=
                DateUtils.dateOnly(m.createdAt);

        return Column(
          children: [
            if (newDay) _dayChip(m.createdAt),
            _MessageBubble(
              message: m,
              isMine: m.senderId == me,
              onOpenImage: () => _openImage(m),
              onRetry: () => _retry(m),
              onDiscard: () => _discard(m),
            ),
          ],
        );
      },
    );
  }

  Widget _dayChip(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _openImage(ChatMessage m) {
    if (m.imageUrl == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => MediaViewerScreen(
              media: [
                PostMedia(
                  id: m.id,
                  type: PostMediaType.image,
                  url: m.imageUrl!,
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildPendingImage() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      alignment: Alignment.centerLeft,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _pendingImage!,
              height: 90,
              width: 90,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() => _pendingImage = null),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
          child: _recording ? _buildRecordingBar() : _buildInputRow(),
        ),
      ),
    );
  }

  Widget _buildInputRow() {
    final canSend = _input.text.trim().isNotEmpty || _pendingImage != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Joindre une photo',
          icon: const Icon(
            Icons.add_photo_alternate_outlined,
            color: AppColors.primary,
          ),
          onPressed: _showAttachOptions,
        ),
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Écrire un message…',
              hintStyle: const TextStyle(fontSize: 14),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              filled: true,
              fillColor: AppColors.backgroundGrey,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: canSend ? 'Envoyer' : 'Enregistrer une note vocale',
            icon: Icon(
              canSend ? Icons.send_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: canSend ? _send : _startRecording,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingBar() {
    final total = Duration(milliseconds: _recordMs);
    final label =
        '${total.inMinutes}:${(total.inSeconds % 60).toString().padLeft(2, '0')}';
    return Row(
      children: [
        IconButton(
          tooltip: 'Annuler',
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
          ),
          onPressed: () => _finishRecording(send: false),
        ),
        AnimatedOpacity(
          opacity: (_recordMs ~/ 600).isEven ? 1 : 0.25,
          duration: const Duration(milliseconds: 250),
          child: const Icon(
            Icons.fiber_manual_record,
            color: Colors.red,
            size: 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Enregistrement…',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: 'Envoyer la note vocale',
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            onPressed: () => _finishRecording(send: true),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final VoidCallback onOpenImage;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onOpenImage,
    required this.onRetry,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final metaColor = isMine ? Colors.white70 : AppColors.textMuted;

    Widget status() {
      if (!isMine) return const SizedBox.shrink();
      if (m.failed) {
        return const Icon(Icons.error_outline, size: 14, color: Colors.amber);
      }
      if (m.sending) return Icon(Icons.schedule, size: 13, color: metaColor);
      return Icon(
        m.isRead ? Icons.done_all : Icons.done,
        size: 15,
        color: m.isRead ? const Color(0xFF7DD3FC) : metaColor,
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: m.failed ? onRetry : null,
        onLongPress: m.failed ? onDiscard : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.hasImage)
                Padding(
                  padding: EdgeInsets.only(bottom: m.content.isEmpty ? 0 : 6),
                  child: GestureDetector(
                    onTap: m.imageUrl != null ? onOpenImage : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child:
                          m.localImagePath != null && m.imageUrl == null
                              ? Image.file(
                                File(m.localImagePath!),
                                width: 220,
                                height: 220,
                                fit: BoxFit.cover,
                              )
                              : Image.network(
                                m.imageUrl!,
                                width: 220,
                                height: 220,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => const SizedBox(
                                      width: 220,
                                      height: 120,
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                              ),
                    ),
                  ),
                ),
              if (m.hasAudio)
                VoiceMessagePlayer(
                  url: m.audioUrl,
                  filePath: m.audioUrl == null ? m.localAudioPath : null,
                  durationMs: m.audioDurationMs,
                  isMine: isMine,
                ),
              if (m.content.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    m.content,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: textColor,
                      height: 1.3,
                    ),
                  ),
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.failed)
                    const Text(
                      'Échec — touchez pour réessayer  ',
                      style: TextStyle(fontSize: 10.5, color: Colors.amber),
                    ),
                  Text(
                    DateFormat('HH:mm').format(m.createdAt),
                    style: TextStyle(fontSize: 10.5, color: metaColor),
                  ),
                  const SizedBox(width: 3),
                  status(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
