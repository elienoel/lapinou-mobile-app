import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pharmacy.dart';
import '../providers/auth_provider.dart';
import '../providers/pharmacy_provider.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import 'medication_detail_screen.dart';

/// Fiche d'une pharmacie : adresse/téléphone puis la liste de ses médicaments
/// avec le prix exact pratiqué par cette pharmacie (contrairement à la liste des
/// pharmacies d'un médicament, qui n'affiche pas de prix).
class PharmacyDetailScreen extends StatefulWidget {
  final String pharmacyId;

  const PharmacyDetailScreen({super.key, required this.pharmacyId});

  @override
  State<PharmacyDetailScreen> createState() => _PharmacyDetailScreenState();
}

class _PharmacyDetailScreenState extends State<PharmacyDetailScreen> {
  Pharmacy? _pharmacy;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pharmacy = await context.read<PharmacyProvider>().fetchPharmacyDetail(
      widget.pharmacyId,
    );
    if (!mounted) return;
    setState(() {
      _pharmacy = pharmacy;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.read<AuthProvider>().currency;
    final pharmacy = _pharmacy;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(pharmacy?.name ?? 'Pharmacie'),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : pharmacy == null
              ? const Center(
                child: Text(
                  "Impossible de charger cette pharmacie.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
              : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pharmacy.address,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (pharmacy.phone != null &&
                              pharmacy.phone!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  pharmacy.phone!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Médicaments vendus',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (pharmacy.medications.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Aucun médicament renseigné pour cette pharmacie pour le moment.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      for (final line in pharmacy.medications)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/placeholder.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              line.medicationName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(line.medicationCategory.label),
                            trailing: Text(
                              currency.format(line.price),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => MedicationDetailScreen(
                                          medicationId: line.medicationId,
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
