import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/medication.dart';
import '../models/pharmacy.dart';
import '../providers/pharmacy_provider.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import 'medication_detail_screen.dart';
import 'pharmacy_detail_screen.dart';

/// Pharmacie : catalogue des médicaments pour lapins (onglet "Produits") et
/// répertoire des pharmacies vétérinaires à proximité sur une carte (onglet "Carte").
/// [initialTab] : 0 = produits, 1 = carte.
class PharmacyScreen extends StatefulWidget {
  final int initialTab;

  const PharmacyScreen({super.key, this.initialTab = 0});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PharmacyProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:
            Navigator.canPop(context)
                ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.pop(context),
                )
                : null,
        title: const Text('Pharmacie'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          tabs: const [
            Tab(key: ValueKey('pharmacy-tab-products'), text: 'Produits'),
            Tab(key: ValueKey('pharmacy-tab-map'), text: 'Carte'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabs,
          children: const [_MedicationGridTab(), _PharmacyMapTab()],
        ),
      ),
    );
  }
}

class _MedicationGridTab extends StatelessWidget {
  const _MedicationGridTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    final medications = provider.medications;

    if (medications.isEmpty) {
      return Center(
        child:
            provider.isLoading
                ? const CircularProgressIndicator(color: AppColors.primary)
                : const Text(
                  'Aucun médicament dans le catalogue pour le moment.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.76,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: medications.length,
      itemBuilder: (context, index) {
        final medication = medications[index];
        return _MedicationCard(medication: medication);
      },
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final Medication medication;

  const _MedicationCard({required this.medication});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('medication-${medication.id}'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => MedicationDetailScreen(medicationId: medication.id),
            ),
          ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.cardBorder),
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
            Expanded(
              child:
                  medication.image != null && medication.image!.isNotEmpty
                      ? Image.network(
                        ApiConstants.formatMediaUrl(medication.image),
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => _medicationIconFallback(medication),
                      )
                      : _medicationIconFallback(medication),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    medication.category.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicationIconFallback(Medication medication) {
    return Image.asset('assets/placeholder.png', fit: BoxFit.cover);
  }
}

class _PharmacyMapTab extends StatefulWidget {
  const _PharmacyMapTab();

  @override
  State<_PharmacyMapTab> createState() => _PharmacyMapTabState();
}

class _PharmacyMapTabState extends State<_PharmacyMapTab> {
  final _mapController = MapController();
  LatLng? _userPosition;
  bool _locationDenied = false;

  static const _fallbackCenter = LatLng(5.3600, -4.0083); // Abidjan

  @override
  void initState() {
    super.initState();
    _resolvePosition();
  }

  Future<void> _resolvePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => _locationDenied = true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _locationDenied = true);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(
        () => _userPosition = LatLng(position.latitude, position.longitude),
      );
      _mapController.move(_userPosition!, 13);
    } catch (_) {
      if (mounted) setState(() => _locationDenied = true);
    }
  }

  LatLng _initialCenter(List<Pharmacy> pharmacies) {
    if (_userPosition != null) return _userPosition!;
    if (pharmacies.isEmpty) return _fallbackCenter;
    final avgLat =
        pharmacies.map((p) => p.latitude).reduce((a, b) => a + b) /
        pharmacies.length;
    final avgLng =
        pharmacies.map((p) => p.longitude).reduce((a, b) => a + b) /
        pharmacies.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacyProvider>();
    final pharmacies = provider.pharmacies;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _initialCenter(pharmacies),
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.lapinou.app',
            ),
            MarkerLayer(
              markers: [
                if (_userPosition != null)
                  Marker(
                    point: _userPosition!,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.maleBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                for (final pharmacy in pharmacies)
                  Marker(
                    point: LatLng(pharmacy.latitude, pharmacy.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
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
                      child: const Icon(
                        Icons.local_pharmacy,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (_locationDenied)
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Activez la localisation pour centrer la carte sur votre position.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}
