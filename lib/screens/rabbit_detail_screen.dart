import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/care.dart';
import '../models/litter.dart';
import '../models/rabbit.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/care_sheets.dart';
import '../widgets/genealogy_tree_widget.dart';
import '../widgets/rabbit_avatar.dart';
import 'add_rabbit_screen.dart';

class RabbitDetailScreen extends StatefulWidget {
  final Rabbit rabbit;

  const RabbitDetailScreen({super.key, required this.rabbit});

  @override
  State<RabbitDetailScreen> createState() => _RabbitDetailScreenState();
}

class _RabbitDetailScreenState extends State<RabbitDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Rabbit _currentRabbit;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _currentRabbit = widget.rabbit;
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _editRabbit() async {
    final updated = await Navigator.push<Rabbit>(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddRabbitScreen(initialRabbitToEdit: _currentRabbit),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _currentRabbit = updated;
      });
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer ce lapin ?'),
            content: Text(
              'Voulez-vous vraiment supprimer ${_currentRabbit.name} (${_currentRabbit.tagNumber}) de votre cheptel ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () {
                  Provider.of<RabbitProvider>(
                    context,
                    listen: false,
                  ).deleteRabbit(_currentRabbit.id);
                  Navigator.pop(ctx); // close dialog
                  Navigator.pop(context); // back to list
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${_currentRabbit.name} a été supprimé'),
                    ),
                  );
                },
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        // Keep updated instance if provider modified it
        final liveRabbit =
            provider.getRabbitById(_currentRabbit.id) ?? _currentRabbit;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(liveRabbit.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: _editRabbit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _confirmDelete,
              ),
            ],
          ),
          body: SafeArea(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          _buildProfileHeaderCard(liveRabbit),
                          const SizedBox(height: 16),
                          TabBar(
                            controller: _tabController,
                            indicatorColor: AppColors.primary,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textSecondary,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            tabs: [
                              Tab(text: 'Photos (${liveRabbit.images.length})'),
                              const Tab(text: 'Généalogie'),
                              const Tab(text: 'Descendance'),
                              const Tab(text: 'Détails & Soins'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Photos & Galerie
                  _buildPhotosTab(liveRabbit, provider),

                  // Tab 1: Pedigree / Family Tree
                  _buildGenealogyTab(liveRabbit, provider),

                  // Tab 2: Descendants / Kits
                  _buildDescendantsTab(liveRabbit, provider),

                  // Tab 3: Details & Health
                  _buildDetailsAndCareTab(liveRabbit, provider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeaderCard(Rabbit r) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              RabbitAvatar(rabbit: r, size: 68),
              GestureDetector(
                onTap: () => _showAddPhotoSheet(context, r),
                child: Stack(
                  children: [
                    RabbitAvatar(rabbit: r, size: 68),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 20,
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
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            r.genderSymbol,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color:
                                  r.isMale
                                      ? AppColors.maleBlue
                                      : AppColors.femalePink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.breed} • Bague: ${r.tagNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusActiveBg,
                            border: Border.all(color: AppColors.statusActiveText),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            r.statusLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.statusActiveText,
                            ),
                          ),
                        ),
                        // Lapereaux non sevrés avec cette lapine
                        if (context.watch<RabbitProvider>().nursingKitsOf(r.id) > 0)
                          Container(
                            key: const ValueKey('header-nursing-kits'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusPregnantBg,
                              border: Border.all(color: AppColors.statusPregnantText),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Builder(
                              builder: (context) {
                                final n = context
                                    .watch<RabbitProvider>()
                                    .nursingKitsOf(r.id);
                                return Text(
                                  '🍼 $n lapereau${n > 1 ? 'x' : ''} au nid',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.statusPregnantText,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniMetric('ÂGE', r.ageString),
              _buildMiniMetric(
                'POIDS',
                r.weightKg != null ? '${r.weightKg} kg' : '-',
              ),
              _buildMiniMetric('CAGE', r.cageNumber),
              _buildMiniMetric('ROBE', r.color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildGenealogyTab(Rabbit r, RabbitProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Arbre Généalogique Cunicole',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Visualisation des ascendants sur 3 générations (Sujet, Parents, Grands-parents). Touchez un ancêtre pour voir sa fiche.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Center(
            child: GenealogyTreeWidget(
              rabbit: r,
              provider: provider,
              onSelectRabbit: (selected) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RabbitDetailScreen(rabbit: selected),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescendantsTab(Rabbit r, RabbitProvider provider) {
    final children = provider.getChildren(r.id);
    final litters = provider.littersOf(r.id);

    if (children.isEmpty && litters.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🍼', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text(
                'Aucune portée ni descendance enregistrée',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Les mises bas et les lapereaux sevrés de ce reproducteur apparaîtront ici automatiquement.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (litters.isNotEmpty) ...[
          sectionTitle('Portées (${litters.length})'),
          _buildLitterTotals(litters),
          const SizedBox(height: 10),
          for (final l in litters) _buildLitterTile(r, l, provider),
        ],
        if (children.isNotEmpty) ...[
          const SizedBox(height: 8),
          sectionTitle('Fiches descendantes (${children.length})'),
          for (final childRabbit in children)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: RabbitAvatar(rabbit: childRabbit, size: 40),
                title: Text(
                  childRabbit.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${childRabbit.breed} • Bague: ${childRabbit.tagNumber} (${childRabbit.ageString})',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RabbitDetailScreen(rabbit: childRabbit),
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }

  /// Totaux de toutes les portées du lapin : portées, nés vivants, au nid, sevrés.
  Widget _buildLitterTotals(List<Litter> litters) {
    final born = litters.fold<int>(0, (s, l) => s + l.bornAlive);
    final atNest = litters.fold<int>(0, (s, l) => s + l.kitsRemaining);
    final weaned = litters.fold<int>(0, (s, l) => s + l.weaned);

    Widget cell(String value, String label, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );

    return Container(
      key: const ValueKey('litter-totals'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primarySoftBorder),
      ),
      child: Row(
        children: [
          cell('${litters.length}', litters.length > 1 ? 'Portées' : 'Portée'),
          cell('$born', 'Nés vivants'),
          cell('$atNest', 'Au nid', color: AppColors.statusPregnantText),
          cell('$weaned', 'Sevrés', color: AppColors.maleBlue),
        ],
      ),
    );
  }

  Widget _buildLitterTile(Rabbit r, Litter l, RabbitProvider provider) {
    final partner = provider.getRabbitById(r.isFemale ? l.fatherId : l.motherId);
    final status = l.status;
    final (bg, fg, badge) = switch (status) {
      LitterStatus.nursing => (AppColors.statusPregnantBg, AppColors.statusPregnantText, 'Au nid'),
      LitterStatus.weaningDue => (AppColors.statusAlertBg, AppColors.statusAlertText, 'Sevrage à faire'),
      LitterStatus.weaned => (AppColors.statusActiveBg, AppColors.statusActiveText, 'Sevrée'),
    };
    final d = l.daysUntilWeaning;
    final weaning = switch (status) {
      LitterStatus.weaned =>
        l.weanedAt != null
            ? 'Sevrée le ${DateFormat('dd/MM/yyyy').format(l.weanedAt!)}'
            : 'Sevrage terminé',
      LitterStatus.weaningDue =>
        d == 0 ? 'Sevrage à faire aujourd\'hui' : 'Sevrage en retard de ${-d} j',
      LitterStatus.nursing => 'Sevrage dans $d j (${DateFormat('dd/MM').format(l.calculatedWeaningDate)})',
    };

    return Card(
      key: ValueKey('rabbit-litter-${l.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Née le ${DateFormat('dd/MM/yyyy').format(l.birthDate)} · J${l.ageDays}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: bg, border: Border.all(color: fg), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    badge,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              partner == null
                  ? (r.isFemale ? 'Père inconnu' : 'Mère inconnue')
                  : '${r.isFemale ? 'Avec' : 'Avec la mère'} ${partner.name}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '${l.bornAlive} nés vivants · ${l.kitsRemaining} au nid · ${l.weaned} sevrés'
              '${l.stillBorn + l.diedCount > 0 ? ' · ${l.stillBorn + l.diedCount} perte${l.stillBorn + l.diedCount > 1 ? 's' : ''}' : ''}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              weaning,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: status == LitterStatus.weaningDue ? AppColors.statusAlertText : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsAndCareTab(Rabbit r, RabbitProvider provider) {
    final careRecords = provider.careRecordsOf(r.id);
    final upcomingCare = provider.upcomingCaresOf(r.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations Générales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Date de naissance',
                  DateFormat('dd/MM/yyyy').format(r.birthDate),
                ),
                const Divider(height: 16),
                _buildInfoRow('Couleur / Robe', r.color),
                const Divider(height: 16),
                _buildInfoRow('Clapier / Cage', r.cageNumber),
                const Divider(height: 16),
                _buildInfoRow(
                  'Poids enregistré',
                  r.weightKg != null ? '${r.weightKg} kg' : 'Non renseigné',
                ),
                if (r.notes != null && r.notes!.isNotEmpty) ...[
                  const Divider(height: 16),
                  _buildInfoRow('Observations', r.notes!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Soins & Traitements Sanitaires',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('rabbit-add-care'),
                onPressed:
                    () => showCareRecordSheet(context, rabbitIds: [r.id]),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Soin'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final due in upcomingCare)
            Container(
              key: ValueKey('rabbit-due-${due.recordId}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color:
                    due.status == DueStatus.overdue
                        ? AppColors.statusAlertBg
                        : due.status == DueStatus.soon
                        ? AppColors.statusPregnantBg
                        : AppColors.statusActiveBg,
                border: Border.all(
                  color:
                      due.status == DueStatus.overdue
                          ? AppColors.statusAlertText
                          : due.status == DueStatus.soon
                          ? AppColors.statusPregnantText
                          : AppColors.statusActiveText,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(due.category.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${due.treatmentName} · ${DateFormat('dd/MM/yyyy').format(due.dueDate)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    due.dueLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          if (careRecords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Text(
                'Aucun soin spécifique enregistré pour le moment.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            ...careRecords.map(
              (care) => Container(
                key: ValueKey('rabbit-care-${care.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        border: Border.all(color: AppColors.cardBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        care.category.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            care.treatmentName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            [
                              DateFormat('dd/MM/yyyy').format(care.date),
                              if (care.purpose.isNotEmpty) care.purpose,
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosTab(Rabbit rabbit, RabbitProvider provider) {
    final images = rabbit.images;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_rabbit_photo',
        onPressed:
            _isUploadingPhoto
                ? null
                : () => _showAddPhotoSheet(context, rabbit),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon:
            _isUploadingPhoto
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Icon(Icons.add_a_photo, size: 20),
        label: Text(_isUploadingPhoto ? 'Envoi...' : 'Ajouter une photo'),
      ),
      body:
          _isUploadingPhoto && images.isEmpty
              ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text('Téléversement de la photo en cours...'),
                  ],
                ),
              )
              : images.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune photo pour ce lapin',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ajoutez des photos pour illustrer son évolution et faciliter son identification.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _showAddPhotoSheet(context, rabbit),
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: const Text('Ajouter la première photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.76,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final img = images[index];
                  return _buildPhotoCard(context, rabbit, img, auth, provider);
                },
              ),
    );
  }

  Widget _buildPhotoCard(
    BuildContext context,
    Rabbit rabbit,
    RabbitImageModel img,
    AuthProvider auth,
    RabbitProvider provider,
  ) {
    final fullUrl = ApiConstants.formatMediaUrl(img.imageUrl);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: img.isPrimary ? AppColors.primary : AppColors.cardBorder,
          width: img.isPrimary ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Area
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap:
                      () => _viewPhotoFullscreen(context, fullUrl, img.caption),
                  child: Image.network(
                    fullUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          color: Colors.white,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 36,
                            ),
                          ),
                        ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.white,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Primary badge
                if (img.isPrimary)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            'Principale',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Zoom tap hint
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Actions footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!img.isPrimary)
                  Expanded(
                    child: InkWell(
                      onTap: () => _setPrimary(rabbit, img.id, auth, provider),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.star_border,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Définir principale',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Photo de profil',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Supprimer cette photo',
                  onPressed:
                      () => _confirmDeletePhoto(rabbit, img.id, auth, provider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddPhotoSheet(BuildContext context, Rabbit rabbit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ajouter une photo de ${rabbit.name}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.camera_alt,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('Prendre une photo'),
                    subtitle: const Text('Utiliser l\'appareil photo'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadPhoto(rabbit, ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        Icons.photo_library,
                        color: AppColors.primary,
                      ),
                    ),
                    title: const Text('Choisir dans la galerie'),
                    subtitle: const Text('Sélectionner depuis vos albums'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _uploadPhoto(rabbit, ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _uploadPhoto(Rabbit rabbit, ImageSource source) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<RabbitProvider>(context, listen: false);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);

      final success = await provider.uploadRabbitPhoto(
        rabbit.id,
        File(picked.path),
        isPrimary: rabbit.images.isEmpty,
        token: auth.token,
      );

      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo ajoutée avec succès !'),
              backgroundColor: AppColors.primary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Échec du téléversement de la photo.'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  Future<void> _setPrimary(
    Rabbit rabbit,
    int imageId,
    AuthProvider auth,
    RabbitProvider provider,
  ) async {
    final success = await provider.setPrimaryPhoto(
      rabbit.id,
      imageId,
      token: auth.token,
    );
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo principale mise à jour ! ⭐'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _confirmDeletePhoto(
    Rabbit rabbit,
    int imageId,
    AuthProvider auth,
    RabbitProvider provider,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Supprimer cette photo ?'),
            content: const Text(
              'Cette action supprimera définitivement cette photo de la galerie.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final success = await provider.deleteRabbitPhoto(
                    rabbit.id,
                    imageId,
                    token: auth.token,
                  );
                  if (mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Photo supprimée avec succès'),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _viewPhotoFullscreen(
    BuildContext context,
    String imageUrl,
    String? caption,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 60,
                          ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                if (caption != null && caption.isNotEmpty)
                  Positioned(
                    bottom: 30,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}
