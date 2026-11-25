import '../utils/formatters.dart';
import '../widgets/app_ui.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/wave_edge.dart';
import 'add_rabbit_screen.dart';
import '../widgets/app_icon.dart';

class RabbitDetailScreen extends StatefulWidget {
  final Rabbit rabbit;

  const RabbitDetailScreen({super.key, required this.rabbit});

  @override
  State<RabbitDetailScreen> createState() => _RabbitDetailScreenState();
}

class _RabbitDetailScreenState extends State<RabbitDetailScreen> {
  late Rabbit _currentRabbit;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _currentRabbit = widget.rabbit;
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
                  showAppSnack(
                    context,
                    '${_currentRabbit.name} a été supprimé',
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
        final liveRabbit =
            provider.getRabbitById(_currentRabbit.id) ?? _currentRabbit;
        final topInset = MediaQuery.of(context).padding.top;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                // Navbar fixe noire
                _buildFixedNavbar(liveRabbit, topInset),

                // Contenu défilant unique
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // En-tête noir dégradé avec photo & métriques
                        Container(
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
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildRabbitHero(liveRabbit),
                              const SizedBox(height: 18),
                              _buildHeroStats(liveRabbit),
                            ],
                          ),
                        ),
                        const WaveEdge(color: Color(0xFF1E1E24)),

                        // Contenu sous la vague
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Informations générales
                              _buildGeneralInfoSection(liveRabbit),
                              const SizedBox(height: 24),

                              // 2. Bande des photos (scroll horizontal)
                              _buildPhotosHorizontalSection(liveRabbit, provider),
                              const SizedBox(height: 24),

                              // 3. Soins & Traitements
                              _buildCareSection(liveRabbit, provider),
                              const SizedBox(height: 24),

                              // Descendance / Portées (si reproducteur)
                              _buildDescendantsSection(liveRabbit, provider),
                              const SizedBox(height: 24),

                              // 4. Généalogie (en dernière position)
                              _buildGenealogySection(liveRabbit, provider),
                            ],
                          ),
                        ),
                      ],
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

  // ---- Navbar fixe ----
  Widget _buildFixedNavbar(Rabbit rabbit, double topInset) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF000000),
      padding: EdgeInsets.fromLTRB(8, topInset + 6, 12, 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Retour',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              rabbit.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
            tooltip: 'Modifier',
            onPressed: _editRabbit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
            tooltip: 'Supprimer',
            onPressed: _confirmDelete,
          ),
        ],
      ),
    );
  }

  // ---- En-tête noir (style Profil) ----
  Widget _buildRabbitHero(Rabbit r) {
    const avatarSize = 84.0;
    final photoUrl = r.primaryPhotoUrl;

    return Row(
      children: [
        GestureDetector(
          onTap: () => _showAddPhotoSheet(context, r),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? Image.network(
                            ApiConstants.formatMediaUrl(photoUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarFallback(r),
                          )
                        : _buildAvatarFallback(r),
                  ),
                ),
              ),
              if (_isUploadingPhoto)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera,
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
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: Text(
                      r.genderSymbol,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: r.isMale ? Colors.lightBlueAccent : Colors.pinkAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${r.breed} • Bague: ${r.tagNumber}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withAlpha(200),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.statusActiveBg,
                      border: Border.all(color: AppColors.statusActiveText),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r.statusLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusActiveText,
                      ),
                    ),
                  ),
                  if (context.watch<RabbitProvider>().nursingKitsOf(r.id) > 0)
                    Container(
                      key: const ValueKey('header-nursing-kits'),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.statusPregnantBg,
                        border: Border.all(color: AppColors.statusPregnantText),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Builder(
                        builder: (context) {
                          final n = context.watch<RabbitProvider>().nursingKitsOf(r.id);
                          return Text(
                            '$n lapereau${n > 1 ? 'x' : ''} au nid',
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
    );
  }

  Widget _buildAvatarFallback(Rabbit r) {
    return Container(
      color: AppColors.primarySoft,
      child: const Center(
        child: AppIcon(
          AppIcons.rabbit,
          size: 38,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildHeroStats(Rabbit r) {
    Widget stat(String value, String label) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          stat(r.ageString, 'Âge'),
          stat(r.weightKg != null ? '${r.weightKg} kg' : '-', 'Poids'),
          stat(r.cageNumber.isNotEmpty ? r.cageNumber : '-', 'Cage'),
          stat(r.color.isNotEmpty ? r.color : '-', 'Robe'),
        ],
      ),
    );
  }

  // ---- 1. Informations générales ----
  Widget _buildGeneralInfoSection(Rabbit r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations Générales',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: appCardDecoration(),
          child: Column(
            children: [
              _buildInfoRow('Date de naissance', formatDate(r.birthDate)),
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
      ],
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

  // ---- 2. Bande photos scroll horizontal & modal "Voir plus" ----
  Widget _buildPhotosHorizontalSection(Rabbit rabbit, RabbitProvider provider) {
    final images = rabbit.images;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'Photos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${images.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (images.length > 3)
                  TextButton(
                    onPressed: () => _openAllPhotosModal(rabbit, provider),
                    child: const Text('Voir plus'),
                  ),
                TextButton.icon(
                  onPressed:
                      _isUploadingPhoto ? null : () => _showAddPhotoSheet(context, rabbit),
                  icon: const Icon(Icons.add_a_photo, size: 16),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (images.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: appCardDecoration(),
            child: Column(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 38,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aucune photo pour ce lapin',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ajoutez une photo pour identifier ce lapin.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddPhotoSheet(context, rabbit),
                  icon: const Icon(Icons.add_a_photo, size: 16),
                  label: const Text('Ajouter une photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final img = images[index];
                final fullUrl = ApiConstants.formatMediaUrl(img.imageUrl);
                return GestureDetector(
                  onTap: () => _showPhotoActionSheet(context, rabbit, img, provider),
                  child: Container(
                    width: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: img.isPrimary ? AppColors.primary : AppColors.cardBorder,
                        width: img.isPrimary ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(6),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          fullUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                        if (img.isPrimary)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade700,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '★',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _openAllPhotosModal(Rabbit rabbit, RabbitProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        return Consumer<RabbitProvider>(
          builder: (context, p, _) {
            final live = p.getRabbitById(rabbit.id) ?? rabbit;
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Galerie photo (${live.images.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.76,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: live.images.length,
                          itemBuilder: (context, index) {
                            final img = live.images[index];
                            return _buildPhotoCard(context, live, img, auth, p);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ---- 3. Soins & Traitements & modal "Voir plus" ----
  Widget _buildCareSection(Rabbit r, RabbitProvider provider) {
    final careRecords = provider.careRecordsOf(r.id);
    final upcomingCare = provider.upcomingCaresOf(r.id);
    final previewRecords = careRecords.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'Soins & Traitements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${careRecords.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (careRecords.length > 3)
              TextButton(
                onPressed: () => _openAllCareModal(r, provider),
                child: const Text('Voir plus'),
              ),
            TextButton.icon(
              key: const ValueKey('rabbit-add-care'),
              onPressed: () => showCareRecordSheet(context, rabbitIds: [r.id]),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Soin'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Soins à venir
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
                CareCategoryIcon(
                  due.category,
                  size: 22,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${due.treatmentName} · ${formatDate(due.dueDate)}',
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
            decoration: appCardDecoration(),
            child: const Text(
              'Aucun soin spécifique enregistré pour le moment.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          )
        else ...[
          for (final care in previewRecords) _buildCareTile(care),
        ],
      ],
    );
  }

  Widget _buildCareTile(CareRecord care) {
    return Container(
      key: ValueKey('rabbit-care-${care.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: appCardDecoration(),
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
            child: CareCategoryIcon(
              care.category,
              size: 24,
              color: AppColors.primary,
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
                    formatDate(care.date),
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
    );
  }

  void _openAllCareModal(Rabbit r, RabbitProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<RabbitProvider>(
          builder: (context, p, _) {
            final careRecords = p.careRecordsOf(r.id);
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Historique des soins (${careRecords.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: careRecords.length,
                          itemBuilder: (context, index) {
                            return _buildCareTile(careRecords[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ---- Descendance & Portées ----
  Widget _buildDescendantsSection(Rabbit r, RabbitProvider provider) {
    final children = provider.getChildren(r.id);
    final litters = provider.littersOf(r.id);

    if (children.isEmpty && litters.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Descendance & Portées',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (litters.isNotEmpty)
              Text(
                'Portées (${litters.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (litters.isNotEmpty) ...[
          _buildLitterTotals(litters),
          const SizedBox(height: 10),
          for (final l in litters) _buildLitterTile(r, l, provider),
        ],
        if (children.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Fiches descendantes (${children.length})',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
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

  // ---- 4. Arbre généalogique (Dernière position) ----
  Widget _buildGenealogySection(Rabbit r, RabbitProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Arbre Généalogique Cunicole',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Visualisation des ascendants sur 3 générations (Sujet, Parents, Grands-parents). Touchez un ancêtre pour voir sa fiche.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: appCardDecoration(),
          child: Center(
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
        ),
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
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
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
    final partner = provider.getRabbitById(
      r.isFemale ? l.fatherId : l.motherId,
    );
    final status = l.status;
    final (bg, fg, badge) = switch (status) {
      LitterStatus.nursing => (
        AppColors.statusPregnantBg,
        AppColors.statusPregnantText,
        'Au nid',
      ),
      LitterStatus.weaningDue => (
        AppColors.statusAlertBg,
        AppColors.statusAlertText,
        'Sevrage à faire',
      ),
      LitterStatus.weaned => (
        AppColors.statusActiveBg,
        AppColors.statusActiveText,
        'Sevrée',
      ),
    };
    final d = l.daysUntilWeaning;
    final weaning = switch (status) {
      LitterStatus.weaned =>
        l.weanedAt != null
            ? 'Sevrée le ${formatDate(l.weanedAt!)}'
            : 'Sevrage terminé',
      LitterStatus.weaningDue =>
        d == 0
            ? 'Sevrage à faire aujourd\'hui'
            : 'Sevrage en retard de ${-d} j',
      LitterStatus.nursing =>
        'Sevrage dans $d j (${DateFormat('dd/MM').format(l.calculatedWeaningDate)})',
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
                    'Née le ${formatDate(l.birthDate)} · J${l.ageDays}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border.all(color: fg),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              partner == null
                  ? (r.isFemale ? 'Père inconnu' : 'Mère inconnue')
                  : '${r.isFemale ? 'Avec' : 'Avec la mère'} ${partner.name}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${l.bornAlive} nés vivants · ${l.kitsRemaining} au nid · ${l.weaned} sevrés'
              '${l.stillBorn + l.diedCount > 0 ? ' · ${l.stillBorn + l.diedCount} perte${l.stillBorn + l.diedCount > 1 ? 's' : ''}' : ''}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              weaning,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    status == LitterStatus.weaningDue
                        ? AppColors.statusAlertText
                        : AppColors.primary,
              ),
            ),
          ],
        ),
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
                      child: Icon(Icons.camera_alt, color: AppColors.primary),
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
          showAppSnack(context, 'Photo ajoutée avec succès !');
        } else {
          showAppSnack(context, 'Échec du téléversement de la photo.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        showAppSnack(context, 'Erreur: $e');
      }
    }
  }

  void _showPhotoActionSheet(
    BuildContext context,
    Rabbit rabbit,
    RabbitImageModel img,
    RabbitProvider provider,
  ) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final fullUrl = ApiConstants.formatMediaUrl(img.imageUrl);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: const Icon(Icons.fullscreen, color: AppColors.primary),
                ),
                title: const Text('Voir en plein écran'),
                onTap: () {
                  Navigator.pop(ctx);
                  _viewPhotoFullscreen(context, fullUrl, img.caption);
                },
              ),
              if (!img.isPrimary)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.shade50,
                    child: Icon(Icons.star, color: Colors.amber.shade700),
                  ),
                  title: const Text('Définir comme photo de profil'),
                  subtitle: const Text('Cette photo sera la photo principale du lapin'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setPrimary(rabbit, img.id, auth, provider);
                  },
                ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
                title: const Text(
                  'Supprimer cette photo',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeletePhoto(rabbit, img.id, auth, provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
    if (mounted) {
      if (success) {
        final updated = provider.getRabbitById(rabbit.id);
        if (updated != null) {
          setState(() => _currentRabbit = updated);
        }
        showAppSnack(context, 'Photo de profil mise à jour !');
      } else {
        showAppSnack(context, 'Impossible de définir cette photo comme principale.');
      }
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
                  if (mounted) {
                    if (success) {
                      final updated = provider.getRabbitById(rabbit.id);
                      if (updated != null) {
                        setState(() => _currentRabbit = updated);
                      }
                      showAppSnack(context, 'Photo supprimée avec succès');
                    } else {
                      showAppSnack(context, 'Échec de la suppression de la photo');
                    }
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
