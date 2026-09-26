import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/care.dart';
import '../models/currency.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/author_avatar.dart';
import '../widgets/chat_icon_button.dart';
import 'main_navigation_screen.dart';
import 'rabbit_list_screen.dart';
import 'matings_screen.dart';
import 'care_screen.dart';
import 'finances_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      if (token != null && token.isNotEmpty) {
        context.read<RabbitProvider>().fetchAll(token: token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        final totalIncome = provider.finances
            .where((f) => f.isIncome)
            .fold(0.0, (sum, f) => sum + f.amount);

        final totalExpense = provider.finances
            .where((f) => !f.isIncome)
            .fold(0.0, (sum, f) => sum + f.amount);

        final balance = totalIncome - totalExpense;
        final currency = context.watch<AuthProvider>().currency;

        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh:
                  () => provider.fetchAll(
                    token: context.read<AuthProvider>().token,
                  ),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. En-tête éleveur
                    _buildTopHeader(context),

                    const SizedBox(height: 20),

                    // 2. Section "Résumé de l'activité" (Scroll horizontal)
                    const Text(
                      'Résumé de l\'activité',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildHorizontalActivitySummary(
                      provider,
                      totalIncome,
                      totalExpense,
                      balance,
                      currency,
                    ),

                    const SizedBox(height: 20),

                    // 3. Section "Menu Principal" (Les cards du menu)

                    // Card 1: Mes lapins
                    _buildMenuCard(
                      context: context,
                      icon: '🐰',
                      title: 'Mes lapins',
                      subtitle:
                          'Cheptel, cages et loges, reproducteurs, arbres généalogiques',
                      badge: '${provider.totalRabbitsCount} lapins',
                      badgeColor: AppColors.primarySoft,
                      badgeTextColor: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RabbitListScreen(),
                          ),
                        );
                      },
                    ),

                    // Card 2: Accouplements & Mises bas
                    _buildMenuCard(
                      context: context,
                      icon: '❤️',
                      title: 'Accouplements & Mises bas',
                      subtitle:
                          'Saillies, palpation, mises bas et sevrage des lapereaux',
                      badge:
                          '${provider.matings.where((m) => m.isActive).length} en cours · ${provider.totalKitsInNests} lapereaux${provider.littersToWeanCount > 0 ? ' · ${provider.littersToWeanCount} à sevrer' : ''}',
                      badgeColor: AppColors.statusPregnantBg,
                      badgeTextColor: AppColors.statusPregnantText,
                      onTap: () {
                        // Des lapereaux à sevrer : on ouvre directement l'onglet des mises bas
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => MatingsScreen(
                                  initialTab:
                                      provider.littersToWeanCount > 0 ? 1 : 0,
                                ),
                          ),
                        );
                      },
                    ),

                    // Card 3: Soins & entretien
                    _buildMenuCard(
                      context: context,
                      icon: '💉',
                      title: 'Soins & entretien',
                      subtitle:
                          'Vaccins, vitamines, déparasitants, historique des soins et rappels',
                      badge: _careBadge(provider),
                      badgeColor:
                          provider.pendingCareCount > 0
                              ? AppColors.statusAlertBg
                              : AppColors.primarySoft,
                      badgeTextColor:
                          provider.pendingCareCount > 0
                              ? AppColors.statusAlertText
                              : AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CareScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Badge de la carte « Soins & entretien » : ce qu'il faut faire en priorité.
  String _careBadge(RabbitProvider provider) {
    final overdue =
        provider.upcomingCares.where((c) => c.status == DueStatus.overdue).length;
    if (overdue > 0) return '$overdue en retard';
    if (provider.pendingCareCount > 0) {
      return '${provider.pendingCareCount} à faire';
    }
    return 'À jour';
  }

  String _careDetail(RabbitProvider provider) {
    final overdue =
        provider.upcomingCares.where((c) => c.status == DueStatus.overdue).length;
    if (overdue > 0) return '$overdue en retard';
    if (provider.pendingCareCount > 0) return 'À faire cette semaine';
    return 'Aucun soin en retard';
  }

  Widget _buildTopHeader(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final farmName =
        user?.farmName?.isNotEmpty == true
            ? user!.farmName!
            : 'Clapier du Val Fleuri';
    final displayName =
        user?.firstName?.isNotEmpty == true
            ? 'Bonjour, ${user!.firstName} 🐰'
            : 'Bonjour, Éleveur 🐰';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  farmName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            const ChatIconButton(),
            GestureDetector(
              onTap:
                  () => MainNavigationScreen.goToTab(
                    context,
                    MainNavigationScreen.profileTab,
                  ),
              child: Tooltip(
                message: 'Mon profil',
                child: AuthorAvatar(
                  key: ValueKey(user?.avatar),
                  name: user?.displayName ?? '',
                  url: user?.avatar,
                  radius: 22,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHorizontalActivitySummary(
    RabbitProvider provider,
    double totalIncome,
    double totalExpense,
    double balance,
    AppCurrency currency,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // Stat Card 1: Cheptel total (Highlighted green card)
          _buildActivityStatCard(
            isHighlighted: true,
            icon: '🐰',
            value: '${provider.totalRabbitsCount}',
            label: 'Cheptel total',
            detail: '${provider.males.length} ♂ • ${provider.females.length} ♀',
            badge: 'Reproducteurs',
          ),
          const SizedBox(width: 12),

          // Stat Card 2: Gestations
          _buildActivityStatCard(
            icon: '⏳',
            value: '${provider.activePregnanciesCount}',
            label: 'Gestations',
            detail: 'Prochaine dans ~2 j',
            badge: 'Mise bas',
          ),
          const SizedBox(width: 12),

          // Stat Card 3: Lapereaux au nid
          _buildActivityStatCard(
            icon: '🍼',
            value: '${provider.totalKitsInNests}',
            label: 'Lapereaux',
            detail: '${provider.litters.length} portée(s) active(s)',
            badge: 'Au nid',
          ),
          const SizedBox(width: 12),

          // Stat Card 4: Soins dus
          _buildActivityStatCard(
            icon: '💉',
            value: '${provider.pendingCareCount}',
            label: 'Soins dus',
            detail: _careDetail(provider),
            badge: 'Sanitaire',
          ),
          const SizedBox(width: 12),

          // Stat Card 5: Finances
          _buildActivityStatCard(
            icon: '💰',
            value: currency.format(balance, showSign: true, decimals: 0),
            label: 'Bilan clapier',
            detail: 'Ventes: ${currency.format(totalIncome, showSign: true, decimals: 0)}',
            badge: balance >= 0 ? 'Bénéfice' : 'Déficit',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStatCard({
    required String icon,
    required String value,
    required String label,
    required String detail,
    required String badge,
    bool isHighlighted = false,
  }) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isHighlighted ? 15 : 6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isHighlighted
                            ? Colors.white
                            : AppColors.primarySoft,
                    border: Border.all(
                      color:
                          isHighlighted ? Colors.white : AppColors.primary,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isHighlighted ? Colors.white : AppColors.textPrimary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  isHighlighted
                      ? Colors.white.withAlpha(220)
                      : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11,
              color:
                  isHighlighted
                      ? Colors.white.withAlpha(180)
                      : AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: badgeColor,
                  border: Border.all(color: AppColors.cardBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),

              // Title & Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            border: Border.all(color: badgeTextColor),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
