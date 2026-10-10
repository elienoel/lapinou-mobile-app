import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

/// Enregistreur de notes vocales (AAC / .m4a, mono, léger). Abstrait pour pouvoir le remplacer en test.
abstract class VoiceRecorder {
  /// Demande (si besoin) et renvoie l'autorisation d'utiliser le micro.
  Future<bool> requestPermission();

  Future<void> start(String path);

  /// Termine l'enregistrement et renvoie le chemin du fichier (null si rien n'a été enregistré).
  Future<String?> stop();

  /// Abandonne l'enregistrement et supprime le fichier.
  Future<void> cancel();

  Future<void> dispose();
}

class RecordVoiceRecorder implements VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
    ),
    path: path,
  );

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Lecture d'une note vocale (réseau ou fichier local).
abstract class VoicePlayback {
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<bool> get playingStream;
  Stream<void> get completeStream;

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

class AudioplayersPlayback implements VoicePlayback {
  AudioplayersPlayback(this._source);

  final Source _source;
  final AudioPlayer _player = AudioPlayer();
  bool _started = false;

  @override
  Stream<Duration> get positionStream => _player.onPositionChanged;

  @override
  Stream<Duration> get durationStream => _player.onDurationChanged;

  @override
  Stream<bool> get playingStream =>
      _player.onPlayerStateChanged.map((s) => s == PlayerState.playing);

  @override
  Stream<void> get completeStream => _player.onPlayerComplete;

  @override
  Future<void> play() async {
    // Première lecture, ou relecture après la fin : on repart de la source
    if (!_started || _player.state == PlayerState.completed) {
      _started = true;
      await _player.play(_source);
    } else {
      await _player.resume();
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setPlaybackRate(speed);

  @override
  Future<void> dispose() => _player.dispose();
}

/// Point d'entrée unique vers l'audio de l'appareil ; les tests y branchent des faux.
class VoiceServices {
  static VoiceRecorder Function() recorder = () => RecordVoiceRecorder();

  static VoicePlayback Function({String? url, String? filePath}) playback =
      ({url, filePath}) => AudioplayersPlayback(
        filePath != null ? DeviceFileSource(filePath) : UrlSource(url!),
      );
}
