import '../widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/colors.dart';

/// Format national d'un numéro : indicatif, nombre exact de chiffres
/// et regroupement affiché pendant la saisie.
class PhoneCountry {
  final String code;
  final String name;
  final String iso;
  final List<int> groups;

  const PhoneCountry({
    required this.code,
    required this.name,
    required this.iso,
    required this.groups,
  });

  int get digits => groups.fold(0, (a, b) => a + b);

  /// Exemple affiché en placeholder, au bon format.
  String get hint {
    final sample = switch (iso) {
      'CI' => '0700000000',
      'SN' => '771234567',
      'CM' => '671234567',
      'BJ' => '0197000000',
      'BF' => '70123456',
      'TG' => '90123456',
      'FR' => '612345678',
      _ => '0' * digits,
    };
    return format(sample);
  }

  String format(String raw) {
    final buffer = StringBuffer();
    var i = 0;
    for (final g in groups) {
      if (i >= raw.length) break;
      if (buffer.isNotEmpty) buffer.write(' ');
      final end = (i + g).clamp(0, raw.length);
      buffer.write(raw.substring(i, end));
      i = end;
    }
    return buffer.toString();
  }
}

const List<PhoneCountry> kPhoneCountries = [
  PhoneCountry(
    code: '+225',
    name: 'Côte d\'Ivoire',
    iso: 'CI',
    groups: [2, 2, 2, 2, 2],
  ),
  PhoneCountry(code: '+221', name: 'Sénégal', iso: 'SN', groups: [2, 3, 2, 2]),
  PhoneCountry(
    code: '+237',
    name: 'Cameroun',
    iso: 'CM',
    groups: [1, 2, 2, 2, 2],
  ),
  PhoneCountry(code: '+229', name: 'Bénin', iso: 'BJ', groups: [2, 2, 2, 2, 2]),
  PhoneCountry(
    code: '+226',
    name: 'Burkina Faso',
    iso: 'BF',
    groups: [2, 2, 2, 2],
  ),
  PhoneCountry(code: '+228', name: 'Togo', iso: 'TG', groups: [2, 2, 2, 2]),
  PhoneCountry(code: '+33', name: 'France', iso: 'FR', groups: [1, 2, 2, 2, 2]),
];

/// Ne garde que les chiffres, bloque au-delà de la longueur du pays
/// et insère les espaces du format national.
class _PhoneFormatter extends TextInputFormatter {
  final PhoneCountry country;

  _PhoneFormatter(this.country);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > country.digits) {
      digits = digits.substring(0, country.digits);
    }
    final text = country.format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

