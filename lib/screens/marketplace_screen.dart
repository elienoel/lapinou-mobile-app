import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/marketplace_listing.dart';
import '../providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import '../services/api_constants.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../utils/time_ago.dart';
import '../widgets/app_ui.dart';
import 'chat_screen.dart';

/// Prix d'une annonce dans la devise de l'utilisateur, ou « Prix à débattre ».
String _priceLabel(BuildContext context, MarketplaceListing l) {
  if (l.price == null) return 'Prix à débattre';
  return context.read<AuthProvider>().currency.format(l.price!);
}

Widget _listingPhoto(MarketplaceListing l, {BoxFit fit = BoxFit.cover}) {
  final fallback = Image.asset('assets/placeholder.png', fit: fit);
  if (l.photo == null) return fallback;
  return Image.network(
    ApiConstants.formatMediaUrl(l.photo),
    fit: fit,
    errorBuilder: (_, __, ___) => fallback,
  );
}

/// Petites annonces entre éleveurs : toutes les annonces (onglet « Toutes »)
/// et celles publiées par l'utilisateur (onglet « Mes annonces »).
class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  ListingType? _type;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MarketplaceProvider>().fetchListings();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  List<MarketplaceListing> _filter(
    List<MarketplaceListing> all, {
    int? sellerId,
  }) {
    final term = _search.text.trim().toLowerCase();
    return all.where((l) {
      if (sellerId != null && l.sellerId != sellerId) return false;
      // Les annonces vendues/clôturées des autres ne sont plus utiles
      if (sellerId == null && l.status == ListingStatus.closed) return false;
      if (_type != null && l.type != _type) return false;
      if (term.isEmpty) return true;
      return l.title.toLowerCase().contains(term) ||
          l.description.toLowerCase().contains(term) ||
          (l.location ?? '').toLowerCase().contains(term) ||
          l.sellerName.toLowerCase().contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketplaceProvider>();
    final myId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(
        leading:
            Navigator.canPop(context)
                ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.pop(context),
                )
                : null,
        title: const Text('Petites annonces'),
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
            Tab(key: ValueKey('market-tab-all'), text: 'Toutes'),
            Tab(key: ValueKey('market-tab-mine'), text: 'Mes annonces'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('market-publish'),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ListingFormScreen()),
            ),
        icon: const Icon(Icons.add),
        label: const Text('Publier'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Rechercher une annonce, un lieu, un éleveur…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon:
                      _search.text.isEmpty
                          ? null
                          : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: _search.clear,
                          ),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _typeChip(null, 'Toutes'),
                  for (final t in ListingType.values) _typeChip(t, t.label),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ListingList(
                    listings: _filter(provider.listings),
                    emptyText: 'Aucune annonce pour le moment.',
                  ),
                  _ListingList(
                    listings:
                        myId == null
                            ? const []
                            : _filter(provider.listings, sellerId: myId),
                    emptyText:
                        'Vous n\'avez publié aucune annonce.\nAppuyez sur « Publier » pour vendre un reproducteur, du matériel…',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(ListingType? type, String label) {
    final selected = _type == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: ValueKey('market-filter-${type?.api ?? 'all'}'),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.onPrimary : AppColors.textPrimary,
        ),
        onSelected: (_) => setState(() => _type = type),
      ),
    );
  }
}

class _ListingList extends StatelessWidget {
  final List<MarketplaceListing> listings;
  final String emptyText;

  const _ListingList({required this.listings, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketplaceProvider>();
    final Widget content;

    if (listings.isEmpty) {
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child:
                provider.isLoading
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        provider.error ?? emptyText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
          ),
        ],
      );
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: listings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _ListingCard(listing: listings[i]),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: provider.fetchListings,
      child: content,
    );
  }
}

