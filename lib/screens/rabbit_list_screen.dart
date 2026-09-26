import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cage.dart';
import '../models/rabbit.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../services/api_constants.dart';
import 'add_rabbit_screen.dart';
import 'cages_screen.dart';
import 'rabbit_detail_screen.dart';

class RabbitListScreen extends StatefulWidget {
  const RabbitListScreen({super.key});

  @override
  State<RabbitListScreen> createState() => _RabbitListScreenState();
}

/// Façon d'afficher les lapins : cartes en grille, ou rangés dans leurs cages.
enum RabbitListView { grid, cages }

class _RabbitListScreenState extends State<RabbitListScreen> {
  static const _viewPrefKey = 'rabbit_list_view';

  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: Tous, 1: Mâles, 2: Femelles, 3: Gestantes
  RabbitListView _view = RabbitListView.grid;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
  }

  /// Retrouve la dernière vue choisie (grille ou cages)
  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_viewPrefKey) == RabbitListView.cages.name &&
          mounted) {
        setState(() => _view = RabbitListView.cages);
      }
    } catch (_) {}
  }

  Future<void> _setView(RabbitListView view) async {
    setState(() => _view = view);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewPrefKey, view.name);
    } catch (_) {}
  }

  bool _matches(Rabbit r, String query) =>
      r.name.toLowerCase().contains(query) ||
      r.tagNumber.toLowerCase().contains(query) ||
      r.breed.toLowerCase().contains(query) ||
      r.cageNumber.toLowerCase().contains(query);

  bool _cageMatches(Cage c, String query) =>
      c.name.toLowerCase().contains(query) ||
      (c.location ?? '').toLowerCase().contains(query) ||
      c.slots.any(
        (slot) => slot.occupants.any(
          (o) =>
              o.name.toLowerCase().contains(query) ||
              o.tagNumber.toLowerCase().contains(query),
        ),
      );

  void _addRabbit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddRabbitScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        final query = _searchQuery.trim().toLowerCase();

        List<Rabbit> filtered = provider.rabbits;
        if (_selectedFilterIndex == 1) {
          filtered = provider.males;
        } else if (_selectedFilterIndex == 2) {
          filtered = provider.females;
        } else if (_selectedFilterIndex == 3) {
          filtered = provider.pregnantFemales;
        }
        if (query.isNotEmpty) {
          filtered = filtered.where((r) => _matches(r, query)).toList();
        }

        final inCagesView = _view == RabbitListView.cages;

        return Scaffold(
          appBar: AppBar(
            // Onglet principal : pas de flèche de retour quand il n'y a rien vers quoi revenir
            leading:
                Navigator.canPop(context)
                    ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                    : null,
            title: const Text('Mes Lapins'),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.add_circle,
                  color: AppColors.primary,
                  size: 28,
                ),
                tooltip: 'Ajouter un lapin',
                onPressed: _addRabbit,
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                final token = context.read<AuthProvider>().token;
                await Future.wait([
                  provider.fetchRabbits(token: token),
                  provider.fetchCages(token: token),
                ]);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // 1. Les cages, en tout premier
                  SliverToBoxAdapter(
                    child: _buildCagesStrip(context, provider),
                  ),

                  // 2. Recherche
                  SliverToBoxAdapter(child: _buildSearchBar()),

                  // 3. Filtres (propres à la grille)
                  if (!inCagesView)
                    SliverToBoxAdapter(child: _buildFilterChips(provider)),

                  // 4. Choix de la vue
                  SliverToBoxAdapter(
                    child: _buildViewToggle(
                      inCagesView ? provider.rabbits.length : filtered.length,
                    ),
                  ),

                  if (inCagesView)
                    ..._buildCagesViewSlivers(context, provider, query)
                  else
                    ..._buildGridSlivers(filtered),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab_rabbit_list',
            onPressed: _addRabbit,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nouveau Lapin'),
          ),
        );
      },
    );
  }

  // ---- Bande des cages ----

  Widget _buildCagesStrip(BuildContext context, RabbitProvider provider) {
    final cages = provider.cages;
    final total = cages.fold<int>(0, (s, c) => s + c.compartmentsCount);
    final occupied = cages.fold<int>(0, (s, c) => s + c.occupiedCount);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Text(
                  'Mes cages',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (cages.isNotEmpty)
                  Text(
                    '$occupied/$total loges occupées',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (cages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _AddCageTile(
                wide: true,
                onTap: () => showCageForm(context),
              ),
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: cages.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  if (i == cages.length) {
                    return _AddCageTile(onTap: () => showCageForm(context));
                  }
                  return _CageChip(cage: cages[i]);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: const InputDecoration(
            hintText: 'Rechercher par nom, bague, race, cage...',
            prefixIcon: Icon(Icons.search, color: AppColors.primary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(RabbitProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Row(
        children: [
          _buildFilterChip(0, 'Tous (${provider.rabbits.length})'),
          const SizedBox(width: 8),
          _buildFilterChip(1, 'Mâles ♂ (${provider.males.length})'),
          const SizedBox(width: 8),
          _buildFilterChip(2, 'Femelles ♀ (${provider.females.length})'),
          const SizedBox(width: 8),
          _buildFilterChip(
            3,
            'Gestantes ⏳ (${provider.pregnantFemales.length})',
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count lapin${count > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SegmentedButton<RabbitListView>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: Colors.white,
              foregroundColor: AppColors.textSecondary,
            ),
            segments: const [
              ButtonSegment(
                value: RabbitListView.grid,
                icon: Icon(Icons.grid_view_rounded, size: 18),
                label: Text('Grille'),
              ),
              ButtonSegment(
                value: RabbitListView.cages,
                icon: Icon(Icons.home_work_outlined, size: 18),
                label: Text('Cages'),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (v) => _setView(v.first),
          ),
        ],
      ),
    );
  }

  // ---- Vue grille ----

  List<Widget> _buildGridSlivers(List<Rabbit> rabbits) {
    if (rabbits.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(height: 350, child: _buildEmptyState()),
        ),
      ];
    }
    return [_rabbitGridSliver(rabbits)];
  }

  Widget _rabbitGridSliver(List<Rabbit> rabbits) {
    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 80),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.70,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGridRabbitCard(context, rabbits[index]),
          childCount: rabbits.length,
        ),
      ),
    );
  }

  // ---- Vue cages : chaque cage avec ses lapins dans leurs loges ----

  List<Widget> _buildCagesViewSlivers(
    BuildContext context,
    RabbitProvider provider,
    String query,
  ) {
    final allCages = provider.cages;
    final cages =
        query.isEmpty
            ? allCages
            : allCages.where((c) => _cageMatches(c, query)).toList();
    var unassigned = provider.rabbits.where((r) => r.cageId == null).toList();
    if (query.isNotEmpty) {
      unassigned = unassigned.where((r) => _matches(r, query)).toList();
    }

    if (allCages.isEmpty && unassigned.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(height: 350, child: _buildEmptyState()),
        ),
      ];
    }

    final cardWidth = (MediaQuery.of(context).size.width - 36 - 14) / 2;

    return [
      if (allCages.isNotEmpty && query.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          sliver: SliverToBoxAdapter(child: CageSummaryBar(cages: allCages)),
        ),
      if (allCages.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          sliver: SliverToBoxAdapter(
            child: _AddCageTile(wide: true, onTap: () => showCageForm(context)),
          ),
        ),
      if (cages.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final cage in cages)
                  CageCard(cage: cage, width: cardWidth),
              ],
            ),
          ),
        ),
      if (unassigned.isNotEmpty) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Text(
                  'Sans cage',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusPregnantBg,
                    border: Border.all(color: AppColors.statusPregnantText),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${unassigned.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusPregnantText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _rabbitGridSliver(unassigned),
      ] else
        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      if (query.isNotEmpty && cages.isEmpty && unassigned.isEmpty)
        SliverToBoxAdapter(
          child: SizedBox(height: 300, child: _buildEmptyState()),
        ),
    ];
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildGridRabbitCard(BuildContext context, Rabbit rabbit) {
    final photoUrl = rabbit.primaryPhotoUrl;
    // Fond blanc uni : la couleur n'apparaît que par la bordure et le contenu
    const bgColor = AppColors.primarySoft;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RabbitDetailScreen(rabbit: rabbit),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Header Section
              Expanded(
                flex: 11,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                        child:
                            photoUrl != null && photoUrl.isNotEmpty
                                ? Image.network(
                                  ApiConstants.formatMediaUrl(photoUrl),
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                          _buildPlaceholderPhoto(bgColor),
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: bgColor,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                                : _buildPlaceholderPhoto(bgColor),
                      ),
                    ),

                    // Gender badge overlay (Top Right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          rabbit.shortGenderSymbol,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Special status chip overlay (Top Left)
                    if (rabbit.status != RabbitStatus.active)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rabbit.status == RabbitStatus.pregnant
                                ? '⏳ Gestante'
                                : rabbit.status == RabbitStatus.lactating
                                ? '🍼 Allaitement'
                                : rabbit.status == RabbitStatus.resting
                                ? '💤 Repos'
                                : 'Réformé',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                    // Lapereaux non sevrés avec cette lapine (Bottom Left)
                    if (context.read<RabbitProvider>().nursingKitsOf(
                          rabbit.id,
                        ) >
                        0)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          key: ValueKey('kits-badge-${rabbit.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusPregnantBg,
                            border: Border.all(color: AppColors.statusPregnantText),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '🍼 ${context.read<RabbitProvider>().nursingKitsOf(rabbit.id)}',
                            style: const TextStyle(
                              color: AppColors.statusPregnantText,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                    // Gallery photo count badge (Bottom Right)
                    if (rabbit.images.length > 1)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${rabbit.images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Rabbit Info section
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rabbit.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rabbit.breed,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'C.${rabbit.cageNumber}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            rabbit.ageString,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderPhoto(Color bgColor) {
    return Container(
      color: bgColor,
      child: const Center(child: Text('🐰', style: TextStyle(fontSize: 38))),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 42)),
          const SizedBox(height: 12),
          const Text(
            'Aucun lapin trouvé',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Essayez un autre mot-clé ou filtre',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddRabbitScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter un reproducteur'),
          ),
        ],
      ),
    );
  }
}

