import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../screens/conversations_screen.dart';
import '../theme/colors.dart';

/// Bouton « Messages » avec la pastille des messages non lus.
class ChatIconButton extends StatelessWidget {
  const ChatIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.select<ChatProvider, int>((c) => c.unreadTotal);
    return IconButton(
      tooltip: 'Messages',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: AppColors.primary,
        child: const Icon(
          Icons.chat_bubble_outline_rounded,
          color: AppColors.primary,
        ),
      ),
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConversationsScreen()),
          ),
    );
  }
}