const double _fieldRadius = 14;
const BorderSide _whiteBorder = BorderSide(color: Colors.white, width: 1.4);

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  PhoneCountry _country = kPhoneCountries.first; // Côte d'Ivoire par défaut
  String? _error;

  String get _digits => _phoneController.text.replaceAll(' ', '');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _selectCountry(PhoneCountry c) {
    setState(() {
      _country = c;
      _error = null;
      var digits = _digits;
      if (digits.length > c.digits) digits = digits.substring(0, c.digits);
      _phoneController.text = c.format(digits);
    });
  }

  Future<void> _pickCountry() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<PhoneCountry>(
      context: context,
      backgroundColor: AppColors.secondaryDark,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(120),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Choisir l\'indicatif',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children:
                          kPhoneCountries.map((c) {
                            final selected = c.code == _country.code;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color:
                                    selected
                                        ? Colors.white.withAlpha(28)
                                        : Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color:
                                        selected
                                            ? Colors.white
                                            : Colors.white.withAlpha(70),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.pop(ctx, c),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 56,
                                          child: Text(
                                            c.code,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    if (picked != null) _selectCountry(picked);
  }

  Future<void> _submitPhoneNumber() async {
    if (_digits.length != _country.digits) {
      setState(() => _error = 'Numéro de téléphone incomplet');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();

    final phone = '${_country.code}$_digits';
    final auth = context.read<AuthProvider>();

    final success = await auth.requestOtp(phone);
    if (success && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => OtpVerificationScreen(
                phoneNumber: phone,
                displayNumber: '${_country.code} ${_country.format(_digits)}',
              ),
        ),
      );
    } else if (mounted && auth.errorMessage != null) {
      showAppSnack(context, auth.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutBack,
                    builder:
                        (context, v, child) => Transform.scale(
                          scale: v,
                          child: Opacity(
                            opacity: v.clamp(0.0, 1.0),
                            child: child,
                          ),
                        ),
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Clap'in",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gestion intelligente & Communauté d\'éleveurs',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 15, color: Colors.white),
                ),
                const SizedBox(height: 48),

                Text(
                  'Connexion rapide',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Entrez votre numéro pour recevoir votre code de connexion par SMS.',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Numéro de téléphone',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Indicatif et numéro dans un seul champ
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(_fieldRadius),
                    border: Border.fromBorderSide(
                      _error != null
                          ? const BorderSide(color: Colors.white, width: 2.2)
                          : _whiteBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _pickCountry,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(_fieldRadius),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 10),
                          child: Row(
                            children: [
                              Text(
                                _country.code,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1.4, height: 28, color: Colors.white),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          cursorColor: Colors.white,
                          inputFormatters: [_PhoneFormatter(_country)],
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          onSubmitted: (_) => _submitPhoneNumber(),
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: _country.hint,
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 17,
                              color: Colors.white.withAlpha(140),
                            ),
                            // Annule le fond blanc et les bordures du thème global
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),

                // Fond violet : bouton noir
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submitPhoneNumber,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child:
                        auth.isLoading
                            ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                            : Text(
                              'Recevoir le code',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Connexion sécurisée sans mot de passe',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  /// Numéro mis en forme pour l'affichage (ex. +225 07 00 00 00 00).
  final String? displayNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.displayNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _length = 6;
  String _code = '';

  void _press(String digit) {
    if (_code.length >= _length) return;
    HapticFeedback.selectionClick();
    setState(() => _code += digit);
    if (_code.length == _length) _verifyOtp();
  }

  void _backspace() {
    if (_code.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _verifyOtp() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) return;
    if (_code.length < _length) {
      showAppSnack(context, 'Veuillez saisir le code à $_length chiffres');
      return;
    }

    final success = await auth.verifyOtp(otpCode: _code);

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (mounted) {
      setState(() => _code = '');
      if (auth.errorMessage != null) showAppSnack(context, auth.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.secondary,
        appBar: AppBar(
          backgroundColor: AppColors.secondary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder:
                (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 20).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Vérification',
                            style: GoogleFonts.outfit(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text.rich(
                            TextSpan(
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                height: 1.4,
                                color: Colors.white,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'Saisissez le code à 6 chiffres envoyé au ',
                                ),
                                TextSpan(
                                  text:
                                      widget.displayNumber ??
                                      widget.phoneNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Cases du code
                          Row(
                            children: List.generate(_length, (i) {
                              final filled = i < _code.length;
                              final active =
                                  i == _code.length && !auth.isLoading;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: i == 0 ? 0 : 8,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 0.82,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color:
                                            active
                                                ? Colors.white.withAlpha(30)
                                                : AppColors.secondary,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: active || filled ? 2 : 1.2,
                                        ),
                                      ),
                                      child: Text(
                                        filled ? _code[i] : '',
                                        style: GoogleFonts.outfit(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton(
                              onPressed:
                                  auth.isLoading
                                      ? null
                                      : () {
                                        auth.requestOtp(widget.phoneNumber);
                                        setState(() => _code = '');
                                        showAppSnack(
                                          context,
                                          'Un nouveau code a été envoyé',
                                        );
                                      },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                'Renvoyer le code par SMS',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Clavier numérique intégré
                          _OtpKeypad(
                            enabled: !auth.isLoading,
                            onDigit: _press,
                            onBackspace: _backspace,
                          ),
                          const SizedBox(height: 16),

                          // Fond violet : bouton noir
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child:
                                  auth.isLoading
                                      ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                      : Text(
                                        'Confirmer',
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
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class _OtpKeypad extends StatelessWidget {
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  const _OtpKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];
    return Column(
      children:
          rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: List.generate(row.length, (i) {
                  final key = row[i];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 10),
                      child:
                          key.isEmpty
                              ? const SizedBox(height: 60)
                              : _KeypadKey(
                                enabled: enabled,
                                onTap:
                                    key == '<'
                                        ? onBackspace
                                        : () => onDigit(key),
                                child:
                                    key == '<'
                                        ? const Icon(
                                          Icons.backspace_outlined,
                                          color: Colors.white,
                                          size: 24,
                                        )
                                        : Text(
                                          key,
                                          style: GoogleFonts.outfit(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                              ),
                    ),
                  );
                }),
              ),
            );
          }).toList(),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  const _KeypadKey({
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        splashColor: Colors.white.withAlpha(50),
        highlightColor: Colors.white.withAlpha(30),
        child: SizedBox(height: 60, child: Center(child: child)),
      ),
    );
  }
}
