import '../widgets/app_ui.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../models/subscription.dart';
import '../providers/subscription_provider.dart';
import '../utils/formatters.dart';
import '../services/sync_service.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/author_avatar.dart';
import '../widgets/wave_edge.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';

/// Profil de l'éleveur : photo, informations personnelles, statistiques et gestion du compte.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _farmName = TextEditingController();
  final _location = TextEditingController();
  final _email = TextEditingController();
  final _bio = TextEditingController();

  bool _isSaving = false;
  // Les informations s'affichent en lecture ; le formulaire n'apparaît qu'après « Modifier »
  bool _isEditing = false;
  bool _isUploadingPhoto = false;
  int? _loadedForUserId;

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _lastName,
      _farmName,
      _location,
      _email,
      _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Remplit le formulaire avec les données du compte (au premier affichage et après un rafraîchissement)
  void _fillFrom(AuthUser user) {
    _firstName.text = user.firstName ?? '';
    _lastName.text = user.lastName ?? '';
    _farmName.text = user.farmName ?? '';
    _location.text = user.location ?? '';
    _email.text = user.email ?? '';
    _bio.text = user.bio ?? '';
    _loadedForUserId = user.id;
  }

  // ---- Photo de profil ----

  void _showPhotoOptions(AuthUser user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choisir dans la galerie'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Prendre une photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                ),
                if (user.avatar != null && user.avatar!.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Supprimer la photo',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _removePhoto();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _isUploadingPhoto = true);
      final error = await context.read<AuthProvider>().updateAvatar(
        File(picked.path),
      );
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      error == null
          ? showAppSnack(context, 'Photo de profil mise à jour')
          : showAppSnack(context, error, error: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        showAppSnack(context, "Impossible d'accéder à la photo.", error: true);
      }
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUploadingPhoto = true);
    final error = await context.read<AuthProvider>().removeAvatar();
    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);
    error == null
        ? showAppSnack(context, 'Photo supprimée')
        : showAppSnack(context, error, error: true);
  }

  // ---- Informations ----

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    final error = await context.read<AuthProvider>().updateProfile(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      farmName: _farmName.text.trim(),
      location: _location.text.trim(),
      email: _email.text.trim(),
      bio: _bio.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (error == null) _isEditing = false;
    });
    error == null
        ? showAppSnack(context, 'Profil enregistré')
        : showAppSnack(context, error, error: true);
  }

  void _startEditing(AuthUser user) {
    _fillFrom(user);
    setState(() => _isEditing = true);
  }

  /// Ferme le formulaire sans enregistrer : les champs reprennent les valeurs du compte.
  void _cancelEditing(AuthUser user) {
    _fillFrom(user);
    FocusScope.of(context).unfocus();
    setState(() => _isEditing = false);
  }

  // ---- Compte ----

  Future<void> _confirmLogout() async {
    final pending = context.read<SyncService>().pendingCount;
    final ok = await confirmAction(
      context,
      title: 'Déconnexion',
      message:
          pending > 0
              ? 'Voulez-vous vraiment vous déconnecter ?\n\n'
                  '$pending modification${pending > 1 ? 's' : ''} ne '
                  "${pending > 1 ? 'sont' : 'est'} pas encore synchronisée${pending > 1 ? 's' : ''}. "
                  'Elle${pending > 1 ? 's seront' : ' sera'} envoyée${pending > 1 ? 's' : ''} '
                  "à la prochaine connexion à ce compte."
              : 'Voulez-vous vraiment vous déconnecter ?',
      confirmLabel: 'Déconnexion',
    );
    if (ok == true && mounted) context.read<AuthProvider>().logout();
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) return;

    final error = await context.read<AuthProvider>().deleteAccount();
    if (!mounted) return;
    if (error != null) showAppSnack(context, error, error: true);
    // En cas de succès, la session est fermée et l'écran de connexion s'affiche
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    if (_loadedForUserId != user.id) _fillFrom(user);

    final rabbits = context.watch<RabbitProvider>();

    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Icônes de la barre d'état en blanc sur le haut sombre
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ---- Navbar fixe du profil : Titre Profil & bouton Paramètres ----
            Container(
              width: double.infinity,
              color: const Color(0xFF000000),
              padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mon profil',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  _buildSettingsButton(),
                ],
              ),
            ),

            // ---- Contenu défilant sous la navbar fixe ----
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---- Haut noir en dégradé : identité et statistiques ----
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
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(user),
                          const SizedBox(height: 24),
                          _buildStats(rabbits),
                        ],
                      ),
                    ),
                    const WaveEdge(color: Color(0xFF1E1E24)),

                    // ---- Bas blanc : le compte ----
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Compte',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildPersonalInfo(user),
                          const Divider(height: 1),
                          _buildAccountCard(user),
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
  }

  /// Bouton « Paramètres » en pastille, en haut à droite.
  Widget _buildSettingsButton() {
    return Tooltip(
      message: 'Paramètres',
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
        icon: const Icon(Icons.settings_outlined, size: 18),
        label: const Text('Paramètres'),
      ),
    );
  }

  /// Ligne de liste pleine largeur : icône, libellé, et chevron si elle mène quelque part.
  /// « Gratuit · 3 lapins sur 4 », « Éleveur · jusqu'au 21/12/2026 »
  String _subscriptionLine() {
    final SubscriptionStatus? status;
    try {
      status = context.watch<SubscriptionProvider>().status;
    } on ProviderNotFoundException {
      return 'Formules et paiement';
    }
    if (status == null) return 'Formules et paiement';
    if (status.isPaid && status.periodEnd != null) {
      return '${status.planName} · jusqu’au ${formatDate(status.periodEnd!)}';
    }
    final limit = status.limit;
    return limit == null
        ? status.planName
        : '${status.planName} · ${status.rabbitCount} lapins sur $limit';
  }

  Widget _menuRow({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color color = AppColors.textPrimary,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 28,
                color: AppColors.textPrimary,
              ),
          ],
        ),
      ),
    );
  }

  /// Section à plat de la partie « Compte » (lignes séparées par des traits).
  Widget _card({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: child,
    );
  }

  /// Identité sur le haut violet : photo (modifiable), nom, élevage et lieu.
  Widget _buildHeader(AuthUser user) {
    final fullName = [
      user.firstName,
      user.lastName,
    ].where((e) => e != null && e.isNotEmpty).join(' ');
    const avatarRadius = 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _isUploadingPhoto ? null : () => _showPhotoOptions(user),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: AuthorAvatar(
                      // La clé force le rechargement quand l'URL de la photo change
                      key: ValueKey(user.avatar),
                      name: user.displayName,
                      url: user.avatar,
                      radius: avatarRadius,
                    ),
                  ),
                  if (_isUploadingPhoto)
                    Container(
                      width: avatarRadius * 2,
                      height: avatarRadius * 2,
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.photo_camera,
                        color: Colors.white,
                        size: 14,
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
                  Text(
                    fullName.isEmpty ? user.displayName : fullName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  if (user.farmName != null && user.farmName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        user.farmName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (user.location != null && user.location!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        user.location!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (user.bio != null && user.bio!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              user.bio!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(220),
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStats(RabbitProvider rabbits) {
    Widget stat(String value, String label) {
      return Expanded(
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
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          stat('${rabbits.totalRabbitsCount}', 'Lapins'),
          stat('${rabbits.activePregnanciesCount}', 'Gestations'),
          stat('${rabbits.litters.length}', 'Portées'),
        ],
      ),
    );
  }

  Widget _buildPersonalInfo(AuthUser user) {
    InputDecoration deco(String label, IconData icon, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
    }

    if (!_isEditing) return _buildInfoView(user);

    return _card(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations personnelles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: deco('Prénom', Icons.person_outline),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: deco('Nom', Icons.badge_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _farmName,
              textCapitalization: TextCapitalization.words,
              decoration: deco("Nom de l'élevage", Icons.home_work_outlined),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration: deco(
                'Localisation',
                Icons.location_on_outlined,
                hint: 'Ville, région',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: deco('Email (optionnel)', Icons.mail_outline),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)
                    ? null
                    : 'Adresse email invalide';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: deco(
                'À propos de vous',
                Icons.notes_outlined,
                hint: 'Races élevées, expérience…',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      key: const ValueKey('profile-cancel'),
                      onPressed: _isSaving ? null : () => _cancelEditing(user),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      key: const ValueKey('profile-save'),
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Text(
                                'Enregistrer',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Informations personnelles en lecture seule, avec l'option « Modifier ».
  Widget _buildInfoView(AuthUser user) {
    Widget row(IconData icon, String label, String? value) {
      final empty = value == null || value.trim().isEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    empty ? 'Non renseigné' : value.trim(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          empty ? AppColors.textMuted : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Informations personnelles',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('profile-edit'),
                onPressed: () => _startEditing(user),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifier'),
              ),
            ],
          ),

          Row(
            children: [
              Expanded(
                child: row(Icons.person_outline, 'Prénom', user.firstName),
              ),
              Expanded(child: row(Icons.badge_outlined, 'Nom', user.lastName)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: row(
                  Icons.home_work_outlined,
                  "Nom de l'élevage",
                  user.farmName,
                ),
              ),
              Expanded(
                child: row(
                  Icons.location_on_outlined,
                  'Localisation',
                  user.location,
                ),
              ),
            ],
          ),

          row(Icons.mail_outline, 'Email', user.email),
          row(Icons.notes_outlined, 'À propos de vous', user.bio),
        ],
      ),
    );
  }

  /// Lignes du compte, séparées par des traits comme une liste de réglages.
  Widget _buildAccountCard(AuthUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _menuRow(
          icon: Icons.phone_outlined,
          title: user.phoneNumber ?? '—',
          subtitle: 'Numéro de connexion (non modifiable)',
        ),
        if (user.createdAt != null) ...[
          const Divider(height: 1),
          _menuRow(
            icon: Icons.event_available_outlined,
            title:
                'Membre depuis le ${DateFormat('d MMMM yyyy', 'fr_FR').format(user.createdAt!.toLocal())}',
          ),
        ],
        const Divider(height: 1),
        _menuRow(
          key: const ValueKey('profile-subscription'),
          icon: Icons.workspace_premium_outlined,
          title: 'Abonnement',
          subtitle: _subscriptionLine(),
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
        ),
        const Divider(height: 1),
        _menuRow(
          icon: Icons.logout_rounded,
          title: 'Se déconnecter',
          onTap: _confirmLogout,
        ),
        const Divider(height: 1),
        _menuRow(
          icon: Icons.delete_forever_outlined,
          title: 'Supprimer mon compte',
          subtitle: 'Efface définitivement votre élevage et vos publications',
          color: Colors.redAccent,
          onTap: _confirmDeleteAccount,
        ),
      ],
    );
  }
}

/// Demande de saisir « SUPPRIMER » avant d'effacer définitivement le compte.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  static const _word = 'SUPPRIMER';
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _controller.text.trim().toUpperCase() == _word;
    return AlertDialog(
      title: const Text('Supprimer le compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tous vos lapins, accouplements, portées, finances, publications et '
            'photos seront effacés définitivement. Cette action est irréversible.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Tapez SUPPRIMER pour confirmer',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}
