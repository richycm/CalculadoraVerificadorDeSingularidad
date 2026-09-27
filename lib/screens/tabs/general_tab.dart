import 'package:flutter/material.dart';
import '../../math/ec_math.dart';
import '../../main.dart';
import 'dart:math';

class GeneralTab extends StatelessWidget {
  final EllipticCurve? curve;
  final List<ECPoint>? points;
  final bool isSingular;
  final String statusMessage;

  const GeneralTab({super.key, this.curve, this.points, required this.isSingular, required this.statusMessage});

  @override
  Widget build(BuildContext context) {
    if (curve == null && points == null) {
      return _EmptyState(
        icon: Icons.functions_rounded,
        message: statusMessage,
        isError: statusMessage.contains('Error') || statusMessage.contains('NO'),
      );
    }

    if (isSingular) {
      return _EmptyState(
        icon: Icons.warning_amber_rounded,
        message: statusMessage,
        isError: true,
      );
    }

    BigInt p = curve!.p;
    BigInt pPlus1 = p + BigInt.one;
    int hasseBound = (2 * sqrt(p.toDouble())).floor();
    int diff = (points!.length - pPlus1.toInt()).abs();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _InfoCard(
                icon: Icons.functions_rounded,
                title: "Curva reducida",
                accent: kViolet,
                child: Text(
                  "y² ≡ x³ + ${curve!.a}x + ${curve!.b}  (mod ${curve!.p})",
                  style: const TextStyle(fontFamily: kMonoFont, color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.scatter_plot_rounded,
                      title: "Cardinalidad #E(𝔽p)",
                      accent: kEmerald,
                      footer: "puntos, incluyendo 𝒪",
                      child: _CountUp(
                        value: points!.length,
                        style: const TextStyle(color: kEmerald, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoCard(
                      icon: Icons.verified_outlined,
                      title: "Teorema de Hasse",
                      accent: kIndigo,
                      footer: "|#E − (p+1)| ≤ 2√p",
                      child: Text(
                        "$diff ≤ $hasseBound",
                        style: TextStyle(
                          color: diff <= hasseBound ? kEmerald : kDanger,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _CurvePlot(p: curve!.p, points: points!),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 18, color: kTextFaint),
                  const SizedBox(width: 8),
                  const Text("Puntos de la curva", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: kSurfaceHi,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text("${points!.length}", style: const TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ]),
          ),
        ),
        if (points != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisExtent: 42,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final isInf = points![index].isInfinity;
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isInf ? kIndigo.withValues(alpha: 0.12) : kSurface,
                      border: Border.all(color: isInf ? kIndigo.withValues(alpha: 0.5) : kBorder),
                      borderRadius: BorderRadius.circular(kRadiusSm),
                    ),
                    child: Text(
                      points![index].toString(),
                      style: TextStyle(
                        fontFamily: kMonoFont,
                        fontSize: 13,
                        fontWeight: isInf ? FontWeight.w700 : FontWeight.w500,
                        color: isInf ? kViolet : kTextSecondary,
                      ),
                    ),
                  );
                },
                childCount: points!.length,
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  final Widget child;
  final String? footer;

  const _InfoCard({required this.icon, required this.title, required this.accent, required this.child, this.footer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorderSoft),
        boxShadow: glowShadow(accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: kTextFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
          if (footer != null) ...[
            const SizedBox(height: 4),
            Text(footer!, style: const TextStyle(color: kTextFaint, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isError;

  const _EmptyState({required this.icon, required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final color = isError ? kDanger : kIndigo;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
                ),
              ),
              child: Icon(icon, color: color, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: isError ? kDanger : kTextPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (!isError) ...[
              const SizedBox(height: 10),
              const Text(
                "Ingresa a, b y p en la parte superior, luego pulsa Calcular.",
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextFaint, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  final int value;
  final TextStyle style;

  const _CountUp({required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) => Text("$val", style: style),
    );
  }
}

class _CurvePlot extends StatelessWidget {
  final BigInt p;
  final List<ECPoint> points;

  const _CurvePlot({required this.p, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceAlt,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorderSoft),
        boxShadow: glowShadow(kViolet),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bubble_chart_rounded, size: 14, color: kViolet),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Distribución en 𝔽$p × 𝔽$p",
                  style: const TextStyle(color: kTextFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 1.4,
              child: CustomPaint(
                painter: _CurvePlotPainter(p: p, points: points),
                child: Container(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: kEmerald, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text("puntos afines", style: TextStyle(color: kTextFaint, fontSize: 11)),
              const Spacer(),
              const Text("(0,0)", style: TextStyle(color: kTextFaint, fontSize: 11, fontFamily: kMonoFont)),
              const SizedBox(width: 12),
              const Text("(p−1,p−1)", style: TextStyle(color: kTextFaint, fontSize: 11, fontFamily: kMonoFont)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurvePlotPainter extends CustomPainter {
  final BigInt p;
  final List<ECPoint> points;

  _CurvePlotPainter({required this.p, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = kBg2;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final gridPaint = Paint()
      ..color = kBorder
      ..strokeWidth = 1;
    const divisions = 4;
    for (int i = 1; i < divisions; i++) {
      final tx = size.width * i / divisions;
      final ty = size.height * i / divisions;
      canvas.drawLine(Offset(tx, 0), Offset(tx, size.height), gridPaint);
      canvas.drawLine(Offset(0, ty), Offset(size.width, ty), gridPaint);
    }

    final pDouble = p.toDouble();
    final finitePoints = points.where((pt) => !pt.isInfinity).toList();
    final radius = finitePoints.length > 300 ? 1.1 : (finitePoints.length > 100 ? 1.6 : 2.4);
    final dotPaint = Paint()..color = kEmerald;

    for (final pt in finitePoints) {
      final x = (pt.x!.toDouble() / pDouble) * size.width;
      final y = size.height - (pt.y!.toDouble() / pDouble) * size.height;
      canvas.drawCircle(Offset(x, y), radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePlotPainter oldDelegate) {
    return oldDelegate.p != p || oldDelegate.points.length != points.length;
  }
}
