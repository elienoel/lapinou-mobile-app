import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/community_post.dart';
import '../theme/colors.dart';

/// Grille de photos/vidéos d'une publication, façon Facebook :
/// 1 média = pleine largeur, 2 = côte à côte, 3 = un grand + deux petits,
/// 4 et + = grille 2x2 avec un compteur "+N" sur la dernière tuile.
class PostMediaGrid extends StatelessWidget {
  final List<PostMedia> media;
  final void Function(int index) onOpen;

  const PostMediaGrid({super.key, required this.media, required this.onOpen});

  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    // Une seule vidéo : lecteur intégré directement dans le fil
    if (media.length == 1 && media.first.isVideo) {
      return PostVideoPlayer(
        url: media.first.url,
        onFullscreen: () => onOpen(0),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        switch (media.length) {
          case 1:
            return _tile(0, w, w > 0 ? (w * 0.9).clamp(200, 460) : 300);
          case 2:
            final half = (w - _gap) / 2;
            return Row(
              children: [
                _tile(0, half, half * 1.15),
                const SizedBox(width: _gap),
                _tile(1, half, half * 1.15),
              ],
            );
          case 3:
            final half = (w - _gap) / 2;
            return Column(
              children: [
                _tile(0, w, w * 0.62),
                const SizedBox(height: _gap),
                Row(
                  children: [
                    _tile(1, half, half * 0.8),
                    const SizedBox(width: _gap),
                    _tile(2, half, half * 0.8),
                  ],
                ),
              ],
            );
          default:
            final half = (w - _gap) / 2;
            final extra = media.length - 4;
            return Column(
              children: [
                Row(
                  children: [
                    _tile(0, half, half),
                    const SizedBox(width: _gap),
                    _tile(1, half, half),
                  ],
                ),
                const SizedBox(height: _gap),
                Row(
                  children: [
                    _tile(2, half, half),
                    const SizedBox(width: _gap),
                    _tile(3, half, half, extra: extra),
                  ],
                ),
              ],
            );
        }
      },
    );
  }

  Widget _tile(int index, double width, double height, {int extra = 0}) {
    final item = media[index];
    return GestureDetector(
      onTap: () => onOpen(index),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.isVideo)
              Container(
                color: AppColors.primary,
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              )
            else
              Image.network(
                item.url,
                fit: BoxFit.cover,
                loadingBuilder:
                    (context, child, progress) =>
                        progress == null
                            ? child
                            : Container(
                              color: Colors.white,
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                errorBuilder:
                    (_, __, ___) => Container(
                      color: Colors.white,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
              ),
            if (extra > 0)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lecteur vidéo réseau : première image visible, tap pour lire/mettre en pause,
/// barre de progression déplaçable.
class PostVideoPlayer extends StatefulWidget {
  final String url;
  final bool autoPlay;
  final VoidCallback? onFullscreen;

  const PostVideoPlayer({
    super.key,
    required this.url,
    this.autoPlay = false,
    this.onFullscreen,
  });

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..addListener(_onTick);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});
          if (widget.autoPlay) _controller.play();
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final v = _controller.value;
    if (v.isPlaying) {
      _controller.pause();
    } else {
      if (v.position >= v.duration) _controller.seekTo(Duration.zero);
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return _placeholder(
        const Icon(
          Icons.videocam_off_outlined,
          color: Colors.white70,
          size: 40,
        ),
      );
    }
    if (!_controller.value.isInitialized) {
      return _placeholder(
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }

    final v = _controller.value;
    final ratio = v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
    return Container(
      color: Colors.black,
      child: AspectRatio(
        // Les vidéos verticales sont limitées pour ne pas occuper tout l'écran
        aspectRatio: ratio < 0.8 ? 0.8 : ratio,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: ratio,
                  child: VideoPlayer(_controller),
                ),
              ),
              if (!v.isPlaying)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  children: [
                    Expanded(
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                    if (widget.onFullscreen != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                        ),
                        onPressed: widget.onFullscreen,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(Widget child) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: AppColors.primary,
        child: Center(child: child),
      ),
    );
  }
}

/// Visionneuse plein écran : défilement horizontal entre les médias,
/// zoom au pincement pour les photos, lecture pour les vidéos.
class MediaViewerScreen extends StatefulWidget {
  final List<PostMedia> media;
  final int initialIndex;

  const MediaViewerScreen({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title:
            widget.media.length > 1
                ? Text(
                  '${_index + 1} / ${widget.media.length}',
                  style: const TextStyle(fontSize: 15),
                )
                : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.media.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final item = widget.media[i];
          if (item.isVideo) {
            return Center(
              child: PostVideoPlayer(url: item.url, autoPlay: true),
            );
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image.network(
                item.url,
                fit: BoxFit.contain,
                loadingBuilder:
                    (context, child, progress) =>
                        progress == null
                            ? child
                            : const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                errorBuilder:
                    (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
              ),
            ),
          );
        },
      ),
    );
  }
}
