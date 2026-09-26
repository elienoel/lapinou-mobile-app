import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../theme/colors.dart';
import '../widgets/author_avatar.dart';
import 'chat_screen.dart';

/// Recherche d'un éleveur (nom, élevage, localisation) pour démarrer une discussion.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<ChatUser> _users = [];
  bool _loading = true;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(value));
  }

  Future<void> _load(String term) async {
    setState(() => _loading = true);
    final users = await context.read<ChatProvider>().searchUsers(term);
    // Ignorer une réponse périmée si le texte a changé entre-temps
    if (!mounted || term.trim() != _search.text.trim()) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _start(ChatUser user) async {
    if (_opening) return;
    setState(() => _opening = true);

    final chat = context.read<ChatProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final conversation = await chat.openConversation(user.id);
    if (!mounted) return;
    setState(() => _opening = false);

    if (conversation == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Impossible d'ouvrir la discussion."),
        backgroundColor: AppColors.primary,
      ));
      return;
    }
    navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => ChatScreen(conversation: conversation),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        title: const Text(
          'Nouvelle discussion',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher un éleveur, un élevage, une ville…',
                hintStyle: const TextStyle(fontSize: 13.5),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_opening) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading && _users.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _users.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucun éleveur trouvé',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, indent: 72, color: Color(0xFFEDEFED)),
                        itemBuilder: (context, i) {
                          final u = _users[i];
                          final sub = [
                            if (u.farmName != null &&
                                u.farmName!.isNotEmpty &&
                                u.farmName != u.name)
                              u.farmName!,
                            if (u.location != null && u.location!.isNotEmpty)
                              u.location!,
                          ].join(' · ');
                          return ListTile(
                            tileColor: Colors.white,
                            leading: AuthorAvatar(
                                name: u.name, url: u.avatar, radius: 22),
                            title: Text(
                              u.name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: sub.isEmpty ? null : Text(sub),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.textMuted),
                            onTap: () => _start(u),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
