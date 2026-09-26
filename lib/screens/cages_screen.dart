import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cage.dart';
import '../models/rabbit.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/cage_diagram.dart';
import 'rabbit_detail_screen.dart';

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
      ),
    );
}

/// Bandeau récapitulatif : cages, loges, occupées, libres.
class CageSummaryBar extends StatelessWidget {
  final List<Cage> cages;

  const CageSummaryBar({super.key, required this.cages});

  @override
  Widget build(BuildContext context) {
    final totalSlots = cages.fold<int>(0, (s, c) => s + c.compartmentsCount);
    final occupied = cages.fold<int>(0, (s, c) => s + c.occupiedCount);
    final kits = cages.fold<int>(0, (s, c) => s + c.kitsCount);

    Widget item(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.primarySoftBorder),
      ),
      child: Row(
        children: [
          item('${cages.length}', cages.length > 1 ? 'Cages' : 'Cage'),
          item('$totalSlots', 'Loges'),
          item('$occupied', 'Occupées'),
          item('${totalSlots - occupied}', 'Libres'),
          if (kits > 0) item('🍼 $kits', 'Lapereaux'),
        ],
      ),
    );
  }
}

/// Carte d'une cage avec son schéma (les lapins dans leurs loges) ; ouvre le détail.
class CageCard extends StatelessWidget {
  final Cage cage;
  final double width;

