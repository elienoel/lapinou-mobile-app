import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Images de la communauté téléchargées par l'utilisateur : tant qu'une
/// image ne l'est pas, le fil n'en montre qu'un aperçu flou (économie de
/// données). La liste est gardée d'une session à l'autre.
class MediaDownloads extends ChangeNotifier {
  MediaDownloads._();
  static final instance = MediaDownloads._();

  static const _key = 'downloaded_media';
  static const _max = 500;

  final List<String> _done = [];
  final Set<String> _loading = {};
  bool _loaded = false;

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _done.addAll(prefs.getStringList(_key) ?? const []);
      notifyListeners();
    } catch (_) {}
  }

  bool isDownloaded(String url) {
    _load();
    return _done.contains(url);
  }

  bool isLoading(String url) => _loading.contains(url);

  /// Télécharge l'image (mise en cache) puis la marque comme téléchargée.
  Future<void> download(BuildContext context, String url) async {
    if (_loading.contains(url) || _done.contains(url)) return;
    _loading.add(url);
    notifyListeners();
    var ok = true;
    await precacheImage(
      NetworkImage(url),
      context,
      onError: (_, __) => ok = false,
    );
    _loading.remove(url);
    if (ok) {
      _done.add(url);
      if (_done.length > _max) _done.removeAt(0);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_key, _done);
      } catch (_) {}
    }
    notifyListeners();
  }

  @visibleForTesting
  void resetForTesting() {
    _done.clear();
    _loading.clear();
    _loaded = true;
  }
}

/// « 850 Ko », « 1,2 Mo »
String formatFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} Ko';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} Mo';
}
