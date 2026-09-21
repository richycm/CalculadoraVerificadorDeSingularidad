// Verificador de Singularidad de Curvas Elípticas
// y² ≡ x³ + ax + b (mod n)
// Flutter puro (Material 3) — sin dependencias externas más allá de las de Flutter.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SingularityApp());
}

// ---------------------------------------------------------------------------
// Paleta / Tema
// ---------------------------------------------------------------------------

const kBg = Color(0xFF07060B);
const kBg2 = Color(0xFF0C0A14);
const kSurface = Color(0xFF14121C);
const kSurfaceAlt = Color(0xFF1A1826);
const kIndigo = Color(0xFF7C6CFF);
const kViolet = Color(0xFFA377FF);
const kEmerald = Color(0xFF17E3A8);
const kDanger = Color(0xFFFF5C7A);
const kTextPrimary = Color(0xFFF3F1FA);
const kTextSecondary = Color(0xFFA6A2BE);
const kTextFaint = Color(0xFF716C8C);
const kBorder = Color(0x1FFFFFFF);

class SingularityApp extends StatelessWidget {
  const SingularityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verificador de Singularidad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kIndigo,
          secondary: kEmerald,
          surface: kSurface,
          error: kDanger,
        ),
        textSelectionTheme:
            const TextSelectionThemeData(cursorColor: kIndigo),
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Modelo de cálculo
// ---------------------------------------------------------------------------

class Step {
  final String label;
  final String content;
  const Step(this.label, this.content);
}

class CalcResult {
  final bool singular;
  final String verdictSubtitle;
  final String justification;
  final List<Step> steps;
  const CalcResult({
    required this.singular,
    required this.verdictSubtitle,
    required this.justification,
    required this.steps,
  });
}

String _paren(BigInt v) => v.isNegative ? '($v)' : '$v';

bool _isPrime(BigInt n) {
  if (n < BigInt.two) return false;
  if (n == BigInt.two) return true;
  if (n % BigInt.two == BigInt.zero) return false;
  BigInt i = BigInt.from(3);
  while (i * i <= n) {
    if (n % i == BigInt.zero) return false;
    i += BigInt.two;
  }
  return true;
}

/// Excepción de validación con mensajes dirigidos a un campo específico.
class FieldError implements Exception {
  final String field; // 'a' | 'b' | 'n'
  final String message;
  FieldError(this.field, this.message);
}

CalcResult calculateSingularity({
  required String rawA,
  required String rawB,
  required String rawN,
}) {
  if (rawA.trim().isEmpty) throw FieldError('a', 'Campo requerido');
  if (rawB.trim().isEmpty) throw FieldError('b', 'Campo requerido');
  if (rawN.trim().isEmpty) throw FieldError('n', 'Campo requerido');

  final a = BigInt.tryParse(rawA.trim());
  final b = BigInt.tryParse(rawB.trim());
  final n = BigInt.tryParse(rawN.trim());

  if (a == null) throw FieldError('a', 'Entero inválido');
  if (b == null) throw FieldError('b', 'Entero inválido');
  if (n == null) throw FieldError('n', 'Entero inválido');
  if (n < BigInt.two) {
    throw FieldError('n', 'n debe ser un entero mayor que 1');
  }

  final a3 = a.pow(3);
  final b2 = b.pow(2);
  final t1 = BigInt.from(4) * a3;
  final t2 = BigInt.from(27) * b2;
  final sum = t1 + t2;
  final dMod = ((sum % n) + n) % n;
  final primeN = _isPrime(n);

  late final bool singular;
  late final String verificationContent;
  late final String justification;

  if (primeN) {
    singular = dMod == BigInt.zero;
    verificationContent = 'n = $n es primo.\n'
        'Condición: D mod n ≠ 0 ⇒ no singular.\n'
        'D mod n = $dMod  →  ${dMod == BigInt.zero ? "D ≡ 0 (mod n)" : "D ≢ 0 (mod n)"}';
    justification = dMod == BigInt.zero
        ? 'D ≡ 0 (mod n) — el discriminante se anula'
        : 'D ≢ 0 (mod n) — el discriminante no se anula';
  } else {
    final gcdVal = sum.abs().gcd(n);
    singular = gcdVal != BigInt.one;
    verificationContent = 'n = $n es compuesto.\n'
        'Condición: mcd(4a³ + 27b², n) = 1 ⇒ no singular.\n'
        'mcd($sum, $n) = $gcdVal';
    justification = gcdVal != BigInt.one
        ? 'mcd(D, n) = $gcdVal ≠ 1'
        : 'mcd(D, n) = 1';
  }

  final steps = <Step>[
    Step(
      '1 · Sustitución de valores',
      '4(${_paren(a)})³ + 27(${_paren(b)})²',
    ),
    Step(
      '2 · Cálculo de potencias',
      'a³ = (${_paren(a)})³ = $a3\nb² = (${_paren(b)})² = $b2',
    ),
    Step(
      '3 · Multiplicaciones',
      '4 · a³ = 4 · $a3 = $t1\n27 · b² = 27 · $b2 = $t2',
    ),
    Step(
      '4 · Suma total (D)',
      '4a³ + 27b² = $t1 + $t2 = $sum',
    ),
    Step(
      '5 · Reducción módulo n',
      'D mod n = $sum mod $n = $dMod',
    ),
    Step(
      '6 · Verificación',
      verificationContent,
    ),
  ];

  return CalcResult(
    singular: singular,
    verdictSubtitle: primeN
        ? 'n primo — criterio D mod n'
        : 'n compuesto — criterio mcd(D, n)',
    justification: justification,
    steps: steps,
  );
}

