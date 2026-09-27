import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for compute
import '../math/ec_math.dart';
import 'tabs/general_tab.dart';
import 'tabs/calculator_tab.dart';
import 'tabs/tables_tab.dart';
import 'tabs/generators_tab.dart';
import '../main.dart'; // for colors

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _aCtrl = TextEditingController(text: '2');
  final _bCtrl = TextEditingController(text: '3');
  final _pCtrl = TextEditingController(text: '17');

  String? _errorA, _errorB, _errorP;
  
  bool _isLoading = false;
  
  EllipticCurve? _curve;
  List<ECPoint>? _points;
  bool _isSingular = false;
  String _statusMessage = "Ingresa a, b y p para calcular.";
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aCtrl.dispose();
    _bCtrl.dispose();
    _pCtrl.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    setState(() {
      _errorA = _errorB = _errorP = null;
      _isLoading = true;
      _curve = null;
      _points = null;
    });

    final aStr = _aCtrl.text.trim();
    final bStr = _bCtrl.text.trim();
    final pStr = _pCtrl.text.trim();

    if (aStr.isEmpty) _errorA = 'Requerido';
    if (bStr.isEmpty) _errorB = 'Requerido';
    if (pStr.isEmpty) _errorP = 'Requerido';

    if (_errorA != null || _errorB != null || _errorP != null) {
      setState(() => _isLoading = false);
      return;
    }

    final a = BigInt.tryParse(aStr);
    final b = BigInt.tryParse(bStr);
    final p = BigInt.tryParse(pStr);

    if (a == null) _errorA = 'Inválido';
    if (b == null) _errorB = 'Inválido';
    if (p == null) _errorP = 'Inválido';

    if (a == null || b == null || p == null) {
      setState(() => _isLoading = false);
      return;
    }

    if (p <= BigInt.from(3)) {
      setState(() {
        _errorP = 'p debe ser > 3';
        _isLoading = false;
      });
      return;
    }

    // Correr validación en background para no bloquear UI
    try {
      final result = await compute(_processCurve, {'a': a, 'b': b, 'p': p});
      
      setState(() {
        if (result.error != null) {
          _statusMessage = result.error!;
        } else {
          _curve = result.curve;
          _isSingular = result.isSingular;
          _points = result.points;
          if (_isSingular) {
            _statusMessage = "CURVA SINGULAR: Discriminante ≡ 0 (mod p)";
          } else {
            _statusMessage = "Curva válida sobre 𝔽_p";
            _aCtrl.text = _curve!.a.toString(); // Update with reduced a
            _bCtrl.text = _curve!.b.toString(); // Update with reduced b
          }
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error: $e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: kGradientHeader,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.timeline_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Curvas Elípticas',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, height: 1.1),
                ),
                Text(
                  'y² ≡ x³ + ax + b (mod p)',
                  style: TextStyle(fontSize: 11, color: kTextFaint, height: 1.1),
                ),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: kIndigo,
              indicatorWeight: 3,
              labelColor: kTextPrimary,
              unselectedLabelColor: kTextFaint,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.info_outline_rounded, size: 18), text: 'General'),
                Tab(icon: Icon(Icons.calculate_outlined, size: 18), text: 'Calculadora'),
                Tab(icon: Icon(Icons.grid_on_rounded, size: 18), text: 'Tablas'),
                Tab(icon: Icon(Icons.hub_outlined, size: 18), text: 'Generadores'),
              ],
            ),
          ),
        ),
      ),
      body: AppBackdrop(
        child: Column(
        children: [
          _buildInputSection(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: kIndigo),
                        SizedBox(height: 16),
                        Text('Calculando…', style: TextStyle(color: kTextSecondary)),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      GeneralTab(
                        curve: _curve,
                        points: _points,
                        isSingular: _isSingular,
                        statusMessage: _statusMessage,
                      ),
                      CalculatorTab(curve: _curve, points: _points, isSingular: _isSingular),
                      TablesTab(curve: _curve, points: _points, isSingular: _isSingular),
                      GeneratorsTab(curve: _curve, points: _points, isSingular: _isSingular),
                    ],
                  ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildInputSection() {
    final eqA = _aCtrl.text.isEmpty ? 'a' : _aCtrl.text;
    final eqB = _bCtrl.text.isEmpty ? 'b' : _bCtrl.text;
    final eqP = _pCtrl.text.isEmpty ? 'p' : _pCtrl.text;

    final accent = _isSingular ? kDanger : (_curve != null ? kEmerald : kViolet);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        border: const Border(bottom: BorderSide(color: kBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kBg2,
              borderRadius: BorderRadius.circular(kRadiusSm),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: glowShadow(accent, blur: 22, alpha: 0.14),
            ),
            child: Row(
              children: [
                Icon(
                  _isSingular ? Icons.warning_amber_rounded : Icons.functions_rounded,
                  size: 16,
                  color: accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'y² ≡ x³ + $eqA·x + $eqB   (mod $eqP)',
                    style: TextStyle(
                      fontFamily: kMonoFont,
                      color: accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 480;
              final fields = [
                Expanded(child: _buildField(label: 'a', ctrl: _aCtrl, error: _errorA)),
                const SizedBox(width: 10),
                Expanded(child: _buildField(label: 'b', ctrl: _bCtrl, error: _errorB)),
                const SizedBox(width: 10),
                Expanded(child: _buildField(label: 'p (primo)', ctrl: _pCtrl, error: _errorP, signed: false)),
              ];
              final button = SizedBox(
                width: narrow ? double.infinity : null,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _calculate,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Calcular'),
                ),
              );

              if (narrow) {
                return Column(
                  children: [
                    Row(children: fields),
                    const SizedBox(height: 12),
                    button,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...fields,
                  const SizedBox(width: 14),
                  button,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField({required String label, required TextEditingController ctrl, String? error, bool signed = true}) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontFamily: kMonoFont, fontWeight: FontWeight.w600),
      keyboardType: TextInputType.numberWithOptions(signed: signed),
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
      ),
    );
  }
}

class CurveProcessResult {
  final EllipticCurve? curve;
  final bool isSingular;
  final List<ECPoint>? points;
  final String? error;

  CurveProcessResult({this.curve, this.isSingular = false, this.points, this.error});
}

// Top-level function for compute()
CurveProcessResult _processCurve(Map<String, BigInt> data) {
  final a = data['a']!;
  final b = data['b']!;
  final p = data['p']!;

  if (!isPrime(p)) {
    return CurveProcessResult(error: "El valor p=$p NO es primo.");
  }

  try {
    final curve = EllipticCurve(a: a, b: b, p: p);
    final isSing = curve.isSingular();
    List<ECPoint>? pts;
    
    if (!isSing) {
      if (p <= BigInt.from(1000)) {
        pts = curve.getPoints();
      } else {
        return CurveProcessResult(error: "p es primo, pero muy grande para calcular todos los puntos (> 1000).", curve: curve);
      }
    }
    return CurveProcessResult(curve: curve, isSingular: isSing, points: pts);
  } catch (e) {
    return CurveProcessResult(error: e.toString());
  }
}
