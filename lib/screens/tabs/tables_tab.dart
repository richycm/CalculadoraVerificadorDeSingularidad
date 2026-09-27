import 'package:flutter/material.dart';
import '../../math/ec_math.dart';
import '../../main.dart';

class TablesTab extends StatefulWidget {
  final EllipticCurve? curve;
  final List<ECPoint>? points;
  final bool isSingular;

  const TablesTab({super.key, this.curve, this.points, required this.isSingular});

  @override
  State<TablesTab> createState() => _TablesTabState();
}

class _TablesTabState extends State<TablesTab> {
  bool _showMul = false;

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
                child: const Icon(Icons.grid_on_rounded, color: kTextFaint, size: 40),
              ),
              const SizedBox(height: 18),
              const Text("Curva no calculada o singular.", style: TextStyle(color: kTextSecondary, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    if (widget.points!.length > 50) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_chart_outlined, size: 56, color: kTextFaint),
              const SizedBox(height: 16),
              Text(
                "La cardinalidad es ${widget.points!.length}.",
                style: const TextStyle(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                "La tabla no se muestra por encima de 50 puntos para evitar congelar la aplicación.",
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: const Text("Suma (P + Q)"),
                selected: !_showMul,
                onSelected: (v) => setState(() => _showMul = false),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.close_rounded, size: 16),
                label: const Text("Escalar (k · P)"),
                selected: _showMul,
                onSelected: (v) => setState(() => _showMul = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusMd),
                border: Border.all(color: kBorderSoft),
                boxShadow: glowShadow(_showMul ? kIndigo : kEmerald),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _showMul
                        ? KeyedSubtree(key: const ValueKey('mul'), child: _buildMulTable())
                        : KeyedSubtree(key: const ValueKey('add'), child: _buildAddTable()),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAddTable() {
    final pts = widget.points!;
    return DataTable(
      headingRowColor: WidgetStateProperty.all(kSurfaceHi),
      dataRowColor: WidgetStateProperty.all(kSurface),
      headingTextStyle: const TextStyle(fontFamily: kMonoFont, fontWeight: FontWeight.w700, color: kViolet, fontSize: 12),
      dataTextStyle: const TextStyle(fontFamily: kMonoFont, color: kTextSecondary, fontSize: 12),
      border: TableBorder.all(color: kBorder, borderRadius: BorderRadius.circular(kRadiusMd)),
      columnSpacing: 20,
      columns: [
        const DataColumn(label: Text('+')),
        ...pts.map((p) => DataColumn(label: Text(p.toString()))),
      ],
      rows: pts.map((p1) {
        return DataRow(
          cells: [
            DataCell(Text(p1.toString(), style: const TextStyle(fontWeight: FontWeight.w800, color: kIndigo))),
            ...pts.map((p2) {
              return DataCell(Text(widget.curve!.add(p1, p2).toString()));
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMulTable() {
    final pts = widget.points!;
    final card = pts.length;
    return DataTable(
      headingRowColor: WidgetStateProperty.all(kSurfaceHi),
      dataRowColor: WidgetStateProperty.all(kSurface),
      headingTextStyle: const TextStyle(fontFamily: kMonoFont, fontWeight: FontWeight.w700, color: kViolet, fontSize: 12),
      dataTextStyle: const TextStyle(fontFamily: kMonoFont, color: kTextSecondary, fontSize: 12),
      border: TableBorder.all(color: kBorder, borderRadius: BorderRadius.circular(kRadiusMd)),
      columnSpacing: 20,
      columns: [
        const DataColumn(label: Text('k \\ P')),
        ...pts.map((p) => DataColumn(label: Text(p.toString()))),
      ],
      rows: List.generate(card, (k) {
        final kVal = BigInt.from(k + 1);
        return DataRow(
          cells: [
            DataCell(Text(kVal.toString(), style: const TextStyle(fontWeight: FontWeight.w800, color: kIndigo))),
            ...pts.map((p) {
              return DataCell(Text(widget.curve!.multiply(kVal, p).toString()));
            }),
          ],
        );
      }),
    );
  }
}