// ---------------------------------------------------------------------------
// Formateador: enteros con signo opcional
// ---------------------------------------------------------------------------

class _SignedIntegerFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (RegExp(r'^-?\d*$').hasMatch(text)) return newValue;
    return oldValue;
  }
}

// ---------------------------------------------------------------------------
// Botón con micro-animación de escala al presionar
// ---------------------------------------------------------------------------

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const TapScale({super.key, required this.child, required this.onTap});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  double _scale = 1.0;
  void _set(double s) => setState(() => _scale = s);

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _set(0.96) : null,
      onTapUp: enabled ? (_) => _set(1.0) : null,
      onTapCancel: enabled ? () => _set(1.0) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta con efecto "glass"
// ---------------------------------------------------------------------------

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? tint;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tint ?? kSurface).withOpacity(0.72),
                kSurfaceAlt.withOpacity(0.55),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _aCtrl = TextEditingController();
  final _bCtrl = TextEditingController();
  final _nCtrl = TextEditingController();

  String? _errorA;
  String? _errorB;
  String? _errorN;

  CalcResult? _result;
  int _exampleIndex = 0;

  static const _examples = [
    {'a': '2', 'b': '3', 'n': '17'},
    {'a': '-3', 'b': '2', 'n': '11'},
  ];

  @override
  void dispose() {
    _aCtrl.dispose();
    _bCtrl.dispose();
    _nCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      _errorA = null;
      _errorB = null;
      _errorN = null;
    });
    try {
      final result = calculateSingularity(
        rawA: _aCtrl.text,
        rawB: _bCtrl.text,
        rawN: _nCtrl.text,
      );
      setState(() => _result = result);
      FocusScope.of(context).unfocus();
    } on FieldError catch (e) {
      setState(() {
        _result = null;
        switch (e.field) {
          case 'a':
            _errorA = e.message;
            break;
          case 'b':
            _errorB = e.message;
            break;
          case 'n':
            _errorN = e.message;
            break;
        }
      });
    }
  }

  void _clear() {
    setState(() {
      _aCtrl.clear();
      _bCtrl.clear();
      _nCtrl.clear();
      _errorA = null;
      _errorB = null;
      _errorN = null;
      _result = null;
    });
  }

  void _loadExample() {
    final ex = _examples[_exampleIndex % _examples.length];
    _exampleIndex++;
    setState(() {
      _aCtrl.text = ex['a']!;
      _bCtrl.text = ex['b']!;
      _nCtrl.text = ex['n']!;
      _errorA = null;
      _errorB = null;
      _errorN = null;
    });
    _calculate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con orbes de luz decorativos
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kBg2, kBg],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            left: -60,
            child: _glowOrb(kIndigo.withOpacity(0.28), 220),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: _glowOrb(kEmerald.withOpacity(0.16), 260),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 560;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'DATOS DE LA CURVA',
                                  style: TextStyle(
                                    color: kTextFaint,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildFields(wide),
                                const SizedBox(height: 20),
                                _buildActions(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 420),
                            transitionBuilder: (child, anim) {
                              final curved = CurvedAnimation(
                                  parent: anim, curve: Curves.easeOutCubic);
                              return FadeTransition(
                                opacity: curved,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.06),
                                    end: Offset.zero,
                                  ).animate(curved),
                                  child: child,
                                ),
                              );
                            },
                            child: _result == null
                                ? _buildHint(key: const ValueKey('hint'))
                                : _buildResult(_result!,
                                    key: const ValueKey('result')),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [kIndigo, kViolet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.auto_graph_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verificador de Singularidad',
                    style: TextStyle(
                      color: kTextPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Curvas elípticas sobre congruencias',
                    style: TextStyle(color: kTextSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: kSurface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.functions_rounded, color: kIndigo, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'y² ≡ x³ + ax + b  (mod n)',
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFields(bool wide) {
    final fields = [
      _buildField(
        label: 'a',
        hint: 'coef. de x',
        controller: _aCtrl,
        error: _errorA,
        signed: true,
      ),
      _buildField(
        label: 'b',
        hint: 'término indep.',
        controller: _bCtrl,
        error: _errorB,
        signed: true,
      ),
      _buildField(
        label: 'n',
        hint: 'módulo',
        controller: _nCtrl,
        error: _errorN,
        signed: false,
      ),
    ];

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: fields[0]),
          const SizedBox(width: 12),
          Expanded(child: fields[1]),
          const SizedBox(width: 12),
          Expanded(child: fields[2]),
        ],
      );
    }
    return Column(
      children: [
        fields[0],
        const SizedBox(height: 14),
        fields[1],
        const SizedBox(height: 14),
        fields[2],
      ],
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String? error,
    required bool signed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: kTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType:
              TextInputType.numberWithOptions(signed: signed, decimal: false),
          inputFormatters: signed
              ? [_SignedIntegerFormatter()]
              : [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kTextFaint, fontSize: 13),
            filled: true,
            fillColor: kBg2.withOpacity(0.6),
            errorText: error,
            errorStyle: const TextStyle(color: kDanger, fontSize: 12),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kIndigo, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDanger, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDanger, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 12,
      children: [
        TapScale(
          onTap: _clear,
          child: _pillButton(
            label: 'Limpiar',
            icon: Icons.refresh_rounded,
            filled: false,
          ),
        ),
        TapScale(
          onTap: _loadExample,
          child: _pillButton(
            label: 'Ejemplo rápido',
            icon: Icons.bolt_rounded,
            filled: false,
            color: kEmerald,
          ),
        ),
        TapScale(
          onTap: _calculate,
          child: _pillButton(
            label: 'Calcular',
            icon: Icons.arrow_forward_rounded,
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required bool filled,
    Color color = kIndigo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        gradient: filled
            ? LinearGradient(colors: [color, kViolet])
            : null,
        color: filled ? null : kSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: filled ? null : Border.all(color: color.withOpacity(0.5)),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: filled ? Colors.white : color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHint({Key? key}) {
    return GlassCard(
      key: key,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.calculate_outlined, color: kTextFaint, size: 32),
          const SizedBox(height: 12),
          Text(
            'Ingresa a, b y n para ver el desglose paso a paso\n(Modo Cuaderno) y el veredicto de singularidad.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(CalcResult result, {Key? key}) {
    final singular = result.singular;
    final accent = singular ? kDanger : kEmerald;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Veredicto
        GlassCard(
          tint: accent.withOpacity(0.12),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 480),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.5)),
                  ),
                  child: Icon(
                    singular
                        ? Icons.cancel_rounded
                        : Icons.check_circle_rounded,
                    color: accent,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      singular
                          ? 'CURVA SINGULAR'
                          : 'CURVA NO SINGULAR',
                      style: TextStyle(
                        color: accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${singular ? '(no válida)' : '(válida)'} · ${result.verdictSubtitle}',
                      style: TextStyle(
                        color: kTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.justification,
                      style: const TextStyle(
                          color: kTextPrimary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'MODO CUADERNO — PROCEDIMIENTO',
          style: TextStyle(
            color: kTextFaint,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(result.steps.length, (i) {
          final step = result.steps[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [kIndigo, kViolet]),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          step.content,
                          style: const TextStyle(
                            color: kTextPrimary,
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
