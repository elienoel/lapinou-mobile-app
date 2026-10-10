import 'dart:io';

/// Règles de saisie reprises à l'identique du serveur (messages en français).
/// Chaque fonction renvoie null si la valeur est acceptée, sinon le motif du refus.
class Validators {
  Validators._();

  static const int maxPhotoBytes = 10 * 1024 * 1024;
  static const int maxVideoBytes = 100 * 1024 * 1024;
  static const int maxAvatarBytes = 5 * 1024 * 1024;
  static const int maxAudioBytes = 15 * 1024 * 1024;
  static const int maxAudioMs = 600000;
  static const int maxChatLength = 4000;
  static const int maxPostMedia = 10;
  static const double maxAmount = 99999999.99;

  static const List<String> reactionEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🙏',
  ];

  static const _imageExt = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  static const _videoExt = {'mp4', 'mov', 'webm', '3gp'};
  static const _audioExt = {
    'm4a',
    'mp3',
    'wav',
    'aac',
    'ogg',
    'webm',
    '3gp',
    'mp4',
  };

  static String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  }

  static String _name(File f) => f.path.split(Platform.pathSeparator).last;

  static String? image(File f, {int maxBytes = maxPhotoBytes}) {
    if (!_imageExt.contains(_ext(f.path))) {
      return 'Format non pris en charge (jpg, png, gif ou webp).';
    }
    final size = f.existsSync() ? f.lengthSync() : 0;
    if (size > maxBytes) {
      return 'La photo dépasse ${maxBytes ~/ (1024 * 1024)} Mo.';
    }
    return null;
  }

  static String? avatar(File f) => image(f, maxBytes: maxAvatarBytes);

  /// Photo ou vidéo d'une publication communautaire.
  static String? postMedia(File f) {
    final ext = _ext(f.path);
    final size = f.existsSync() ? f.lengthSync() : 0;
    if (_imageExt.contains(ext)) {
      return size > maxPhotoBytes ? '« ${_name(f)} » dépasse 10 Mo.' : null;
    }
    if (_videoExt.contains(ext)) {
      return size > maxVideoBytes ? '« ${_name(f)} » dépasse 100 Mo.' : null;
    }
    return 'Format non pris en charge : « ${_name(f)} ». '
        'Photos (jpg, png, gif, webp) ou vidéos (mp4, mov, webm, 3gp).';
  }

  static String? postMediaCount(int count) =>
      count > maxPostMedia
          ? 'Maximum $maxPostMedia photos/vidéos par publication.'
          : null;

  static String? audio(File f, {int? durationMs}) {
    if (!_audioExt.contains(_ext(f.path)))
      return 'Format audio non pris en charge.';
    final size = f.existsSync() ? f.lengthSync() : 0;
    if (size > maxAudioBytes) return 'La note vocale dépasse 15 Mo.';
    if (durationMs != null && durationMs > maxAudioMs) {
      return 'Note vocale trop longue (10 minutes maximum).';
    }
    return null;
  }

  static String? chatMessage({required String text, File? image, File? audio}) {
    if (text.length > maxChatLength) {
      return 'Message trop long ($maxChatLength caractères maximum).';
    }
    if (image == null && audio == null && text.trim().isEmpty) {
      return 'Écrivez un message, joignez une photo ou une note vocale.';
    }
    if (image != null && audio != null) {
      return 'Envoyez une photo ou une note vocale, pas les deux.';
    }
    if (image != null) return Validators.image(image);
    return null;
  }

  static String? phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s\-().]'), '');
    if (digits.length < 8) return 'Numéro de téléphone invalide.';
    return null;
  }

  static String? amount(double amount) {
    if (amount <= 0) return 'Le montant doit être supérieur à 0.';
    if (amount > maxAmount)
      return 'Le montant ne peut pas dépasser 99 999 999,99.';
    return null;
  }

  static String? postContent({
    required String content,
    required int mediaCount,
  }) {
    if (content.trim().isEmpty && mediaCount == 0) {
      return 'Écrivez un message ou ajoutez une photo/vidéo.';
    }
    return null;
  }

  static String? cageSize({required int rows, required int columns}) {
    if (rows < 1 || rows > 12)
      return 'Le nombre de lignes doit être entre 1 et 12.';
    if (columns < 1 || columns > 6)
      return 'Le nombre de colonnes doit être entre 1 et 6.';
    return null;
  }
}
