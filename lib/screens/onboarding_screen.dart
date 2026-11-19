import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/colors.dart';

/// Clé locale indiquant que l'utilisateur a déjà vu l'onboarding.
const String kOnboardingSeenKey = 'onboarding_seen';

class _OnboardingPage {
  final String image;
  final String title;
  final String description;
  final Color background;

  /// Bouton noir sur fond violet, bouton violet sur fond noir.
  final Color buttonColor;

  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.description,
    required this.background,
    required this.buttonColor,
  });
}

const List<_OnboardingPage> _pages = [
  _OnboardingPage(
    image: 'assets/onboarding-1.webp',
    title: 'Bienvenue sur Clap\'in',
    description:
        'Gérez votre élevage comme un pro : chaque lapin, chaque cage et chaque portée dans votre poche, même sans connexion.',
    background: AppColors.secondary,
    buttonColor: AppColors.primary,
  ),
  _OnboardingPage(
    image: 'assets/onboarding-2.webp',
    title: 'Suivez vos revenus et vos dépenses',
    description:
        'Ventes, alimentation, soins : voyez en un coup d\'œil si votre clapier est rentable.',
    background: AppColors.secondaryDark,
    buttonColor: AppColors.primary,
  ),
  _OnboardingPage(
    image: 'assets/onboarding-3.webp',
    title: 'Planifiez avec précision',
    description:
        'Saillies, palpations, mises bas et vaccins : Clap\'in vous rappelle chaque étape au bon moment.',
    background: AppColors.secondary,
    buttonColor: AppColors.primary,
  ),
];

class OnboardingScreen extends StatefulWidget {
  /// Appelé quand l'utilisateur termine ou passe l'onboarding.
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _index => _page.round().clamp(0, _pages.length - 1);
  bool get _isLast => _index == _pages.length - 1;

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingSeenKey, true);
    } catch (_) {}
    widget.onFinished();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  /// Couleur interpolée entre deux pages pendant le glissement.
  Color _lerp(Color Function(_OnboardingPage) pick) {
    final low = _page.floor().clamp(0, _pages.length - 1);
    final high = _page.ceil().clamp(0, _pages.length - 1);
    return Color.lerp(pick(_pages[low]), pick(_pages[high]), _page - low)!;
  }

  @override
  Widget build(BuildContext context) {
    final background = _lerp((p) => p.background);
    final buttonColor = _lerp((p) => p.buttonColor);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              // Barre du haut : logo + "Passer"
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Text(
                        "Clap'in",
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: _isLast ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: _isLast,
                          child: TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              'Passer',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Carrousel
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  itemBuilder:
                      (context, i) => _OnboardingSlide(page: _pages[i]),
                ),
              ),

              // Indicateurs + bouton
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                active
                                    ? Colors.white
                                    : Colors.white.withAlpha(90),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _isLast ? 'Commencer' : 'Suivant',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
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
}

class _OnboardingSlide extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingSlide({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                // Panneau clair : l'illustration détourée (salopette violette)
                // ne se fond pas dans le fond violet ou noir de la page.
                // color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              // padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Image.asset(
                page.image,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: GoogleFonts.outfit(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.description,
            style: GoogleFonts.outfit(
              fontSize: 16,
              height: 1.45,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