class _ListingCard extends StatelessWidget {
  final MarketplaceListing listing;

  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('listing-${listing.id}'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListingDetailScreen(listingId: listing.id),
            ),
          ),
      child: Container(
        decoration: appCardDecoration(shadow: true),
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: SizedBox(width: 92, height: 92, child: _listingPhoto(listing)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        listing.type.icon,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        listing.type.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (!listing.isAvailable)
                        _StatusBadge(status: listing.status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _priceLabel(context, listing),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color:
                          listing.price == null
                              ? AppColors.textSecondary
                              : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (listing.location != null) listing.location!,
                      timeAgo(listing.createdAt),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
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
}

class _StatusBadge extends StatelessWidget {
  final ListingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color =
        status == ListingStatus.reserved
            ? AppColors.statusPregnantText
            : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Fiche

/// Fiche d'une annonce. Pour l'acheteur : contacter le vendeur par message ou
/// par téléphone. Pour le vendeur : modifier, changer le statut, supprimer.
class ListingDetailScreen extends StatelessWidget {
  final int listingId;

  const ListingDetailScreen({super.key, required this.listingId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarketplaceProvider>();
    final matches = provider.listings.where((l) => l.id == listingId);
    if (matches.isEmpty) {
      // Annonce supprimée pendant que la fiche était ouverte
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'Cette annonce n\'existe plus.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    final listing = matches.first;
    final isMine = context.watch<AuthProvider>().user?.id == listing.sellerId;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Annonce'),
        actions: [
          if (isMine)
            IconButton(
              key: const ValueKey('listing-edit'),
              tooltip: 'Modifier',
              icon: const Icon(Icons.edit_outlined),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ListingFormScreen(existing: listing),
                    ),
                  ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            AspectRatio(aspectRatio: 4 / 3, child: _listingPhoto(listing)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        listing.type.icon,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        listing.type.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (!listing.isAvailable)
                        _StatusBadge(status: listing.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    listing.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _priceLabel(context, listing),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            listing.location ?? 'Lieu non précisé',
                            'publiée ${timeAgo(listing.createdAt).toLowerCase()}',
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    listing.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isMine)
                    _SellerActions(listing: listing)
                  else
                    _ContactSeller(listing: listing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactSeller extends StatelessWidget {
  final MarketplaceListing listing;

  const _ContactSeller({required this.listing});

  Future<void> _call(BuildContext context) async {
    final phone = listing.sellerPhone!.replaceAll(RegExp(r'[^\d+]'), '');
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && context.mounted) {
      showAppSnack(context, 'Impossible de lancer l\'appel.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vendeur',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      listing.sellerName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            key: const ValueKey('listing-message'),
            onPressed: () => startChatWithUser(context, listing.sellerId),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Envoyer un message'),
          ),
          if (listing.sellerPhone != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('listing-call'),
              onPressed: () => _call(context),
              icon: const Icon(Icons.call_outlined, size: 18),
              label: Text('Appeler ${listing.sellerPhone}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SellerActions extends StatelessWidget {
  final MarketplaceListing listing;

  const _SellerActions({required this.listing});

  Future<void> _setStatus(BuildContext context, ListingStatus status) async {
    final error = await context.read<MarketplaceProvider>().setStatus(
      listing,
      status,
    );
    if (!context.mounted) return;
    if (error != null) {
      showAppSnack(context, error, error: true);
    } else {
      showAppSnack(context, 'Annonce : ${status.label.toLowerCase()}.');
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer l\'annonce ?',
      message: 'L\'annonce « ${listing.title} » sera retirée pour tout le monde.',
      destructive: true,
      confirmKey: const ValueKey('listing-delete-confirm'),
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    final error = await context.read<MarketplaceProvider>().deleteListing(
      listing,
    );
    if (!context.mounted) return;
    if (error != null) {
      showAppSnack(context, error, error: true);
    } else {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Statut de l\'annonce',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ListingStatus>(
          key: const ValueKey('listing-status'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: ListingStatus.available,
              label: Text('Disponible'),
            ),
            ButtonSegment(value: ListingStatus.reserved, label: Text('Réservé')),
            ButtonSegment(value: ListingStatus.closed, label: Text('Vendu')),
          ],
          selected: {listing.status},
          onSelectionChanged: (s) => _setStatus(context, s.first),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          key: const ValueKey('listing-delete'),
          style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          onPressed: () => _delete(context),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Supprimer l\'annonce'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Formulaire

/// Publication ([existing] null) ou modification d'une annonce.
class ListingFormScreen extends StatefulWidget {
  final MarketplaceListing? existing;

  const ListingFormScreen({super.key, this.existing});

  @override
  State<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends State<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _location;
  late ListingType _type;
  File? _photo;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _price = TextEditingController(
      text:
          e?.price == null
              ? ''
              : (e!.price! == e.price!.roundToDouble()
                  ? e.price!.toInt().toString()
                  : e.price!.toString()),
    );
    _location = TextEditingController(text: e?.location ?? '');
    _type = e?.type ?? ListingType.sell;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  void _choosePhotoSource() {
    showModalBottomSheet<void>(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Prendre une photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choisir dans la galerie'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final priceText = _price.text.trim().replaceAll(',', '.');
    final error = await context.read<MarketplaceProvider>().saveListing(
      existing: widget.existing,
      title: _title.text,
      type: _type,
      description: _description.text,
      price: priceText.isEmpty ? null : double.parse(priceText),
      location: _location.text,
      photo: _photo,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      showAppSnack(context, error, error: true);
      return;
    }
    showAppSnack(
      context,
      _isEdit ? 'Annonce modifiée.' : 'Annonce publiée.',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<AuthProvider>().currency;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_isEdit ? 'Modifier l\'annonce' : 'Nouvelle annonce'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Photo
              InkWell(
                key: const ValueKey('listing-photo'),
                onTap: _choosePhotoSource,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Container(
                  height: 180,
                  decoration: appCardDecoration(),
                  clipBehavior: Clip.antiAlias,
                  child:
                      _photo != null
                          ? Image.file(_photo!, fit: BoxFit.cover)
                          : widget.existing?.photo != null
                          ? _listingPhoto(widget.existing!)
                          : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 32,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Ajouter une photo',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
              if (_photo != null || widget.existing?.photo != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _choosePhotoSource,
                    child: const Text('Changer la photo'),
                  ),
                ),
              const SizedBox(height: 16),

              const Text(
                'Catégorie',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in ListingType.values)
                    ChoiceChip(
                      key: ValueKey('listing-type-${t.api}'),
                      avatar: Icon(
                        t.icon,
                        size: 16,
                        color:
                            _type == t
                                ? AppColors.onPrimary
                                : AppColors.textSecondary,
                      ),
                      label: Text(t.label),
                      selected: _type == t,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color:
                            _type == t
                                ? AppColors.onPrimary
                                : AppColors.textPrimary,
                      ),
                      onSelected: (_) => setState(() => _type = t),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                key: const ValueKey('listing-title'),
                controller: _title,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  hintText: 'Ex : Mâle Néo-Zélandais de 6 mois',
                  counterText: '',
                ),
                validator:
                    (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'Donnez un titre à votre annonce.'
                            : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('listing-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Prix (facultatif)',
                  hintText: 'Laisser vide : prix à débattre',
                  suffixText: currency.symbol,
                ),
                validator: (v) {
                  final t = (v ?? '').trim().replaceAll(',', '.');
                  if (t.isEmpty) return null;
                  final n = double.tryParse(t);
                  if (n == null || n < 0) return 'Prix invalide.';
                  if (n >= 100000000) return 'Prix trop élevé.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('listing-location'),
                controller: _location,
                maxLength: 200,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Lieu (facultatif)',
                  hintText: 'Ex : Abidjan, Cocody',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('listing-description'),
                controller: _description,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Race, âge, état, quantité, conditions…',
                  alignLabelWithHint: true,
                ),
                validator:
                    (v) =>
                        (v ?? '').trim().isEmpty
                            ? 'Décrivez ce que vous proposez.'
                            : null,
              ),
              const SizedBox(height: 22),
              SubmitButton(
                key: const ValueKey('listing-submit'),
                label: _isEdit ? 'Enregistrer' : 'Publier l\'annonce',
                saving: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