/// Petite carte de cage pour la bande horizontale : nom, emplacement, loges occupées.
class _CageChip extends StatelessWidget {
  final Cage cage;

  const _CageChip({required this.cage});

  @override
  Widget build(BuildContext context) {
    final slots = cage.slots;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CageDetailScreen(cageId: cage.id),
              ),
            ),
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color:
                  cage.isFull
                      ? AppColors.statusPregnantText.withAlpha(90)
                      : AppColors.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cage ${cage.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                (cage.location ?? '').isEmpty ? ' ' : cage.location!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              // Une pastille par loge : pleine = occupée
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final slot in slots.take(16))
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color:
                            slot.isFree
                                ? Colors.transparent
                                : AppColors.primary,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color:
                              slot.isFree
                                  ? AppColors.primarySoftBorder
                                  : AppColors.primary,
                          width: 1.2,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${cage.occupiedCount}/${cage.compartmentsCount} loges${cage.kitsCount > 0 ? ' · 🍼${cage.kitsCount}' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      cage.isFull
                          ? AppColors.statusPregnantText
                          : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton « + Ajouter une cage » (grand quand il n'y a encore aucune cage).
class _AddCageTile extends StatelessWidget {
  final VoidCallback onTap;
  final bool wide;

  const _AddCageTile({required this.onTap, this.wide = false});

  @override
  Widget build(BuildContext context) {
    final content =
        wide
            ? const Row(
              children: [
                Icon(Icons.add_circle, color: AppColors.primary, size: 34),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ajouter une cage',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Créez vos cages pour loger vos lapins loge par loge.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
            : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle, color: AppColors.primary, size: 32),
                SizedBox(height: 6),
                Text(
                  'Ajouter\nune cage',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            );

    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          width: wide ? double.infinity : 112,
          padding: EdgeInsets.all(wide ? 16 : 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.primarySoftBorder),
          ),
          child: content,
        ),
      ),
    );
  }
}
