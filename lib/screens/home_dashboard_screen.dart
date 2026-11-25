import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/care.dart';
import '../models/currency.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../providers/breeding_settings_provider.dart';
import '../providers/marketplace_provider.dart';
import '../providers/pharmacy_provider.dart';
import '../providers/promotions_provider.dart';
import '../providers/rabbit_provider.dart';
import '../config/features.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/author_avatar.dart';
import '../widgets/home_sections.dart';
import '../widgets/chat_icon_button.dart';
import '../widgets/promo_carousels.dart';
import '../widgets/wave_edge.dart';
import '../widgets/reminders.dart';
import 'activity_screen.dart';
import 'main_navigation_screen.dart';
import 'rabbit_list_screen.dart';
import 'matings_screen.dart';
import 'care_screen.dart';
import 'marketplace_screen.dart';
import '../widgets/app_icon.dart';

/// Horizon du rappel sur la page d'accueil : actions dues dans les 3 prochains
/// jours (ou déjà en retard). Le reste est consultable sur la page Activité.
const int _reminderHorizonDays = 3;

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
      if (Features.pharmacy) context.read<PharmacyProvider>().fetchAll();
      final community = context.read<CommunityProvider>();
      if (community.posts.isEmpty) community.fetchPosts(token: token);
      if (Features.marketplace) {
        context.read<MarketplaceProvider>().fetchListings();
      }
      context.read<PromotionsProvider>().fetchCarousels();
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
        final marketplace = context.watch<MarketplaceProvider>();

        final topInset = MediaQuery.of(context).padding.top;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          // Icônes de la barre d'état en blanc sur le haut sombre
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.pageBackground,
            body: Column(
              children: [
                // ---- Navbar fixe : Bonjour éleveur, nom de ferme, chat & profil ----
                Container(
                  width: double.infinity,
                  color: const Color(0xFF000000),
                  padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 14),
                  child: _buildTopHeader(context),
                ),

                // ---- Contenu scrollable sous la navbar fixe ----
                Expanded(
                  child: RefreshIndicator(
                    onRefresh:
                        () => provider.fetchAll(
                          token: context.read<AuthProvider>().token,
                        ),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ---- Haut noir en dégradé : résumé de l'activité ----
                          Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF000000),
                                  Color(0xFF141416),
                                  Color(0xFF1E1E24),
                                ],
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Section "Résumé de l'activité" (Scroll horizontal)
                                const Text(
                                  'Résumé de l\'activité',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                _buildHorizontalActivitySummary(
                                  context,
                                  provider,
                                  totalIncome,
                                  totalExpense,
                                  balance,
                                  currency,
                                ),
                              ],
                            ),
                          ),

                          // Transition en vague, à cheval sur le carrousel d'annonces
                          _buildCarouselBridge(context),

                          // ---- Bas : fond habituel ----
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Actions rapides : saillie, lapin, vente, soin
                          const QuickActions(),
                          const SizedBox(height: 20),

                          // 2bis-b. Rappel : actions à mener dans les prochains jours
                          _buildReminderSection(context, provider),

                          const SizedBox(height: 20),

                          // 3. Section "Menu Principal" (Les cards du menu)

                          // 3. Menu principal : trois carrés alignés (noir, violet, blanc)
                          Row(
                            children: [
                              Expanded(
                                child: _buildSquareMenuCard(
                                  key: const ValueKey('menu-rabbits'),
                                  imageAsset: 'assets/meslapins.webp',
                                  title: 'Mes lapins',
                                  detail:
                                      '${provider.totalRabbitsCount} lapins',
                                  background: AppColors.primary,
                                  foreground: Colors.white,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                const RabbitListScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSquareMenuCard(
                                  key: const ValueKey('menu-reproduction'),
                                  imageAsset: 'assets/reproduction.webp',
                                  title: 'Reproduction',
                                  detail:
                                      '${provider.matings.where((m) => m.isActive).length} en cours${provider.littersToWeanCount > 0 ? ' · ${provider.littersToWeanCount} à sevrer' : ''}',
                                  background: AppColors.secondary,
                                  foreground: Colors.white,
                                  onTap: () {
                                    // Des lapereaux à sevrer : on ouvre directement l'onglet des mises bas
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => const MatingsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildSquareMenuCard(
                                  key: const ValueKey('menu-care'),
                                  imageAsset: 'assets/veto.jpeg',
                                  title: 'Soins & entretien',
                                  detail: _careBadge(provider),
                                  detailColor:
                                      provider.pendingCareCount > 0
                                          ? AppColors.statusAlertText
                                          : null,
                                  background: Colors.white,
                                  foreground: AppColors.textPrimary,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => const CareScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Card 4: Petites annonces entre éleveurs (masquée pour l'instant)
                          if (Features.marketplace) ...[
                            _buildMenuCard(
                              context: context,
                              icon: Icons.storefront_outlined,
                              title: 'Petites annonces',
                              subtitle:
                                  'Reproducteurs, matériel, alimentation et saillies entre éleveurs',
                              badge: '${marketplace.availableCount} annonces',
                              badgeColor: AppColors.primarySoft,
                              badgeTextColor: AppColors.primary,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const MarketplaceScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Finances : solde du mois et 6 derniers mois
                          const HomeSectionTitle('Finances'),
                          const SizedBox(height: 10),
                          const FinanceGlance(),
                          const SizedBox(height: 24),

                          // Communauté : dernières publications et messages non lus
                          const CommunityGlance(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
},
);
  }

  /// Carrousels d'annonces posés à cheval sur la transition : le noir
  /// s'arrête au milieu de la première carte ; la 1re lame du dégradé finit au
  /// bas de la carte, les deux autres juste après. Sans annonce, seule la
  /// vague reste.
  Widget _buildCarouselBridge(BuildContext context) {
    const topWaveColor = Color(0xFF1E1E24);
    final hasAds = context.select<PromotionsProvider, bool>(
      (p) => p.carousels.isNotEmpty,
    );
    if (!hasAds) return const WaveEdge(color: topWaveColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardHeight = PromoCarouselView.cardHeight(width - 32);
        // Le creux de la vague pleine tombe au milieu de la carte, la 1re
        // lame s'arrête au bas de la carte, les deux autres juste après.
        final solidHeight = cardHeight / 2 - WaveEdge.waveHeight(width);
        final firstBlade = cardHeight / 2;
        final bladesTotal = WaveEdge.bladeWidths(
          firstBlade,
        ).reduce((a, b) => a + b);
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(height: solidHeight, color: topWaveColor),
                  WaveEdge(color: topWaveColor, firstBlade: firstBlade),
                ],
              ),
            ),
            // Hauteur minimale : les lames sous la carte restent dans la section
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: cardHeight / 2 + bladesTotal,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: PromoCarousels(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Rappel horizontal des actions à mener dans les prochains jours (palpations,
  /// mises bas, soins). Vide si rien n'est dû bientôt ; "Voir plus" ouvre la
  /// page Activité avec toutes les actions, sans limite de délai.
  Widget _buildReminderSection(BuildContext context, RabbitProvider provider) {
    final breedingSettings = context.watch<BreedingSettingsProvider>().settings;
    final all = buildReminders(provider, breedingSettings);
    final nearTerm =
        all.where((i) => i.daysUntilDue <= _reminderHorizonDays).toList();
    if (nearTerm.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'À faire bientôt',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            TextButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActivityScreen(),
                    ),
                  ),
              child: const Text(
                'Voir plus',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final item in nearTerm) ...[
                ReminderCard(item: item, provider: provider),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Badge de la carte « Soins & entretien » : ce qu'il faut faire en priorité.
  String _careBadge(RabbitProvider provider) {
    final overdue =
        provider.upcomingCares
            .where((c) => c.status == DueStatus.overdue)
            .length;
    if (overdue > 0) return '$overdue en retard';
    if (provider.pendingCareCount > 0) {
      return '${provider.pendingCareCount} à faire';
    }
    return 'À jour';
  }

  String _careDetail(RabbitProvider provider) {
    final overdue =
        provider.upcomingCares
            .where((c) => c.status == DueStatus.overdue)
            .length;
    if (overdue > 0) return '$overdue en retard';
    if (provider.pendingCareCount > 0) return 'À faire cette semaine';
    return 'Aucun soin en retard';
  }

  /// Calcule le détail dynamique pour la carte Gestations :
  /// - S'il n'y a aucune gestation en cours : 'Aucune en cours'
  /// - Sinon, temps restant jusqu'à la prochaine mise bas attendue.
  String _gestationDetail(BuildContext context, RabbitProvider provider) {
    final count = provider.activePregnanciesCount;
    if (count == 0) return 'Aucune en cours';

    final breedingSettings = context.watch<BreedingSettingsProvider>().settings;
    final matings = provider.matingsAwaitingKindling;
    if (matings.isEmpty) {
      return '$count en cours';
    }

    // Trouver le nombre minimum de jours jusqu'à la prochaine mise bas
    int minDays = 999999;
    for (final m in matings) {
      final days = m.daysUntilKindlingWith(breedingSettings.gestationDays);
      if (days < minDays) {
        minDays = days;
      }
    }

    if (minDays <= -2) {
      return 'En retard (${minDays.abs()} j)';
    } else if (minDays == -1) {
      return 'En retard (1 j)';
    } else if (minDays == 0) {
      return 'Prévue aujourd\'hui';
    } else if (minDays == 1) {
      return 'Prévue demain';
    } else {
      return 'Prochaine dans $minDays j';
    }
  }

  /// Pictogramme d'une carte : une icône vectorielle [AppIcons], ou une icône Material.
  Widget _iconOf(Object icon, {required double size, required Color color}) {
    if (icon is AppIcons) return AppIcon(icon, size: size, color: color);
    if (icon is IconData) return Icon(icon, size: size, color: color);
    return const SizedBox.shrink();
  }

  Widget _buildTopHeader(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final farmName = user?.farmName?.isNotEmpty == true ? user!.farmName! : '';
    final displayFirstName =
        user?.firstName?.trim().isNotEmpty == true
            ? user!.firstName!
                .split(RegExp(r'\s+'))
                .where((part) => part.isNotEmpty)
                .last
            : null;

    final displayName =
        user?.lastName?.isNotEmpty == true
            ? 'Bonjour, ${user!.lastName}'
            : displayFirstName != null
            ? 'Bonjour, $displayFirstName'
            : 'Bonjour, Éleveur';

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
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: Colors.white.withAlpha(170),
                ),
                const SizedBox(width: 4),
                Text(
                  farmName.isEmpty ? 'Nom de ferme non défini' : farmName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            const ChatIconButton(color: Colors.white),
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
    BuildContext context,
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
            icon: AppIcons.rabbit,
            value: '${provider.totalRabbitsCount}',
            label: 'Cheptel total',
            detail: '${provider.males.length} ♂ • ${provider.females.length} ♀',
            badge: 'Reproducteurs',
          ),
          const SizedBox(width: 12),

          // Stat Card 2: Gestations
          _buildActivityStatCard(
            icon: Icons.hourglass_empty,
            value: '${provider.activePregnanciesCount}',
            label: 'Gestations',
            detail: _gestationDetail(context, provider),
            badge: 'Mise bas',
          ),
          const SizedBox(width: 12),

          // Stat Card 3: Lapereaux présents sans fiche (au nid + sevrés à nommer)
          _buildActivityStatCard(
            icon: AppIcons.nest,
            value: '${provider.totalKitsPresent}',
            label: 'Lapereaux',
            detail:
                '${provider.totalKitsInNests} au nid · ${provider.totalKitsToName} à nommer',
            badge: 'Présents',
          ),
          const SizedBox(width: 12),

          // Stat Card 4: Soins dus
          _buildActivityStatCard(
            icon: AppIcons.syringe,
            value: '${provider.pendingCareCount}',
            label: 'Soins dus',
            detail: _careDetail(provider),
            badge: 'Sanitaire',
          ),
          const SizedBox(width: 12),

          // Stat Card 5: Finances
          _buildActivityStatCard(
            icon: Icons.payments_outlined,
            value: currency.format(balance, showSign: true, decimals: 0),
            label: 'Bilan clapier',
            detail:
                'Ventes: ${currency.format(totalIncome, showSign: true, decimals: 0)}',
            badge: balance >= 0 ? 'Bénéfice' : 'Déficit',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityStatCard({
    required Object icon,
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
          color: isHighlighted ? Colors.white.withAlpha(200) : AppColors.cardBorder,
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isHighlighted ? 40 : 6),
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
              _iconOf(
                icon,
                size: 26,
                color: isHighlighted ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isHighlighted ? Colors.white : AppColors.primarySoft,
                    border: Border.all(
                      color: isHighlighted ? Colors.white : AppColors.primary,
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

  /// Carte carrée du menu principal : illustration sur un panneau clair,
  /// titre et compteur dessous. [background] : noir, violet ou blanc.
  Widget _buildSquareMenuCard({
    required Key key,
    required String imageAsset,
    required String title,
    required String detail,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
    Color? detailColor,
  }) {
    final isWhite = background == Colors.white;
    // Fond en teinte légère (opacité réduite) pour laisser voir les images ;
    // le texte reprend alors la couleur pleine de la carte pour rester lisible.
    final fill = isWhite ? background : background.withAlpha(46);
    final ink = isWhite ? foreground : background;
    return AspectRatio(
      key: key,
      aspectRatio: 1,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: isWhite ? Border.all(color: AppColors.cardBorder) : null,
            ),
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Panneau clair : les illustrations restent lisibles sur le noir et le violet
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      // color: isWhite ? AppColors.pageBackground : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    clipBehavior: Clip.antiAlias,
                    padding:
                        imageAsset.endsWith('.webp')
                            ? const EdgeInsets.all(3)
                            : EdgeInsets.zero,
                    child: Image.asset(
                      imageAsset,
                      // Illustrations détourées entières, photos en plein cadre
                      fit:BoxFit.contain
                     
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: detailColor ?? ink.withAlpha(isWhite ? 150 : 190),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required Object icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
    String? imageAsset,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        // border: Border.all(color: AppColors.cardBorder),
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
          padding: const EdgeInsets.all(7),
          child: Row(
            children: [
              // Icon container (ou vignette photo si fournie)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: badgeColor),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child:
                    imageAsset != null
                        ? Image.asset(imageAsset, fit: BoxFit.cover)
                        : _iconOf(icon, size: 32, color: AppColors.primary),
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
