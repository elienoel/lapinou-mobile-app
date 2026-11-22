import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../theme/colors.dart';
import '../utils/time_ago.dart';
import '../widgets/author_avatar.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

/// Liste des discussions privées, la plus récente en premier, avec les messages non lus.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final chat = context.read<ChatProvider>();
    // Après la construction : le chargement notifie les écouteurs (pas permis pendant un build)
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => chat.fetchConversations(),
    );
    _timer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => chat.fetchConversations(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _open(ChatConversation c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)),
    );
    if (mounted) context.read<ChatProvider>().fetchConversations();
  }

  Future<void> _newChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
    if (mounted) context.read<ChatProvider>().fetchConversations();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final me = context.watch<AuthProvider>().user?.id ?? 0;
    final list = chat.conversations;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_new_chat',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Nouvelle discussion'),
        onPressed: _newChat,
      ),
      body: RefreshIndicator(
        color: AppColors.secondary,
        onRefresh: chat.fetchConversations,
        child:
            chat.isLoading && list.isEmpty
                ? const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                )
                : list.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: list.length,
                  separatorBuilder:
                      (_, __) => const Divider(
                        height: 1,
                        indent: 74,
                        color: Color(0xFFEDEFED),
                      ),
                  itemBuilder: (context, i) => _tile(list[i], me),
                ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Aucune discussion pour le moment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Échangez en privé avec les autres éleveurs : conseils, ventes de reproducteurs, entraide.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _tile(ChatConversation c, int me) {
    final last = c.last;
    final unread = c.unread > 0;
    final prefix = last != null && last.senderId == me ? 'Vous : ' : '';

    return InkWell(
      onTap: () => _open(c),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Anneau violet autour de l'avatar quand il y a des messages non lus
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: unread ? AppColors.secondary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: AuthorAvatar(
                name: c.other.name,
                url: c.other.avatar,
                radius: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.other.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (last != null)
                        Text(
                          chatListTime(last.createdAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.normal,
                            color:
                                unread
                                    ? AppColors.secondary
                                    : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          last == null ? '' : '$prefix${last.text}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                unread ? FontWeight.w600 : FontWeight.normal,
                            color:
                                unread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            c.unread > 99 ? '99+' : '${c.unread}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
