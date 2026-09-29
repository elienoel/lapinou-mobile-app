import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/care.dart';
import '../providers/rabbit_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/care_sheets.dart';
import '../widgets/app_icon.dart';

/// Soins & entretien : rappels des prochains soins, historique des soins effectués
/// et types de soins (vaccin, vitamine, déparasitant…) avec leur durée de renouvellement.
/// [initialTab] : 0 = à venir, 1 = historique, 2 = types de soins.
class CareScreen extends StatefulWidget {
  final int initialTab;

  const CareScreen({super.key, this.initialTab = 0});

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    // Le bouton flottant dépend de l'onglet affiché
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RabbitProvider>().fetchCare();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Retour'),
              ),
              FilledButton(
                key: const ValueKey('care-confirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action),
              ),
            ],
          ),
    );
    return ok == true;
  }

  Future<void> _recordCare({
    CareRecord? existing,
    UpcomingCare? renewing,
  }) async {
    final saved = await showCareRecordSheet(
      context,
      existing: existing,
      treatmentId: renewing?.treatmentId,
      rabbitIds: renewing?.rabbits.map((r) => r.id).toList() ?? const [],
      purpose: renewing?.purpose,
    );
    if (saved == true && mounted) {
      _snack(existing == null ? 'Soin enregistré' : 'Soin modifié');
    }
  }

  Future<void> _deleteRecord(CareRecord record) async {
    if (!await _confirm(
      'Supprimer ce soin ?',
      '${record.treatmentName} du ${_dateFormat.format(record.date)} sera retiré de l\'historique.',
      'Supprimer',
    )) {
      return;
    }
    if (!mounted) return;
    final error = await context.read<RabbitProvider>().deleteCareRecord(
      record.id,
    );
    if (mounted) _snack(error ?? 'Soin supprimé');
  }

  Future<void> _deleteTreatment(CareTreatment treatment) async {
    if (!await _confirm(
      'Supprimer ce type de soin ?',
      '« ${treatment.name} » ne sera plus proposé lors de l\'enregistrement d\'un soin.',
      'Supprimer',
    )) {
      return;
    }
    if (!mounted) return;
    final error = await context.read<RabbitProvider>().deleteCareTreatment(
      treatment.id,
    );
    if (mounted) _snack(error ?? 'Type de soin supprimé');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RabbitProvider>(
      builder: (context, provider, child) {
        final onTreatments = _tabs.index == 2;
        return Scaffold(
          appBar: AppBar(
            leading:
                Navigator.canPop(context)
                    ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                    : null,
            title: const Text('Soins & entretien'),
            bottom: TabBar(
              controller: _tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              tabs: [
                Tab(
                  key: const ValueKey('care-tab-upcoming'),
                  text: 'À venir (${provider.upcomingCares.length})',
                ),
                Tab(
                  key: const ValueKey('care-tab-history'),
                  text: 'Historique',
                ),
                Tab(
                  key: const ValueKey('care-tab-treatments'),
                  text: 'Types de soins',
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildUpcomingTab(provider),
                _buildHistoryTab(provider),
                _buildTreatmentsTab(provider),
              ],
            ),
          ),
          floatingActionButton:
              onTreatments
                  ? FloatingActionButton.extended(
                    key: const ValueKey('care-fab-treatment'),
                    heroTag: 'fab_care_treatment',
                    onPressed: () => showCareTreatmentSheet(context),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Nouveau type de soin'),
                  )
                  : FloatingActionButton.extended(
                    key: const ValueKey('care-fab-record'),
                    heroTag: 'fab_care_record',
                    onPressed: () => _recordCare(),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.medical_services_outlined),
                    label: const Text('Enregistrer un soin'),
                  ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- À venir

  Widget _buildUpcomingTab(RabbitProvider provider) {
    final items = provider.upcomingCares;
    final overdue = items.where((c) => c.status == DueStatus.overdue).length;
    final soon = items.where((c) => c.status == DueStatus.soon).length;

    return RefreshIndicator(
      onRefresh: () => provider.fetchCare(),
      child:
          items.isEmpty
              ? _emptyState(
                icon: Icons.notifications_none_rounded,
                title: 'Aucun soin à prévoir',
                message:
                    provider.careTreatments.isEmpty
                        ? 'Commencez par créer vos types de soins (vaccin, vitamine, déparasitant…) avec leur durée de renouvellement, puis enregistrez les soins effectués.'
                        : 'Les rappels apparaissent ici dès qu\'un soin avec une durée de renouvellement est enregistré.',
              )
              : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                children: [
                  if (overdue > 0 || soon > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (overdue > 0)
                            _pill(
                              '$overdue en retard',
                              AppColors.statusAlertBg,
                              AppColors.statusAlertText,
                            ),
                          if (soon > 0)
                            _pill(
                              '$soon cette semaine',
                              AppColors.statusPregnantBg,
                              AppColors.statusPregnantText,
                            ),
                        ],
                      ),
                    ),
                  for (final c in items) _buildUpcomingCard(c),
                ],
              ),
    );
  }

  ({Color bg, Color fg}) _statusColors(DueStatus status) {
    switch (status) {
      case DueStatus.overdue:
        return (bg: AppColors.statusAlertBg, fg: AppColors.statusAlertText);
      case DueStatus.soon:
        return (
          bg: AppColors.statusPregnantBg,
          fg: AppColors.statusPregnantText,
        );
      case DueStatus.upcoming:
        return (bg: AppColors.statusActiveBg, fg: AppColors.statusActiveText);
    }
  }

  Widget _buildUpcomingCard(UpcomingCare care) {
    final colors = _statusColors(care.status);
    return Container(
      key: ValueKey('upcoming-${care.recordId}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(
        borderColor:
            care.status == DueStatus.overdue
                ? AppColors.statusAlertText.withAlpha(90)
                : AppColors.cardBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _emojiBox(care.category, colors.bg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      care.treatmentName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'À faire le ${_dateFormat.format(care.dueDate)}'
                      ' · dernier soin le ${_dateFormat.format(care.lastDate)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _pill(care.dueLabel, colors.bg, colors.fg),
            ],
          ),
          if (care.purpose.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              care.purpose,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          _rabbitChips(care.rabbits),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: ValueKey('upcoming-done-${care.recordId}'),
              onPressed: () => _recordCare(renewing: care),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Soin effectué'),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Historique

  Widget _buildHistoryTab(RabbitProvider provider) {
    final records = provider.careRecords;
    return RefreshIndicator(
      onRefresh: () => provider.fetchCare(),
      child:
          records.isEmpty
              ? _emptyState(
                icon: Icons.history_rounded,
                title: 'Aucun soin enregistré',
                message:
                    'Enregistrez chaque soin effectué : le type, la date, le motif et les lapins soignés.',
              )
              : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                itemCount: records.length,
                itemBuilder: (context, i) => _buildRecordCard(records[i]),
              ),
    );
  }

  Widget _buildRecordCard(CareRecord record) {
    return Container(
      key: ValueKey('record-${record.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _emojiBox(record.category, AppColors.primarySoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.treatmentName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Effectué le ${_dateFormat.format(record.date)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('record-menu-${record.id}'),
                onSelected: (v) {
                  if (v == 'edit') _recordCare(existing: record);
                  if (v == 'delete') _deleteRecord(record);
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
              ),
            ],
          ),
          if (record.purpose.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Motif : ${record.purpose}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _rabbitChips(record.rabbits),
          ),
          if (record.nextDueDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Prochain soin le ${_dateFormat.format(record.nextDueDate!)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------- Types de soins

  Widget _buildTreatmentsTab(RabbitProvider provider) {
    final treatments = provider.careTreatments;
    return RefreshIndicator(
      onRefresh: () => provider.fetchCare(),
      child:
          treatments.isEmpty
              ? _emptyState(
                icon: Icons.vaccines_outlined,
                title: 'Aucun type de soin',
                message:
                    'Créez vos soins (vaccin VHD2, vitamine, déparasitant…) et indiquez leur durée avant renouvellement pour être rappelé à temps.',
              )
              : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                itemCount: treatments.length,
                itemBuilder: (context, i) {
                  final t = treatments[i];
                  return Container(
                    key: ValueKey('treatment-${t.id}'),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: _cardDecoration(),
                    child: ListTile(
                      onTap: () => showCareTreatmentSheet(context, existing: t),
                      contentPadding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      leading: _emojiBox(t.category, AppColors.primarySoft),
                      title: Text(
                        t.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${t.category.label} · ${renewalLabel(t.renewalDays)}'
                        '${t.recordsCount > 0 ? ' · ${t.recordsCount} soin${t.recordsCount > 1 ? 's' : ''}' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        key: ValueKey('treatment-menu-${t.id}'),
                        onSelected: (v) {
                          if (v == 'edit') {
                            showCareTreatmentSheet(context, existing: t);
                          }
                          if (v == 'delete') _deleteTreatment(t);
                        },
                        itemBuilder:
                            (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Modifier')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Supprimer'),
                              ),
                            ],
                      ),
                    ),
                  );
                },
              ),
    );
  }

  // ---------------------------------------------------------------- Widgets

  BoxDecoration _cardDecoration({Color borderColor = AppColors.cardBorder}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(5),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _emojiBox(CareCategory category, Color background) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: CareCategoryIcon(category, size: 26, color: AppColors.primary),
    );
  }

  Widget _pill(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: foreground),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }

  Widget _rabbitChips(List<CareRabbit> rabbits) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final r in rabbits)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundGrey,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(AppIcons.rabbit, size: 14, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  r.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    // Défilable pour que le geste « tirer pour actualiser » reste disponible
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 96),
      children: [
        Icon(icon, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
