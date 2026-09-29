import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../math/ec_math.dart';
import '../../main.dart';

/// A partir de este número de puntos la tabla se pide explícitamente y se
/// dibuja con el renderizador virtualizado.
const int kTablePreviewLimit = 50;

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
  bool _showFullTable = false;

  @override
  void didUpdateWidget(covariant TablesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Curva nueva: volver a pedir confirmación antes de dibujar una tabla enorme.
    if (oldWidget.points != widget.points) {
      _showFullTable = false;
    }
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
                child: const Icon(Icons.grid_on_rounded, color: kTextFaint, size: 40),
              ),
              const SizedBox(height: 18),
              const Text("Curva no calculada o singular.", style: TextStyle(color: kTextSecondary, fontSize: 15)),
            ],
          ),
        ),
      );
    }

    final List<ECPoint> pts = widget.points!;
    final bool isBig = pts.length > kTablePreviewLimit;

    if (isBig && !_showFullTable) {
      return _BigTableNotice(
        count: pts.length,
        onShow: () => setState(() => _showFullTable = true),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
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
              if (isBig)
                IconButton(
                  tooltip: 'Ocultar tabla completa',
                  icon: const Icon(Icons.visibility_off_outlined, size: 20, color: kTextFaint),
                  onPressed: () => setState(() => _showFullTable = false),
                ),
            ],
          ),
        ),
        if (isBig)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: kTextFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${pts.length} × ${pts.length} = ${pts.length * pts.length} celdas · se dibujan solo las visibles",
                    style: const TextStyle(color: kTextFaint, fontSize: 11),
                  ),
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
              child: isBig ? _buildVirtualTable(pts) : _buildSmallTable(),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Tabla virtualizada: encabezados fijos y solo las celdas visibles en memoria.
  Widget _buildVirtualTable(List<ECPoint> pts) {
    final EllipticCurve curve = widget.curve!;
    final int digits = curve.p.toString().length;
    final double cellWidth = math.max(64.0, 26.0 + 2 * digits * 8.0);

    return _VirtualTable(
      key: ValueKey('${_showMul ? 'mul' : 'add'}-${pts.length}-${curve.p}'),
      count: pts.length,
      cellWidth: cellWidth,
      cornerLabel: _showMul ? 'k \\ P' : '+',
      colHeader: (c) => pts[c].toString(),
      rowHeader: (r) => _showMul ? '${r + 1}' : pts[r].toString(),
      cell: (r, c) => _showMul
          ? curve.multiply(BigInt.from(r + 1), pts[c]).toString()
          : curve.add(pts[r], pts[c]).toString(),
    );
  }

  Widget _buildSmallTable() {
    return SingleChildScrollView(
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

class _BigTableNotice extends StatelessWidget {
  final int count;
  final VoidCallback onShow;

  const _BigTableNotice({required this.count, required this.onShow});

  @override
  Widget build(BuildContext context) {
    final int cells = count * count;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_chart_outlined, size: 56, color: kTextFaint),
            const SizedBox(height: 16),
            Text(
              "La cardinalidad es $count.",
              style: const TextStyle(color: kTextPrimary, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              "La tabla completa tiene $count × $count = $cells celdas.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onShow,
              icon: const Icon(Icons.grid_on_rounded, size: 18),
              label: const Text('Mostrar tabla completa'),
            ),
            const SizedBox(height: 10),
            const Text(
              "Se dibujan únicamente las celdas visibles, así que el\ndesplazamiento sigue siendo fluido.",
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextFaint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tabla con encabezados congelados que solo construye las celdas visibles.
///
/// La fila y la columna de encabezados quedan fijas; el cuerpo se desplaza en
/// ambos ejes. En cada fila se construyen únicamente las columnas dentro del
/// viewport, de modo que el coste por frame no depende de `count`.
class _VirtualTable extends StatefulWidget {
  final int count;
  final double cellWidth;
  final String cornerLabel;
  final String Function(int col) colHeader;
  final String Function(int row) rowHeader;
  final String Function(int row, int col) cell;

  const _VirtualTable({
    super.key,
    required this.count,
    required this.cellWidth,
    required this.cornerLabel,
    required this.colHeader,
    required this.rowHeader,
    required this.cell,
  });

  @override
  State<_VirtualTable> createState() => _VirtualTableState();
}

class _VirtualTableState extends State<_VirtualTable> {
  static const double _rowHeight = 34;

  final ScrollController _h = ScrollController();
  final ScrollController _vBody = ScrollController();
  final ScrollController _vHeader = ScrollController();

  @override
  void dispose() {
    _h.dispose();
    _vBody.dispose();
    _vHeader.dispose();
    super.dispose();
  }

  /// Mantiene la columna de encabezados alineada con el cuerpo.
  bool _syncVertical(ScrollNotification n) {
    if (n.metrics.axis == Axis.vertical && _vHeader.hasClients) {
      final double target = n.metrics.pixels.clamp(
        _vHeader.position.minScrollExtent,
        _vHeader.position.maxScrollExtent,
      );
      if (_vHeader.offset != target) _vHeader.jumpTo(target);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final double cw = widget.cellWidth;

    return Row(
      // `stretch` da altura ajustada a ambas columnas, que es lo que necesitan
      // los `Expanded` de dentro.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Columna de encabezados, congelada horizontalmente.
        SizedBox(
          width: cw,
          child: Column(
            children: [
              _HeaderCell(text: widget.cornerLabel, width: cw, height: _rowHeight, isCorner: true),
              Expanded(
                child: ListView.builder(
                  controller: _vHeader,
                  physics: const NeverScrollableScrollPhysics(),
                  itemExtent: _rowHeight,
                  itemCount: widget.count,
                  itemBuilder: (context, r) => _HeaderCell(
                    text: widget.rowHeader(r),
                    width: cw,
                    height: _rowHeight,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double viewportW = constraints.maxWidth;
              return Scrollbar(
                controller: _h,
                thumbVisibility: true,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _h,
                  child: SizedBox(
                    width: cw * widget.count,
                    child: AnimatedBuilder(
                      animation: _h,
                      builder: (context, _) {
                        final double offset = _h.hasClients ? _h.offset : 0.0;
                        // Rango visible con un par de columnas de margen.
                        final int first = ((offset / cw).floor() - 1).clamp(0, math.max(0, widget.count - 1));
                        final int last =
                            (((offset + viewportW) / cw).ceil() + 1).clamp(0, widget.count);
                        final double leadingGap = first * cw;

                        return Column(
                          children: [
                            // Fila de encabezados, congelada verticalmente.
                            SizedBox(
                              height: _rowHeight,
                              child: Row(
                                children: [
                                  SizedBox(width: leadingGap),
                                  for (int c = first; c < last; c++)
                                    _HeaderCell(text: widget.colHeader(c), width: cw, height: _rowHeight),
                                ],
                              ),
                            ),
                            Expanded(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: _syncVertical,
                                child: Scrollbar(
                                  controller: _vBody,
                                  thumbVisibility: true,
                                  notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
                                  child: ListView.builder(
                                    controller: _vBody,
                                    itemExtent: _rowHeight,
                                    itemCount: widget.count,
                                    itemBuilder: (context, r) => Row(
                                      children: [
                                        SizedBox(width: leadingGap),
                                        for (int c = first; c < last; c++)
                                          _BodyCell(
                                            text: widget.cell(r, c),
                                            width: cw,
                                            height: _rowHeight,
                                            shaded: r.isOdd,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final bool isCorner;

  const _HeaderCell({required this.text, required this.width, required this.height, this.isCorner = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: kSurfaceHi,
        border: Border(
          right: BorderSide(color: kBorder, width: 0.5),
          bottom: BorderSide(color: kBorder, width: 0.5),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: kMonoFont,
          fontWeight: FontWeight.w700,
          color: isCorner ? kTextPrimary : kViolet,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final double width;
  final double height;
  final bool shaded;

  const _BodyCell({required this.text, required this.width, required this.height, required this.shaded});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: shaded ? kSurfaceAlt : kSurface,
        border: const Border(
          right: BorderSide(color: kBorder, width: 0.5),
          bottom: BorderSide(color: kBorder, width: 0.5),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: kMonoFont, color: kTextSecondary, fontSize: 11),
      ),
    );
  }
}
