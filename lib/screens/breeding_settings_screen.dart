import '../widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/breeding_settings_provider.dart';
import '../theme/colors.dart';

/// Écran permettant à l'éleveur de personnaliser les durées d'élevage
/// (sevrage, palpation, mise bas) et les délais de rappel de notification.
class BreedingSettingsScreen extends StatefulWidget {
  const BreedingSettingsScreen({super.key});

  @override
  State<BreedingSettingsScreen> createState() => _BreedingSettingsScreenState();
}

class _BreedingSettingsScreenState extends State<BreedingSettingsScreen> {
  late int _gestationDays;
  late int _palpationDays;
  late int _nestBoxDaysBeforeKindling;
  late int _weaningDays;

  late int _palpationNoticeDays;
  late int _nestBoxNoticeDays;
  late int _kindlingNoticeDays;
  late int _weaningNoticeDays;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final s = context.read<BreedingSettingsProvider>().settings;
      _gestationDays = s.gestationDays;
      _palpationDays = s.palpationDays;
      _nestBoxDaysBeforeKindling = s.nestBoxDaysBeforeKindling;
      _weaningDays = s.weaningDays;

      _palpationNoticeDays = s.palpationNoticeDays;
      _nestBoxNoticeDays = s.nestBoxNoticeDays;
      _kindlingNoticeDays = s.kindlingNoticeDays;
      _weaningNoticeDays = s.weaningNoticeDays;