  const CageCard({super.key, required this.cage, required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cage ${cage.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (cage.location != null && cage.location!.isNotEmpty)
                  Text(
                    cage.location!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    width: cage.columnsCount == 1 ? width * 0.62 : width - 24,
                    child: CageDiagram(cage: cage, compact: true),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        cage.isFull
                            ? AppColors.statusPregnantBg
                            : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${cage.occupiedCount}/${cage.compartmentsCount} loges occupées',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          cage.isFull
                              ? AppColors.statusPregnantText
                              : AppColors.primary,
                    ),
                  ),
                ),
                // Lapereaux non sevrés qui vivent dans cette cage avec leur mère
                if (cage.kitsCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    key: ValueKey('cage-kits-${cage.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusPregnantBg,
                      border: Border.all(color: AppColors.statusPregnantText),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '🍼 ${cage.kitsCount} lapereau${cage.kitsCount > 1 ? 'x' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusPregnantText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Création / modification d'une cage : nom, emplacement et nombre de loges,
/// avec aperçu graphique en direct.
Future<void> showCageForm(BuildContext context, {Cage? edit}) {
  final nameController = TextEditingController(text: edit?.name ?? '');
  final locationController = TextEditingController(text: edit?.location ?? '');
  final notesController = TextEditingController(text: edit?.notes ?? '');
  int rows = edit?.rowsCount ?? 3;
  int columns = edit?.columnsCount ?? 1;
  bool saving = false;
  String? error;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final preview = Cage(
            id: edit?.id ?? 'preview',
            name: nameController.text,
            rowsCount: rows,
            columnsCount: columns,
            compartments: [
              for (int i = 1; i <= rows * columns; i++)
                CageCompartment(
                  number: i,
                  occupants:
                      columns == edit?.columnsCount
                          ? edit?.slots
                              .where((s) => s.number == i)
                              .firstOrNull
                              ?.occupants
                          : null,
                ),
            ],
          );
          // Changer le nombre de colonnes décalerait les loges occupées.
          final columnsLocked = (edit?.occupiedCount ?? 0) > 0;

          Widget stepper({
            required String label,
            required int value,
            required int min,
            required int max,
            required ValueChanged<int> onChanged,
            bool locked = false,
          }) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      !locked && value > min
                          ? () => setState(() => onChanged(value - 1))
                          : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      !locked && value < max
                          ? () => setState(() => onChanged(value + 1))
                          : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            );
          }

          Future<void> submit() async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              setState(() => error = 'Donnez un nom à la cage');
              return;
            }
            setState(() {
              saving = true;
              error = null;
            });
            final provider = context.read<RabbitProvider>();
            final result = await provider.saveCage(
              Cage(
                id: edit?.id ?? '',
                name: name,
                location: locationController.text.trim(),
                notes: notesController.text.trim(),
                rowsCount: rows,
                columnsCount: columns,
              ),
              isNew: edit == null,
            );
            if (!ctx.mounted) return;
            if (result == null) {
              Navigator.pop(ctx);
              if (context.mounted) {
                _snack(
                  context,
                  edit == null ? 'Cage $name créée' : 'Cage $name mise à jour',
                );
              }
            } else {
              setState(() {
                saving = false;
                error = result;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    edit == null ? 'Nouvelle cage' : 'Modifier la cage',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              textCapitalization: TextCapitalization.characters,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Nom / code *',
                                hintText: 'A1',
                                prefixIcon: Icon(Icons.tag, size: 20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: locationController,
                              decoration: const InputDecoration(
                                labelText: 'Emplacement',
                                hintText: 'Bâtiment, rangée…',
                                prefixIcon: Icon(
                                  Icons.location_on_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            stepper(
                              label: 'Lignes',
                              value: rows,
                              min: 1,
                              max: Cage.maxRows,
                              onChanged: (v) => rows = v,
                            ),
                            stepper(
                              label: 'Colonnes',
                              value: columns,
                              min: 1,
                              max: Cage.maxColumns,
                              onChanged: (v) => columns = v,
                              locked: columnsLocked,
                            ),
                            if (columnsLocked)
                              const Text(
                                'Libérez les loges pour changer les colonnes.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              '${rows * columns} loge${rows * columns > 1 ? 's' : ''} au total',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: columns == 1 ? 96 : 130,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: columns == 1 ? 96 : 130,
                              child: CageDiagram(cage: preview, compact: true),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      prefixIcon: Icon(Icons.notes, size: 20),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: TextStyle(color: Colors.red.shade700)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : submit,
                      child: Text(
                        saving
                            ? 'Enregistrement…'
                            : (edit == null ? 'Créer la cage' : 'Enregistrer'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Détail d'une cage : grand schéma interactif. Toucher une loge permet d'y
/// placer un lapin (même dans une loge déjà occupée : elle peut en accueillir
/// plusieurs), de consulter les lapins présents ou d'en retirer un.
class CageDetailScreen extends StatefulWidget {
  final String cageId;

  const CageDetailScreen({super.key, required this.cageId});

  @override
  State<CageDetailScreen> createState() => _CageDetailScreenState();
}

class _CageDetailScreenState extends State<CageDetailScreen> {
  /// Place un lapin dans la loge (choisi dans une liste) et confirme le résultat.
  Future<void> _addRabbitTo(Cage cage, CageCompartment slot) async {
    final provider = context.read<RabbitProvider>();
    final rabbit = await _pickRabbit(cage, slot, provider);
    if (rabbit == null || !mounted) return;
    final error = await provider.assignRabbitToCompartment(
      rabbit.id,
      cageId: cage.id,
      compartmentNumber: slot.number,
    );
    if (!mounted) return;
    final kits = math.max(
      provider.nursingKitsOf(rabbit.id),
      rabbit.nursingKits,
    );
    final withKits =
        kits > 0 ? ' avec ses $kits lapereau${kits > 1 ? 'x' : ''}' : '';
    _snack(
      context,
      error ??
          '${rabbit.name} placé$withKits : ${cage.compartmentLabel(slot.number).toLowerCase()}',
      error: error != null,
    );
  }

  Future<void> _onCompartmentTap(Cage cage, CageCompartment slot) async {
    final provider = context.read<RabbitProvider>();

    // Loge libre : on choisit directement le lapin à y placer.
    if (slot.isFree) {
      await _addRabbitTo(cage, slot);
      return;
    }

    // Loge occupée : voir les lapins présents, en retirer un, ou en ajouter un autre.
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text(
                      cage.compartmentLabel(slot.number),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${slot.occupants.length} lapin${slot.occupants.length > 1 ? 's' : ''} dans cette loge',
                    ),
                  ),
                  for (final o in slot.occupants)
                    ListTile(
                      key: ValueKey('occupant-${o.id}'),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(
                          o.isMale ? '♂' : '♀',
                          style: TextStyle(
                            color:
                                o.isMale
                                    ? AppColors.maleBlue
                                    : AppColors.femalePink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        o.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        o.nursingKits > 0
                            ? '${o.tagNumber} · 🍼 avec ${o.nursingKits} lapereau${o.nursingKits > 1 ? 'x' : ''}'
                            : o.tagNumber,
                      ),
                      onTap: () => Navigator.pop(ctx, 'view:${o.id}'),
                      trailing: IconButton(
                        tooltip: 'Retirer de la loge',
                        icon: Icon(Icons.logout, color: Colors.red.shade700),
                        onPressed: () => Navigator.pop(ctx, 'free:${o.id}'),
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    key: const ValueKey('add-to-compartment'),
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Ajouter un lapin dans cette loge',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    onTap: () => Navigator.pop(ctx, 'add'),
                  ),
                ],
              ),
            ),
          ),
    );
    if (!mounted || action == null) return;

    if (action == 'add') {
      await _addRabbitTo(cage, slot);
    } else if (action.startsWith('view:')) {
      final rabbit = provider.getRabbitById(action.substring(5));
      if (rabbit != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RabbitDetailScreen(rabbit: rabbit)),
        );
      }
    } else if (action.startsWith('free:')) {
      final id = action.substring(5);
      final leaving = slot.occupants.firstWhere((o) => o.id == id);
      final error = await provider.assignRabbitToCompartment(id, cageId: null);
      if (!mounted) return;
      final kits = math.max(provider.nursingKitsOf(id), leaving.nursingKits);
      final withKits =
          kits > 0 ? ' avec ses $kits lapereau${kits > 1 ? 'x' : ''}' : '';
      _snack(
        context,
        error ??
            '${leaving.name} retiré$withKits de ${cage.compartmentLabel(slot.number).toLowerCase()}',
        error: error != null,
      );
    }
  }

  Future<Rabbit?> _pickRabbit(
    Cage cage,
    CageCompartment slot,
    RabbitProvider provider,
  ) {
    final candidates =
        provider.rabbits
            .where((r) => r.status != RabbitStatus.retired)
            .where(
              (r) =>
                  !(r.cageId == cage.id && r.compartmentNumber == slot.number),
            )
            .toList()
          ..sort((a, b) {
            // Les lapins sans cage d'abord
            if ((a.cageId == null) != (b.cageId == null)) {
              return a.cageId == null ? -1 : 1;
            }
            return a.name.compareTo(b.name);
          });

    return showModalBottomSheet<Rabbit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder:
                (ctx, controller) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Placer un lapin : ${cage.compartmentLabel(slot.number).toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          candidates.isEmpty
                              ? const Center(
                                child: Text('Aucun lapin disponible'),
                              )
                              : ListView.builder(
                                controller: controller,
                                itemCount: candidates.length,
                                itemBuilder: (ctx, i) {
                                  final r = candidates[i];
                                  final moving = r.cageId != null;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Colors.white,
                                      child: Text(
                                        r.shortGenderSymbol,
                                        style: TextStyle(
                                          color:
                                              r.isMale
                                                  ? AppColors.maleBlue
                                                  : AppColors.femalePink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      r.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${moving ? '${r.tagNumber} · actuellement en ${r.cageNumber}' : '${r.tagNumber} · sans cage'}'
                                      '${provider.nursingKitsOf(r.id) > 0 ? '\n🍼 ses ${provider.nursingKitsOf(r.id)} lapereaux la suivront' : ''}',
                                    ),
                                    onTap: () => Navigator.pop(ctx, r),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _confirmDelete(Cage cage) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Supprimer la cage ${cage.name} ?'),
            content: Text(
              cage.rabbitsCount > 0
                  ? 'Les ${cage.rabbitsCount} lapin(s) qu\'elle contient resteront dans l\'élevage, sans cage.'
                  : 'Cette action est définitive.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    final deleted = await context.read<RabbitProvider>().deleteCage(cage.id);
    if (!mounted) return;
    if (deleted) {
      navigator.pop();
    } else {
      _snack(context, 'Suppression impossible', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cage = context.watch<RabbitProvider>().getCageById(widget.cageId);
    if (cage == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Cage introuvable')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Cage ${cage.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => showCageForm(context, edit: cage),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
            tooltip: 'Supprimer',
            onPressed: () => _confirmDelete(cage),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: cage.columnsCount == 1 ? 380 : 560,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(
                        cage.columnsCount == 1
                            ? '${cage.compartmentsCount} loge${cage.compartmentsCount > 1 ? 's' : ''}'
                            : '${cage.rowsCount} lignes × ${cage.columnsCount} colonnes',
                      ),
                      _chip('${cage.rabbitsCount} lapin(s)'),
                      if (cage.kitsCount > 0)
                        _chip('🍼 ${cage.kitsCount} lapereau(x) au nid'),
                      _chip('${cage.occupiedCount} loge(s) occupée(s)'),
                      _chip('${cage.freeCount} libre(s)'),
                      if (cage.location != null && cage.location!.isNotEmpty)
                        _chip('📍 ${cage.location}'),
                    ],
                  ),
                  if (cage.notes != null && cage.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      cage.notes!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                    'Touchez une loge pour y ajouter un lapin ou gérer ceux qui y logent. '
                    'Une loge peut en accueillir plusieurs.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 14),
                  _buildDiagram(cage),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Schéma interactif ; au-delà de 2 colonnes, défilement horizontal pour
  /// garder des loges lisibles.
  Widget _buildDiagram(Cage cage) {
    final diagram = CageDiagram(
      cage: cage,
      onCompartmentTap: (slot) => _onCompartmentTap(cage, slot),
    );
    if (cage.columnsCount <= 2) return diagram;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(width: cage.columnsCount * 190.0, child: diagram),
    );
  }

  Widget _chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primarySoftBorder),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    ),
  );
}
