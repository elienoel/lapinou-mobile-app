import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_services.dart';
import '../theme/colors.dart';

/// Lecteur d'une note vocale dans une bulle : lecture/pause, barre de progression déplaçable,
/// durée et vitesse (1x, 1.5x, 2x). Une seule note joue à la fois dans l'application.
class VoiceMessagePlayer extends StatefulWidget {
  final String? url;
  final String? filePath;
  final int? durationMs;
  final bool isMine;

  const VoiceMessagePlayer({
    super.key,
    this.url,
    this.filePath,
    this.durationMs,
    required this.isMine,
  }) : assert(url != null || filePath != null);

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  /// La note en cours de lecture (pour arrêter les autres quand on en lance une)
  static _VoiceMessagePlayerState? _active;

  VoicePlayback? _playback;
  final List<StreamSubscription> _subs = [];

  bool _playing = false;
  Duration _position = Duration.zero;
  late Duration _duration;
  double _speed = 1.0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.durationMs ?? 0);
  }

  /// Le lecteur natif n'est créé qu'à la première lecture (une liste peut contenir beaucoup de notes)
  VoicePlayback _ensurePlayback() {
    var p = _playback;
    if (p != null) return p;
    p = VoiceServices.playback(url: widget.url, filePath: widget.filePath);
    _playback = p;
    _subs.addAll([
      p.positionStream.listen((pos) {
        if (mounted) setState(() => _position = pos);
      }),
      p.durationStream.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _duration = d);
      }),
      p.playingStream.listen((playing) {
        if (mounted) setState(() => _playing = playing);
      }),
      p.completeStream.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
        }
      }),
    ]);
    return p;
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _playback?.pause();
      return;
    }
    if (_active != null && _active != this) await _active!._pauseFromOutside();
    _active = this;
    try {
      setState(() => _failed = false);
      final p = _ensurePlayback();
      await p.setSpeed(_speed);
      await p.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _pauseFromOutside() async {
    await _playback?.pause();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _cycleSpeed() async {
    final next = _speed == 1.0 ? 1.5 : (_speed == 1.5 ? 2.0 : 1.0);
    setState(() => _speed = next);
    await _playback?.setSpeed(next);
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    for (final s in _subs) {
      s.cancel();
    }
    _playback?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.isMine ? Colors.white : AppColors.primary;
    final soft = widget.isMine ? Colors.white38 : AppColors.primarySoftBorder;
    final meta = widget.isMine ? Colors.white70 : const Color(0xFF64748B);

    final total = _duration.inMilliseconds;
    final progress =
        total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
    final showPosition = _playing || _position > Duration.zero;

    return SizedBox(
      width: 230,
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMine ? Colors.white : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _failed
                    ? Icons.error_outline
                    : (_playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                color: widget.isMine ? AppColors.primary : Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: fg,
                    inactiveTrackColor: soft,
                    thumbColor: fg,
                  ),
                  child: SizedBox(
                    height: 22,
                    child: Slider(
                      value: progress,
                      onChanged:
                          total > 0 && _playback != null
                              ? (v) => _playback!.seek(
                                Duration(milliseconds: (v * total).round()),
                              )
                              : null,
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _failed
                            ? 'Lecture impossible'
                            : _fmt(showPosition ? _position : _duration),
                        style: TextStyle(fontSize: 11, color: meta),
                      ),
                    ),
                    if (_playing || _speed != 1.0)
                      GestureDetector(
                        onTap: _cycleSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: soft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
