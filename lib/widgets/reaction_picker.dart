import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../theme/colors.dart';

/// Affiche la barre d'emojis flottante au-dessus de [anchor] (comme sur WhatsApp)
/// et renvoie l'emoji choisi, ou null si l'utilisateur ferme la barre.
Future<String?> showReactionPicker(
  BuildContext context, {
  required Rect anchor,
  String? current,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fermer',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, __) {
      final screen = MediaQuery.of(ctx).size;
      const barHeight = 52.0;
      final barWidth = kReactionEmojis.length * 46.0 + 16;

      final left = (anchor.center.dx - barWidth / 2).clamp(
        8.0,
        (screen.width - barWidth - 8).clamp(8.0, double.infinity),
      );
      // Au-dessus du bouton, ou en dessous s'il n'y a pas la place
      final above = anchor.top - barHeight - 8;
      final top =
          above >= MediaQuery.of(ctx).padding.top + 8
              ? above
              : anchor.bottom + 8;

      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final emoji in kReactionEmojis)
                      InkResponse(
                        radius: 24,
                        onTap: () => Navigator.pop(ctx, emoji),
                        child: Container(
                          width: 42,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border:
                                emoji == current
                                    ? Border.all(
                                      color: AppColors.primary,
                                      width: 2,
                                    )
                                    : null,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (ctx, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: curved,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      );
    },
  );
}

/// Zone tactile de réaction : un appui simple applique (ou retire) la réaction rapide,
/// un appui long ouvre la barre d'emojis. [onReact] reçoit l'emoji choisi ;
/// le parent décide si c'est un ajout, un remplacement ou un retrait.
class ReactionTrigger extends StatelessWidget {
  final String? myReaction;
  final void Function(String emoji) onReact;
  final Widget child;
  final BorderRadius borderRadius;

  const ReactionTrigger({
    super.key,
    required this.myReaction,
    required this.onReact,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: borderRadius,
      // Déjà réagi : un appui simple retire la réaction (même emoji = bascule)
      onTap: () => onReact(myReaction ?? kDefaultReaction),
      onLongPress: () async {
        final box = context.findRenderObject() as RenderBox;
        final anchor = box.localToGlobal(Offset.zero) & box.size;
        final picked = await showReactionPicker(
          context,
          anchor: anchor,
          current: myReaction,
        );
        if (picked != null) onReact(picked);
      },
      child: child,
    );
  }
}

/// Résumé compact des réactions : jusqu'à 3 emojis les plus fréquents puis le total.
class ReactionSummary extends StatelessWidget {
  final List<ReactionCount> reactions;
  final int total;
  final double fontSize;
  final Color color;

  const ReactionSummary({
    super.key,
    required this.reactions,
    required this.total,
    this.fontSize = 14,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in reactions.take(3))
          Text(r.emoji, style: TextStyle(fontSize: fontSize)),
        const SizedBox(width: 4),
        Text(
          '$total',
          style: TextStyle(
            fontSize: fontSize - 1,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
