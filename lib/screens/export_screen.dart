import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../export/pdf_export.dart';
import '../main.dart';
import '../math/ec_math.dart';

/// Abre el diálogo de exportación y, si se confirma, la vista previa del PDF.
Future<void> showPdfExportDialog(
  BuildContext context, {
  required EllipticCurve curve,
  required List<ECPoint>? points,
  required bool isSingular,
}) async {
  final List<ECPoint> pts = points ?? const [];
  final bool tablesFit = !isSingular && pts.isNotEmpty && pts.length <= kMaxPdfTableSize;
  final bool hasGroup = !isSingular && pts.isNotEmpty;

  PdfSections sections = PdfSections(
    puntos: hasGroup,
    ordenes: hasGroup,
    tablaSuma: tablesFit && pts.length <= 24,
    tablaEscalar: false,
  );

  final PdfSections? chosen = await showDialog<PdfSections>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setLocal) {
          Widget option({
            required String title,
            required String subtitle,
            required bool value,
            required bool enabled,
            required ValueChanged<bool> onChanged,
          }) {
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: value,
              onChanged: enabled ? (v) => setLocal(() => onChanged(v ?? false)) : null,
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: enabled ? kTextPrimary : kTextFaint,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: enabled ? kTextSecondary : kTextFaint),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: kSurfaceAlt,
            title: const Row(
              children: [
                Icon(Icons.picture_as_pdf_rounded, color: kDanger, size: 20),
                SizedBox(width: 10),
                Text('Exportar a PDF', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'y² ≡ x³ + ${curve.a}x + ${curve.b}  (mod ${curve.p})',
                    style: const TextStyle(fontFamily: kMonoFont, fontSize: 13, color: kViolet),
                  ),
                  const SizedBox(height: 12),
                  option(
                    title: 'Resumen',
                    subtitle: 'a, b, p, discriminante, singularidad, cardinalidad y Hasse',
                    value: sections.resumen,
                    enabled: true,
                    onChanged: (v) => sections = sections.copyWith(resumen: v),
                  ),
                  option(
                    title: 'Lista de puntos',
                    subtitle: hasGroup
                        ? '${pts.length} puntos, incluyendo 𝒪'
                        : 'No disponible en una curva singular',
                    value: sections.puntos,
                    enabled: hasGroup,
                    onChanged: (v) => sections = sections.copyWith(puntos: v),
                  ),
                  option(
                    title: 'Órdenes y generadores',
                    subtitle: hasGroup
                        ? 'Orden de cada punto y si genera el grupo'
                        : 'No disponible en una curva singular',
                    value: sections.ordenes,
                    enabled: hasGroup,
                    onChanged: (v) => sections = sections.copyWith(ordenes: v),
                  ),
                  option(
                    title: 'Tabla de suma (P + Q)',
                    subtitle: tablesFit
                        ? '${pts.length} × ${pts.length} celdas, en bloques de 14 columnas'
                        : 'Solo hasta $kMaxPdfTableSize puntos (esta curva tiene ${pts.length})',
                    value: sections.tablaSuma,
                    enabled: tablesFit,
                    onChanged: (v) => sections = sections.copyWith(tablaSuma: v),
                  ),
                  option(
                    title: 'Tabla escalar (k · P)',
                    subtitle: tablesFit
                        ? '${pts.length} × ${pts.length} celdas, en bloques de 14 columnas'
                        : 'Solo hasta $kMaxPdfTableSize puntos (esta curva tiene ${pts.length})',
                    value: sections.tablaEscalar,
                    enabled: tablesFit,
                    onChanged: (v) => sections = sections.copyWith(tablaEscalar: v),
                  ),
                  if (tablesFit && (sections.tablaSuma || sections.tablaEscalar)) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: kAmber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Las tablas pueden ocupar varias páginas horizontales.',
                            style: TextStyle(fontSize: 11, color: kAmber.withValues(alpha: 0.9)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: sections.isEmpty ? null : () => Navigator.pop(dialogContext, sections),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('Generar'),
              ),
            ],
          );
        },
      );
    },
  );

  if (chosen == null || !context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PdfExportScreen(
        curve: curve,
        points: pts,
        isSingular: isSingular,
        sections: chosen,
      ),
    ),
  );
}

/// Función de nivel superior para `compute`: los órdenes son lo más costoso.
List<PointOrder> _ordersInIsolate(Map<String, dynamic> data) {
  final EllipticCurve curve = data['curve'];
  final List<ECPoint> points = data['points'];
  return computePointOrders(curve, points);
}

class PdfExportScreen extends StatefulWidget {
  final EllipticCurve curve;
  final List<ECPoint> points;
  final bool isSingular;
  final PdfSections sections;

  const PdfExportScreen({
    super.key,
    required this.curve,
    required this.points,
    required this.isSingular,
    required this.sections,
  });

  @override
  State<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends State<PdfExportScreen> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      List<PointOrder> orders = const [];
      final bool needsOrders =
          widget.sections.ordenes || widget.sections.resumen; // el resumen informa si es cíclico
      if (needsOrders && !widget.isSingular && widget.points.isNotEmpty) {
        orders = await compute(_ordersInIsolate, {
          'curve': widget.curve,
          'points': widget.points,
        });
      }

      final Uint8List bytes = await buildCurvePdf(
        report: CurveReport(
          curve: widget.curve,
          isSingular: widget.isSingular,
          points: widget.points,
          orders: orders,
        ),
        sections: widget.sections,
      );

      if (!mounted) return;
      setState(() => _bytes = bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  String get _fileName =>
      'curva_a${widget.curve.a}_b${widget.curve.b}_p${widget.curve.p}.pdf';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kSurfaceAlt,
        title: const Text('Vista previa del PDF',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: kDanger, size: 44),
                    const SizedBox(height: 16),
                    const Text('No se pudo generar el PDF',
                        style: TextStyle(color: kDanger, fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                  ],
                ),
              ),
            )
          : _bytes == null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: kIndigo),
                      SizedBox(height: 16),
                      Text('Generando documento…', style: TextStyle(color: kTextSecondary)),
                    ],
                  ),
                )
              : PdfPreview(
                  build: (format) => _bytes!,
                  pdfFileName: _fileName,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: true,
                  allowSharing: true,
                  initialPageFormat: PdfPageFormat.a4,
                  loadingWidget: const CircularProgressIndicator(color: kIndigo),
                ),
    );
  }
}
