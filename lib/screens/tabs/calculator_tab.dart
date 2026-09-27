import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../math/ec_math.dart';
import '../../main.dart';

class CalculatorTab extends StatefulWidget {
  final EllipticCurve? curve;
  final List<ECPoint>? points;
  final bool isSingular;

  const CalculatorTab({super.key, this.curve, this.points, required this.isSingular});

  @override
  State<CalculatorTab> createState() => _CalculatorTabState();
}

class _CalculatorTabState extends State<CalculatorTab> {
  ECPoint? _p1;
  ECPoint? _p2;
  String _kStr = "2";
  
  String _addResult = "";
  String _mulResult = "";

  late final _kCtrl = TextEditingController(text: _kStr);

  @override
  void dispose() {
    _kCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSingular || widget.curve == null || widget.points == null) {
      return const _CalcEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            icon: Icons.add_circle_outline_rounded,
            title: "Suma de puntos",
            subtitle: "P + Q",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPointSelector("Punto P", _p1, (pt) => setState(() => _p1 = pt))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("+", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextFaint)),
                    ),
                    Expanded(child: _buildPointSelector("Punto Q", _p2, (pt) => setState(() => _p2 = pt))),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_p1 != null && _p2 != null)
                        ? () => setState(() => _addResult = widget.curve!.add(_p1!, _p2!).toString())
                        : null,
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('Calcular P + Q'),
                  ),
                ),
                _AnimatedResult(value: _addResult),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            icon: Icons.close_rounded,
            title: "Multiplicación escalar",
            subtitle: "k · P (double-and-add)",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        onChanged: (v) => _kStr = v,
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        style: const TextStyle(fontFamily: kMonoFont, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(labelText: "Escalar k"),
                        controller: _kCtrl,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text("·", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextFaint)),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildPointSelector("Punto P", _p1, (pt) => setState(() => _p1 = pt)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _p1 != null
                        ? () {
                            final k = BigInt.tryParse(_kStr);
                            if (k != null) {
                              setState(() => _mulResult = widget.curve!.multiply(k, _p1!).toString());
                            }
                          }
                        : null,
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: const Text('Calcular k · P'),
                  ),
                ),
                _AnimatedResult(value: _mulResult),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointSelector(String label, ECPoint? currentVal, ValueChanged<ECPoint> onSelected) {
    return InkWell(
      borderRadius: BorderRadius.circular(kRadiusSm),
      onTap: () => _showPointPicker(onSelected),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                currentVal?.toString() ?? "Elegir",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kMonoFont,
                  fontWeight: FontWeight.w600,
                  color: currentVal == null ? kTextFaint : kTextPrimary,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: kTextSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  void _showPointPicker(ValueChanged<ECPoint> onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusLg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Selecciona un punto  ·  ${widget.points!.length} disponibles",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.points!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
                  itemBuilder: (context, index) {
                    final pt = widget.points![index];
                    return ListTile(
                      title: Text(pt.toString(), style: const TextStyle(fontFamily: kMonoFont, fontWeight: FontWeight.w600)),
                      onTap: () {
                        onSelected(pt);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({required this.icon, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorderSoft),
        boxShadow: glowShadow(kIndigo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kIndigo.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: kIndigo, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
              const SizedBox(width: 8),
              Text(subtitle, style: const TextStyle(fontSize: 12, fontFamily: kMonoFont, color: kTextFaint)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AnimatedResult extends StatelessWidget {
  final String value;

  const _AnimatedResult({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(anim), child: child),
      ),
      child: value.isEmpty
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : Padding(
              key: ValueKey(value),
              padding: const EdgeInsets.only(top: 14),
              child: _ResultBox(label: "Resultado", value: value),
            ),
    );
  }
}

class _ResultBox extends StatelessWidget {
  final String label;
  final String value;

  const _ResultBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kEmerald.withValues(alpha: 0.08),
        border: Border.all(color: kEmerald.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(kRadiusSm),
        boxShadow: glowShadow(kEmerald, alpha: 0.12),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: kEmerald, size: 18),
          const SizedBox(width: 10),
          Text("$label:  ", style: const TextStyle(color: kTextSecondary, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: kEmerald, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: kMonoFont),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16, color: kTextFaint),
            tooltip: 'Copiar',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Resultado copiado'), duration: Duration(seconds: 1), backgroundColor: kSurfaceHi),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CalcEmptyState extends StatelessWidget {
  const _CalcEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [kIndigo.withValues(alpha: 0.16), kIndigo.withValues(alpha: 0.0)]),
              ),
              child: const Icon(Icons.calculate_outlined, color: kTextFaint, size: 40),
            ),
            const SizedBox(height: 18),
            const Text("Calcula una curva válida y no singular\npara usar la calculadora.",
                textAlign: TextAlign.center, style: TextStyle(color: kTextSecondary, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
