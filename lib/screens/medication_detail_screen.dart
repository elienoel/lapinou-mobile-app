import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../models/medication.dart';
import '../providers/auth_provider.dart';
import '../providers/pharmacy_provider.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import 'pharmacy_detail_screen.dart';

/// Détail d'un médicament : bande de prix (fourchette observée chez les pharmacies
/// qui le vendent) puis la liste de ces pharmacies, sans prix — le prix exact
/// n'apparaît que sur la fiche de chaque pharmacie.
class MedicationDetailScreen extends StatefulWidget {
  final String medicationId;

  const MedicationDetailScreen({super.key, required this.medicationId});

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  Medication? _medication;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final medication = await context
        .read<PharmacyProvider>()
        .fetchMedicationDetail(widget.medicationId);
    if (!mounted) return;
    setState(() {
      _medication = medication;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AuthProvider>().currency;
    final medication = _medication;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(medication?.name ?? 'Médicament'),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : medication == null
              ? const Center(
                child: Text(
                  "Impossible de charger ce médicament.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
              : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (medication.image != null &&
                        medication.image!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Image.network(
                          ApiConstants.formatMediaUrl(medication.image),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    if (medication.image != null &&
                        medication.image!.isNotEmpty)
                      const SizedBox(height: 16),
                    Text(
                      medication.category.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (medication.description != null &&
                        medication.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        medication.description!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _PriceBand(medication: medication, currency: currency),
                    const SizedBox(height: 20),
                    Text(
                      'Pharmacies',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (medication.pharmacies.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Aucune pharmacie ne propose ce médicament pour le moment.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      for (final pharmacy in medication.pharmacies)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.local_pharmacy_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              pharmacy.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(pharmacy.address),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PharmacyDetailScreen(
                                          pharmacyId: pharmacy.id,
                                        ),
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

class _PriceBand extends StatelessWidget {
  final Medication medication;
  final AppCurrency currency;

  const _PriceBand({required this.medication, required this.currency});

  @override
  Widget build(BuildContext context) {
    final min = medication.priceMin;
    final max = medication.priceMax;

    String label;
    if (min == null || max == null) {
      label = 'Prix non communiqué';
    } else if (min == max) {
      label = currency.format(min);
    } else {
      label = 'Entre ${currency.format(min)} et ${currency.format(max)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prix observé',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
