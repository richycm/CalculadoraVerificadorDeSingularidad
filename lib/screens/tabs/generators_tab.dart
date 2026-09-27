import 'package:flutter/material.dart';
import '../../math/ec_math.dart';
import '../../main.dart';
import 'package:flutter/foundation.dart';

class GeneratorsTab extends StatefulWidget {
  final EllipticCurve? curve;
  final List<ECPoint>? points;
  final bool isSingular;

  const GeneratorsTab({super.key, this.curve, this.points, required this.isSingular});

  @override
  State<GeneratorsTab> createState() => _GeneratorsTabState();
}

class _GeneratorsTabState extends State<GeneratorsTab> {
  List<PointOrder>? _pointOrders;
  bool _isLoading = false;
  bool _isCyclic = false;

  @override
  void initState() {
    super.initState();
    _calculateOrders();
  }

  @override
  void didUpdateWidget(covariant GeneratorsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.curve != widget.curve) {
      _calculateOrders();
    }
  }

  Future<void> _calculateOrders() async {
    if (widget.isSingular || widget.curve == null || widget.points == null) return;
    
    setState(() => _isLoading = true);

    final res = await compute(_computeOrders, {
      'curve': widget.curve,
      'points': widget.points
    });

    setState(() {
      _pointOrders = res;
      _isCyclic = res.any((element) => element.isGenerator);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSingular || widget.curve == null || widget.points == null) {
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
                child: const Icon(Icons.hub_outlined, color: kTextFaint, size: 40),
              ),
              const SizedBox(height: 18),
              const Text("Curva no calculada o singular.", style: TextStyle(color: kTextSecondary, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: kIndigo),
            SizedBox(height: 16),
            Text('Calculando órdenes…', style: TextStyle(color: kTextSecondary)),
          ],
        ),
      );
    }

    if (_pointOrders == null) {
      return const SizedBox.shrink();
    }

    final generatorCount = _pointOrders!.where((p) => p.isGenerator).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isCyclic ? kEmerald.withValues(alpha: 0.08) : kDanger.withValues(alpha: 0.08),
              border: Border.all(color: (_isCyclic ? kEmerald : kDanger).withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(kRadiusMd),
              boxShadow: glowShadow(_isCyclic ? kEmerald : kDanger),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_isCyclic ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: _isCyclic ? kEmerald : kDanger),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isCyclic ? "Grupo cíclico" : "Grupo no cíclico",
                        style: TextStyle(
                          color: _isCyclic ? kEmerald : kDanger,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isCyclic
                            ? "$generatorCount de ${widget.points!.length} puntos tienen orden #E, por lo que generan todo el grupo."
                            : "Ningún punto alcanza orden #E = ${widget.points!.length}; el grupo no tiene un generador único.",
                        style: const TextStyle(color: kTextSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _pointOrders!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final po = _pointOrders![index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: po.isGenerator ? kEmerald.withValues(alpha: 0.06) : kSurfaceAlt,
                  borderRadius: BorderRadius.circular(kRadiusSm),
                  border: Border.all(color: po.isGenerator ? kEmerald.withValues(alpha: 0.35) : kBorderSoft),
                  boxShadow: po.isGenerator ? glowShadow(kEmerald, alpha: 0.12) : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: po.point.isInfinity ? kViolet : kIndigo,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        po.point.toString(),
                        style: const TextStyle(fontFamily: kMonoFont, fontWeight: FontWeight.w700, color: kTextPrimary, fontSize: 14),
                      ),
                    ),
                    Text("orden ${po.order}", style: const TextStyle(color: kTextFaint, fontSize: 12, fontFamily: kMonoFont)),
                    if (po.isGenerator) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: kEmerald, borderRadius: BorderRadius.circular(20)),
                        child: const Text("Generador", style: TextStyle(color: kBg, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PointOrder {
  final ECPoint point;
  final BigInt order;
  final bool isGenerator;
  PointOrder(this.point, this.order, this.isGenerator);
}

List<PointOrder> _computeOrders(Map<String, dynamic> data) {
  EllipticCurve curve = data['curve'];
  List<ECPoint> points = data['points'];
  BigInt card = BigInt.from(points.length);
  
  List<PointOrder> result = [];
  for (var pt in points) {
    BigInt order = curve.findOrder(pt, card);
    result.add(PointOrder(pt, order, order == card));
  }
  return result;
}
