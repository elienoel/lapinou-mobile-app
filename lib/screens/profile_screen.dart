import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/rabbit_provider.dart';
import '../services/sync_service.dart';
import '../theme/colors.dart';
import '../theme/radius.dart';
import '../widgets/author_avatar.dart';
import 'settings_screen.dart';

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

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
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
          ? _toast('Photo de profil mise à jour')
          : _toast(error, error: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _toast("Impossible d'accéder à la photo.", error: true);
      }
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _isUploadingPhoto = true);
    final error = await context.read<AuthProvider>().removeAvatar();
    if (!mounted) return;
    setState(() => _isUploadingPhoto = false);
    error == null ? _toast('Photo supprimée') : _toast(error, error: true);
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
    error == null ? _toast('Profil enregistré') : _toast(error, error: true);
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
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Déconnexion'),
            content: Text(
              pending > 0
                  ? 'Voulez-vous vraiment vous déconnecter ?\n\n'
                      '$pending modification${pending > 1 ? 's' : ''} ne '
                      "${pending > 1 ? 'sont' : 'est'} pas encore synchronisée${pending > 1 ? 's' : ''}. "
                      'Elle${pending > 1 ? 's seront' : ' sera'} envoyée${pending > 1 ? 's' : ''} '
                      "à la prochaine connexion à ce compte."
                  : 'Voulez-vous vraiment vous déconnecter ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Déconnexion'),
              ),
            ],
          ),
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
    if (error != null) _toast(error, error: true);
    // En cas de succès, la session est fermée et l'écran de connexion s'affiche
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    if (_loadedForUserId != user.id) _fillFrom(user);

    final rabbits = context.watch<RabbitProvider>();

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Mon profil',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Paramètres',
            icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(user),
              const SizedBox(height: 16),
              _buildStats(rabbits),
              const SizedBox(height: 16),
              _buildPersonalInfo(user),
              const SizedBox(height: 16),
              _buildAccountCard(user),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeader(AuthUser user) {
    return _card(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isUploadingPhoto ? null : () => _showPhotoOptions(user),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AuthorAvatar(
                  // La clé force le rechargement quand l'URL de la photo change
                  key: ValueKey(user.avatar),
                  name: user.displayName,
                  url: user.avatar,
                  radius: 52,
                ),
                if (_isUploadingPhoto)
                  Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.photo_camera,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            [
                  user.firstName,
                  user.lastName,
                ].where((e) => e != null && e.isNotEmpty).join(' ').isEmpty
                ? user.displayName
                : [
                  user.firstName,
                  user.lastName,
                ].where((e) => e != null && e.isNotEmpty).join(' '),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          if (user.farmName != null && user.farmName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '🏡 ${user.farmName}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          if (user.location != null && user.location!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '📍 ${user.location}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (user.bio != null && user.bio!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                user.bio!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
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

    return _card(
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
          row(Icons.person_outline, 'Prénom', user.firstName),
          row(Icons.badge_outlined, 'Nom', user.lastName),
          row(Icons.home_work_outlined, "Nom de l'élevage", user.farmName),
          row(Icons.location_on_outlined, 'Localisation', user.location),
          row(Icons.mail_outline, 'Email', user.email),
          row(Icons.notes_outlined, 'À propos de vous', user.bio),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AuthUser user) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mon compte',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
            title: Text(user.phoneNumber ?? '—'),
            subtitle: const Text('Numéro de connexion (non modifiable)'),
          ),
          if (user.createdAt != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_available_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                'Membre depuis le ${DateFormat('d MMMM yyyy', 'fr_FR').format(user.createdAt!.toLocal())}',
              ),
            ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, color: AppColors.primary),
            title: const Text('Se déconnecter'),
            onTap: _confirmLogout,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.redAccent,
            ),
            title: const Text(
              'Supprimer mon compte',
              style: TextStyle(color: Colors.redAccent),
            ),
            subtitle: const Text(
              'Efface définitivement votre élevage et vos publications',
            ),
            onTap: _confirmDeleteAccount,
          ),
        ],
      ),
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