      _initialized = true;
    }
  }

  Future<void> _save() async {
    final provider = context.read<BreedingSettingsProvider>();
    final updated = provider.settings.copyWith(
      gestationDays: _gestationDays,
      palpationDays: _palpationDays,
      nestBoxDaysBeforeKindling: _nestBoxDaysBeforeKindling,
      weaningDays: _weaningDays,
      palpationNoticeDays: _palpationNoticeDays,
      nestBoxNoticeDays: _nestBoxNoticeDays,
      kindlingNoticeDays: _kindlingNoticeDays,
      weaningNoticeDays: _weaningNoticeDays,
    );
    await provider.updateSettings(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paramètres d\'élevage enregistrés avec succès.'),
        backgroundColor: AppColors.primary,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Rétablir les valeurs par défaut ?'),
            content: const Text(
              'Les durées recommandées (gestation 31 j, palpation J12, nid 3 j avant, sevrage 45 j) seront rétablies.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Rétablir'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final d = BreedingSettings.defaults;
      setState(() {
        _gestationDays = d.gestationDays;
        _palpationDays = d.palpationDays;
        _nestBoxDaysBeforeKindling = d.nestBoxDaysBeforeKindling;
        _weaningDays = d.weaningDays;
        _palpationNoticeDays = d.palpationNoticeDays;
        _nestBoxNoticeDays = d.nestBoxNoticeDays;
        _kindlingNoticeDays = d.kindlingNoticeDays;
        _weaningNoticeDays = d.weaningNoticeDays;
      });
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        await context.read<BreedingSettingsProvider>().resetToDefaults();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Valeurs recommandées rétablies.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text(
          'Cycles & Rappels d\'élevage',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Rétablir par défaut',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _reset,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEDEFED))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const ValueKey('save-breeding-settings'),
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Enregistrer les paramètres',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              'Ajustez la durée des cycles selon votre conduite d\'élevage et votre race. '
              'Ces durées mettent à jour le calendrier, les fiches et les alertes automatiques.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Durées des cycles de reproduction
            _buildSectionHeader('DURÉE DES CYCLES D\'ÉLEVAGE', Icons.pets_outlined),
            const SizedBox(height: 8),
            Container(
              decoration: appCardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _buildStepperRow(
                    key: const ValueKey('step-gestation'),
                    title: 'Durée de gestation (mise bas)',
                    subtitle: 'Nombre moyen de jours de gestation (standard : 31 jours)',
                    value: _gestationDays,
                    unit: 'jours',
                    min: 28,
                    max: 35,
                    onChanged: (val) => setState(() => _gestationDays = val),
                  ),
                  const Divider(height: 20),
                  _buildStepperRow(
                    key: const ValueKey('step-palpation'),
                    title: 'Palpation post-saillie',
                    subtitle: 'Jour où la gestation est vérifiée (standard : J12)',
                    value: _palpationDays,
                    unit: 'j après saillie',
                    min: 9,
                    max: 18,
                    onChanged: (val) => setState(() => _palpationDays = val),
                  ),
                  const Divider(height: 20),
                  _buildStepperRow(
                    key: const ValueKey('step-nest-box'),
                    title: 'Pose de la boîte à nid',
                    subtitle:
                        'Posée $_nestBoxDaysBeforeKindling jours avant mise bas (vers J${_gestationDays - _nestBoxDaysBeforeKindling})',
                    value: _nestBoxDaysBeforeKindling,
                    unit: 'j avant mise bas',
                    min: 1,
                    max: 6,
                    onChanged:
                        (val) => setState(() => _nestBoxDaysBeforeKindling = val),
                  ),
                  const Divider(height: 20),
                  _buildStepperRow(
                    key: const ValueKey('step-weaning'),
                    title: 'Âge au sevrage des lapereaux',
                    subtitle: 'Nombre de jours au nid avant le sevrage (standard : 45 jours)',
                    value: _weaningDays,
                    unit: 'jours',
                    min: 28,
                    max: 60,
                    onChanged: (val) => setState(() => _weaningDays = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Délais d'anticipation pour les notifications
            _buildSectionHeader(
              'DÉLAIS D\'ANTICIPATION DES NOTIFICATIONS',
              Icons.notifications_active_outlined,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: appCardDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  _buildNoticeOptionRow(
                    key: const ValueKey('notice-kindling'),
                    title: 'Rappel avant mise bas',
                    subtitle: 'Alerte anticipée pour préparer la cage de mise bas',
                    value: _kindlingNoticeDays,
                    options: const [
                      (0, 'Le jour même'),
                      (1, '1 jour avant (veille)'),
                      (2, '2 jours avant'),
                      (3, '3 jours avant'),
                    ],
                    onChanged: (val) => setState(() => _kindlingNoticeDays = val),
                  ),
                  const Divider(height: 20),
                  _buildNoticeOptionRow(
                    key: const ValueKey('notice-weaning'),
                    title: 'Rappel avant sevrage',
                    subtitle: 'Alerte anticipée pour préparer les loges d\'engraissement',
                    value: _weaningNoticeDays,
                    options: const [
                      (0, 'Le jour même'),
                      (1, '1 jour avant'),
                      (2, '2 jours avant'),
                      (3, '3 jours avant (recommandé)'),
                      (5, '5 jours avant'),
                    ],
                    onChanged: (val) => setState(() => _weaningNoticeDays = val),
                  ),
                  const Divider(height: 20),
                  _buildNoticeOptionRow(
                    key: const ValueKey('notice-palpation'),
                    title: 'Rappel avant palpation',
                    subtitle: 'Alerte pour programmer la séance de diagnostic',
                    value: _palpationNoticeDays,
                    options: const [
                      (0, 'Le jour même (recommandé)'),
                      (1, '1 jour avant'),
                      (2, '2 jours avant'),
                    ],
                    onChanged:
                        (val) => setState(() => _palpationNoticeDays = val),
                  ),
                  const Divider(height: 20),
                  _buildNoticeOptionRow(
                    key: const ValueKey('notice-nest-box'),
                    title: 'Rappel boîte à nid',
                    subtitle: 'Alerte pour préparer et désinfecter la boîte',
                    value: _nestBoxNoticeDays,
                    options: const [
                      (0, 'Le jour de pose (recommandé)'),
                      (1, '1 jour avant'),
                      (2, '2 jours avant'),
                    ],
                    onChanged:
                        (val) => setState(() => _nestBoxNoticeDays = val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStepperRow({
    required Key key,
    required String title,
    required String subtitle,
    required int value,
    required String unit,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: key != null ? ValueKey('${(key as ValueKey).value}-dec') : null,
                  icon: const Icon(Icons.remove, size: 18),
                  splashRadius: 18,
                  onPressed: value > min ? () => onChanged(value - 1) : null,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  alignment: Alignment.center,
                  child: Text(
                    '$value',
                    key: key,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  key: key != null ? ValueKey('${(key as ValueKey).value}-inc') : null,
                  icon: const Icon(Icons.add, size: 18),
                  splashRadius: 18,
                  onPressed: value < max ? () => onChanged(value + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeOptionRow({
    required Key key,
    required String title,
    required String subtitle,
    required int value,
    required List<(int, String)> options,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: key,
            isExpanded: true,
            value: options.any((o) => o.$1 == value) ? value : options.first.$1,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: [
              for (final o in options)
                DropdownMenuItem<int>(
                  value: o.$1,
                  child: Text(
                    o.$2,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
            ],
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ],
      ),
    );
  }
}
