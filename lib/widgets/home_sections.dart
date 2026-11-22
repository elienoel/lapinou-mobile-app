import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/finance_transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/community_provider.dart';
import '../providers/rabbit_provider.dart';
import '../screens/add_rabbit_screen.dart';
import '../screens/conversations_screen.dart';
import '../screens/finances_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/matings_screen.dart';
import '../theme/colors.dart';
import '../utils/time_ago.dart';
import 'app_ui.dart';
import 'author_avatar.dart';
import 'care_sheets.dart';
import 'plan_limit.dart';

/// Titre de section de la page d'accueil, avec un lien « Voir tout » facultatif.
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

// ---- Actions rapides ----

/// Rangée de boutons ronds pour saisir sans chercher l'écran :
/// saillie, lapin, vente, soin.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<RabbitProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _QuickAction(
          key: const ValueKey('quick-mating'),
          icon: Icons.favorite_outline,
          label: 'Saillie',
          color: AppColors.secondary,
          onTap: () => showMatingForm(context, provider),
        ),
        _QuickAction(
          key: const ValueKey('quick-rabbit'),
          icon: Icons.pets_outlined,
          label: 'Lapin',
          color: AppColors.primary,
          onTap: () async {
            if (!await guardRabbitQuota(context, 1) || !context.mounted) {
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddRabbitScreen()),
            );
          },
        ),
        _QuickAction(
          key: const ValueKey('quick-sale'),
          icon: Icons.payments_outlined,
          label: 'Vente',
          color: AppColors.statusActiveText,
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FinancesScreen(openSaleForm: true),
                ),
              ),
        ),
        _QuickAction(
          key: const ValueKey('quick-care'),
          icon: Icons.medical_services_outlined,
          label: 'Soin',
          color: AppColors.statusAlertText,
          onTap: () async {
            final done = await showCareRecordSheet(context);
            if (done == true && context.mounted) {
              showAppSnack(context, 'Soin enregistré');
            }
          },
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(60), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Finances en un coup d'œil ----

/// Solde du mois et recettes / dépenses des 6 derniers mois en barres.
class FinanceGlance extends StatelessWidget {
  const FinanceGlance({super.key});

  static const int months = 6;

  @override
  Widget build(BuildContext context) {
    final finances = context.watch<RabbitProvider>().finances;
    final currency = context.watch<AuthProvider>().currency;
    final now = DateTime.now();

    // Totaux par mois, du plus ancien (gauche) au mois en cours (droite)
    final totals = <(DateTime, double, double)>[];
    for (var i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      double income = 0, expense = 0;
      for (final FinanceTransaction t in finances) {
        if (t.date.year == month.year && t.date.month == month.month) {
          t.isIncome ? income += t.amount : expense += t.amount;
        }
      }
      totals.add((month, income, expense));
    }
    final (_, monthIncome, monthExpense) = totals.last;
    final balance = monthIncome - monthExpense;
    final maxValue = totals.fold<double>(
      0,
      (m, e) => [m, e.$2, e.$3].reduce((a, b) => a > b ? a : b),
    );

    return InkWell(
      key: const ValueKey('finance-glance'),
      borderRadius: BorderRadius.circular(18),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FinancesScreen()),
          ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: appCardDecoration(shadow: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde de ${_monthName(now)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currency.format(balance, showSign: true, decimals: 0),
                        key: const ValueKey('finance-balance'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color:
                              balance >= 0
                                  ? AppColors.statusActiveText
                                  : AppColors.statusAlertText,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _legend(
                      AppColors.statusActiveText,
                      'Recettes ${currency.format(monthIncome, decimals: 0)}',
                    ),
                    const SizedBox(height: 4),
                    _legend(
                      AppColors.statusAlertText,
                      'Dépenses ${currency.format(monthExpense, decimals: 0)}',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (month, income, expense) in totals)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _bar(
                                  income,
                                  maxValue,
                                  AppColors.statusActiveText,
                                ),
                                const SizedBox(width: 3),
                                _bar(
                                  expense,
                                  maxValue,
                                  AppColors.statusAlertText,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('MMM', 'fr_FR').format(month),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  month == totals.last.$1
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                              color:
                                  month == totals.last.$1
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _monthName(DateTime d) => DateFormat('MMMM', 'fr_FR').format(d);

  static Widget _legend(Color color, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  );

  static Widget _bar(double value, double max, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ratio = max <= 0 ? 0.0 : value / max;
        return Container(
          width: 9,
          // Un trait minimal pour les mois sans mouvement
          height: (constraints.maxHeight * ratio).clamp(
            3.0,
            constraints.maxHeight,
          ),
          decoration: BoxDecoration(
            color: value > 0 ? color : AppColors.cardBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

// ---- Communauté ----

/// Les dernières publications du fil et les messages non lus.
class CommunityGlance extends StatelessWidget {
  const CommunityGlance({super.key});

  static const int shown = 3;

  @override
  Widget build(BuildContext context) {
    final posts = context.watch<CommunityProvider>().posts.take(shown).toList();
    final unread = context.select<ChatProvider, int>((c) => c.unreadTotal);
    void openFeed() => MainNavigationScreen.goToTab(
      context,
      MainNavigationScreen.communityTab,
    );

    return Column(
      key: const ValueKey('community-glance'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          'Communauté',
          action: 'Voir le fil',
          onAction: openFeed,
        ),
        if (unread > 0) ...[
          InkWell(
            key: const ValueKey('community-unread'),
            borderRadius: BorderRadius.circular(14),
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConversationsScreen(),
                  ),
                ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$unread message${unread > 1 ? 's' : ''} non lu${unread > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (posts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: appCardDecoration(),
            child: const Text(
              'Aucune publication pour le moment. Partagez votre élevage avec les autres éleveurs !',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          )
        else
          Container(
            decoration: appCardDecoration(shadow: true),
            child: Column(
              children: [
                for (var i = 0; i < posts.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  InkWell(
                    key: ValueKey('community-post-${posts[i].id}'),
                    onTap: openFeed,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AuthorAvatar(
                            name: posts[i].authorName,
                            url: posts[i].authorAvatar,
                            radius: 20,
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
                                        posts[i].authorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13.5,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeAgo(posts[i].createdAt),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  posts[i].title.isNotEmpty
                                      ? posts[i].title
                                      : posts[i].content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite_border_rounded,
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${posts[i].likesCount}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.mode_comment_outlined,
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${posts[i].commentsCount}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
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
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
