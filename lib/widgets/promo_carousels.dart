import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/features.dart';
import '../models/promo_carousel.dart';
import '../providers/promotions_provider.dart';
import '../screens/activity_screen.dart';
import '../screens/care_screen.dart';
import '../screens/conversations_screen.dart';
import '../screens/main_navigation_screen.dart';
import '../screens/marketplace_screen.dart';
import '../screens/matings_screen.dart';
import '../screens/pharmacy_screen.dart';
import '../screens/rabbit_list_screen.dart';
import '../theme/colors.dart';

/// Carrousels d'annonces de la page d'accueil, l'un sous l'autre dans l'ordre
/// défini dans l'admin. Rien n'est affiché tant qu'aucune annonce n'est active.
class PromoCarousels extends StatelessWidget {
  const PromoCarousels({super.key});

  @override
  Widget build(BuildContext context) {
    final carousels = context.watch<PromotionsProvider>().carousels;
    if (carousels.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < carousels.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 20),
            child: PromoCarouselView(
              key: ValueKey('promo-${carousels[i].id}'),
              carousel: carousels[i],
            ),
          ),
      ],
    );
  }
}

/// Un carrousel : images 16:9 qui défilent seules toutes les 5 secondes,
/// avec des points indicateurs en dessous quand il y en a plusieurs.
class PromoCarouselView extends StatefulWidget {
  const PromoCarouselView({
    super.key,
    required this.carousel,
    this.interval = const Duration(seconds: 5),
  });

  final PromoCarousel carousel;
  final Duration interval;

  /// Épaisseur du cadre blanc et arrondi de la carte
  static const double frame = 5;
  static const double radius = 20;

  /// Hauteur de la carte pour une largeur donnée (image 16:9 + cadre).
  static double cardHeight(double width) =>
      (width - 2 * frame) * 9 / 16 + 2 * frame;

  @override
  State<PromoCarouselView> createState() => _PromoCarouselViewState();
}

class _PromoCarouselViewState extends State<PromoCarouselView> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  List<PromoSlide> get _slides => widget.carousel.slides;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(PromoCarouselView old) {
    super.didUpdateWidget(old);
    if (_page >= _slides.length) _page = 0;
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_slides.length < 2) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Carte : cadre blanc translucide et flouté, avec une ombre portée
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PromoCarouselView.radius),
            // boxShadow: [
            //   BoxShadow(
            //     color: Colors.black.withAlpha(45),
            //     blurRadius: 18,
            //     offset: const Offset(0, 8),
            //   ),
            // ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PromoCarouselView.radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(PromoCarouselView.frame),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(150),
                  borderRadius: BorderRadius.circular(PromoCarouselView.radius),
                  // border: Border.all(color: Colors.white.withAlpha(220)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    PromoCarouselView.radius - PromoCarouselView.frame,
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _slides.length,
                      onPageChanged: (i) {
                        setState(() => _page = i);
                        _restartTimer(); // un balayage manuel repart pour 5 s
                      },
                      itemBuilder:
                          (context, i) => _SlideImage(slide: _slides[i]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_slides.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.primary : AppColors.textMuted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Source des images d'annonce (remplaçable en test, où le réseau est coupé).
@visibleForTesting
ImageProvider Function(String url) promoImageProvider = NetworkImage.new;

class _SlideImage extends StatelessWidget {
  const _SlideImage({required this.slide});

  final PromoSlide slide;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(color: AppColors.secondarySoft);
    final image = Image(
      image: promoImageProvider(slide.imageUrl),
      fit: BoxFit.cover,
      semanticLabel: slide.title.isEmpty ? null : slide.title,
      loadingBuilder:
          (context, child, progress) => progress == null ? child : placeholder,
      errorBuilder: (context, error, stack) => placeholder,
    );
    if (slide.linkType == 'none') return image;
    // L'effet d'appui est posé au-dessus de l'image, sinon elle le cacherait
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Material(
          color: Colors.transparent,
          child: InkWell(onTap: () => openPromoSlide(context, slide)),
        ),
      ],
    );
  }
}

/// Ouvre la destination d'une annonce : un écran de l'app ou un site web.
Future<void> openPromoSlide(BuildContext context, PromoSlide slide) async {
  if (slide.linkType == 'external') {
    final uri = Uri.tryParse(slide.externalUrl ?? '');
    if (uri == null || !uri.hasScheme) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir le lien")),
      );
    }
    return;
  }
  if (slide.linkType != 'internal') return;

  void push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  switch (slide.targetScreen) {
    // Modules masqués dans cette version : l'annonce ne mène nulle part
    case 'pharmacy':
      if (Features.pharmacy) push(const PharmacyScreen());
    case 'marketplace':
      if (Features.marketplace) push(const MarketplaceScreen());
    case 'rabbits':
      push(const RabbitListScreen());
    case 'reproduction':
      push(const MatingsScreen());
    case 'care':
      push(const CareScreen());
    case 'chat':
      push(const ConversationsScreen());
    case 'activity':
      push(const ActivityScreen());
    case 'community':
      MainNavigationScreen.goToTab(context, MainNavigationScreen.communityTab);
    case 'finances':
      MainNavigationScreen.goToTab(context, MainNavigationScreen.financesTab);
  }
}
