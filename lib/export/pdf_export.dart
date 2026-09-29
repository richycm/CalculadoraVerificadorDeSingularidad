import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../math/ec_math.dart';

/// Máximo de puntos para el que se incluyen las tablas N×N en el PDF.
/// Por encima de esto el documento sería ilegible y de cientos de páginas.
const int kMaxPdfTableSize = 60;

/// Columnas por bloque al partir una tabla ancha en varios trozos.
const int _kColsPerChunk = 14;

/// Qué secciones incluir en el documento.
class PdfSections {
  final bool resumen;
  final bool puntos;
  final bool ordenes;
  final bool tablaSuma;
  final bool tablaEscalar;

  const PdfSections({
    this.resumen = true,
    this.puntos = true,
    this.ordenes = true,
    this.tablaSuma = false,
    this.tablaEscalar = false,
  });

  bool get isEmpty => !resumen && !puntos && !ordenes && !tablaSuma && !tablaEscalar;

  PdfSections copyWith({
    bool? resumen,
    bool? puntos,
    bool? ordenes,
    bool? tablaSuma,
    bool? tablaEscalar,
  }) {
    return PdfSections(
      resumen: resumen ?? this.resumen,
      puntos: puntos ?? this.puntos,
      ordenes: ordenes ?? this.ordenes,
      tablaSuma: tablaSuma ?? this.tablaSuma,
      tablaEscalar: tablaEscalar ?? this.tablaEscalar,
    );
  }
}

/// Todo lo que el informe necesita saber de la curva.
class CurveReport {
  final EllipticCurve curve;
  final bool isSingular;
  final List<ECPoint> points;
  final List<PointOrder> orders;

  const CurveReport({
    required this.curve,
    required this.isSingular,
    required this.points,
    required this.orders,
  });

  int get cardinality => points.length;
  bool get isCyclic => orders.any((o) => o.isGenerator);
  int get generatorCount => orders.where((o) => o.isGenerator).length;

  /// 4a³ + 27b² (mod p)
  BigInt get discriminant =>
      (BigInt.from(4) * curve.a.pow(3) + BigInt.from(27) * curve.b.pow(2)) % curve.p;
}

// Las fuentes base del PDF (Helvetica/Courier) codifican con WinAnsi, es decir
// solo Latin-1. Los acentos del español caben; los símbolos matemáticos por
// encima de U+00FF no, y `latin1.encode` descartaría la cadena entera en
// silencio. `pdfSafe` los traduce antes de que eso ocurra.
const Map<String, String> _replacements = {
  '≡': '=', // ≡
  '≤': '<=', // ≤
  '≥': '>=', // ≥
  '≠': '!=', // ≠
  '√': 'raiz', // √
  '∞': 'inf', // ∞
  '−': '-', // −
  '…': '...', // …
  '\u{1D4AA}': 'O', // 𝒪
  '\u{1D53D}': 'F', // 𝔽
  '→': '->', // →
  '×': 'x', // ×  (existe en Latin-1, pero se lee mejor como x)
};

/// Deja una cadena dentro de Latin-1, que es lo único que codifican las
/// fuentes base del PDF. Cualquier carácter alto restante pasa a '?'.
String pdfSafe(String s) {
  String out = s;
  _replacements.forEach((from, to) => out = out.replaceAll(from, to));
  return String.fromCharCodes(out.runes.map((r) => r <= 0xFF ? r : 0x3F));
}

String _pt(ECPoint p) => p.isInfinity ? 'O' : '(${p.x}, ${p.y})';

String _equation(EllipticCurve c) => pdfSafe('y² = x³ + ${c.a}x + ${c.b}  (mod ${c.p})');

const PdfColor _accent = PdfColor.fromInt(0xFF5B5BD6);
const PdfColor _headerBg = PdfColor.fromInt(0xFFEDEDFB);
const PdfColor _zebra = PdfColor.fromInt(0xFFF6F6FA);
const PdfColor _muted = PdfColor.fromInt(0xFF6B6B7B);
const PdfColor _danger = PdfColor.fromInt(0xFFC0392B);
const PdfColor _ok = PdfColor.fromInt(0xFF1E8E5A);

/// Construye el PDF con las secciones pedidas.
Future<Uint8List> buildCurvePdf({
  required CurveReport report,
  required PdfSections sections,
  DateTime? generatedAt,
}) async {
  final pw.Font base = pw.Font.helvetica();
  final pw.Font bold = pw.Font.helveticaBold();
  final pw.Font mono = pw.Font.courier();
  final pw.Font monoBold = pw.Font.courierBold();

  final doc = pw.Document(
    title: pdfSafe('Curva elíptica ${_equation(report.curve)}'),
    author: 'Calculadora de Curvas Elipticas',
    creator: 'Calculadora de Curvas Elipticas',
    subject: 'Analisis de y^2 = x^3 + ax + b sobre F_p',
    theme: pw.ThemeData.withFont(base: base, bold: bold),
  );

  final DateTime now = generatedAt ?? DateTime.now();
  final String stamp = '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/${now.year} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  // --- Documento principal (vertical) ---
  final List<pw.Widget> body = [];

  if (sections.resumen) {
    body.addAll(_summary(report, mono));
  }

  if (sections.puntos && !report.isSingular && report.points.isNotEmpty) {
    body.add(_sectionTitle('Puntos de la curva (${report.cardinality})'));
    body.add(pw.SizedBox(height: 8));
    body.add(_pointsGrid(report.points, mono));
    body.add(pw.SizedBox(height: 18));
  }

  if (sections.ordenes && !report.isSingular && report.orders.isNotEmpty) {
    body.addAll(_ordersSection(report, mono, bold));
  }

  if (body.isNotEmpty) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
        header: (ctx) => _pageHeader(ctx, report, bold),
        footer: (ctx) => _pageFooter(ctx, stamp),
        build: (ctx) => body,
      ),
    );
  }

  // --- Tablas de operaciones (horizontal, se parten en bloques de columnas) ---
  final bool tablesFit = !report.isSingular && report.cardinality <= kMaxPdfTableSize;

  if (sections.tablaSuma && tablesFit) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 34, 28, 34),
        header: (ctx) => _pageHeader(ctx, report, bold),
        footer: (ctx) => _pageFooter(ctx, stamp),
        build: (ctx) => _operationTable(
          title: 'Tabla de suma  (P + Q)',
          corner: '+',
          count: report.cardinality,
          colLabel: (c) => _pt(report.points[c]),
          rowLabel: (r) => _pt(report.points[r]),
          cell: (r, c) => _pt(report.curve.add(report.points[r], report.points[c])),
          mono: mono,
          monoBold: monoBold,
        ),
      ),
    );
  }

  if (sections.tablaEscalar && tablesFit) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 34, 28, 34),
        header: (ctx) => _pageHeader(ctx, report, bold),
        footer: (ctx) => _pageFooter(ctx, stamp),
        build: (ctx) => _operationTable(
          title: 'Tabla de multiplicacion escalar  (k · P)',
          corner: 'k \\ P',
          count: report.cardinality,
          colLabel: (c) => _pt(report.points[c]),
          rowLabel: (r) => '${r + 1}',
          cell: (r, c) => _pt(report.curve.multiply(BigInt.from(r + 1), report.points[c])),
          mono: mono,
          monoBold: monoBold,
        ),
      ),
    );
  }

  return doc.save();
}

pw.Widget _pageHeader(pw.Context ctx, CurveReport r, pw.Font bold) {
  if (ctx.pageNumber == 1) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(pdfSafe('Curvas elípticas sobre F_p'),
              style: pw.TextStyle(font: bold, fontSize: 18, color: _accent)),
          pw.SizedBox(height: 2),
          pw.Text(_equation(r.curve), style: const pw.TextStyle(fontSize: 12, color: _muted)),
        ],
      ),
    );
  }
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Text(_equation(r.curve), style: const pw.TextStyle(fontSize: 9, color: _muted)),
  );
}

pw.Widget _pageFooter(pw.Context ctx, String stamp) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 10),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(pdfSafe('Generado el $stamp'),
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
        pw.Text(pdfSafe('Página ${ctx.pageNumber} de ${ctx.pagesCount}'),
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
  );
}

pw.Widget _sectionTitle(String text) {
  return pw.Text(pdfSafe(text),
      style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold));
}

List<pw.Widget> _summary(CurveReport r, pw.Font mono) {
  final c = r.curve;
  final int card = r.cardinality;
  final int pInt = c.p.toInt();
  final int diff = (card - (pInt + 1)).abs();
  final bool hasseOk = diff * diff <= 4 * pInt;

  final rows = <List<String>>[
    ['Coeficiente a', '${c.a}'],
    ['Coeficiente b', '${c.b}'],
    ['Módulo p (primo)', '${c.p}'],
    ['Discriminante 4a³ + 27b² (mod p)', '${r.discriminant}'],
    ['Curva singular', r.isSingular ? 'SÍ - el discriminante es 0' : 'No'],
  ];

  if (!r.isSingular) {
    rows.addAll([
      ['Cardinalidad #E(Fp)', '$card  (incluye el punto al infinito O)'],
      ['Cota de Hasse', '|$card - ${pInt + 1}| = $diff  <=  2*raiz($pInt)'],
      ['Cumple Hasse', hasseOk ? 'Sí' : 'No'],
      ['Grupo cíclico', r.isCyclic ? 'Sí' : 'No'],
      if (r.isCyclic) ['Generadores', '${r.generatorCount} de $card puntos'],
    ]);
  }

  return [
    _sectionTitle('Resumen'),
    pw.SizedBox(height: 8),
    pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(6),
      },
      children: [
        for (int i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isOdd ? _zebra : PdfColors.white),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(pdfSafe(rows[i][0]), style: const pw.TextStyle(fontSize: 9)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Text(
                  pdfSafe(rows[i][1]),
                  style: pw.TextStyle(
                    font: mono,
                    fontSize: 9,
                    color: rows[i][0] == 'Curva singular' && r.isSingular ? _danger : PdfColors.black,
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
    pw.SizedBox(height: 18),
    if (r.isSingular)
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFFDECEA),
          border: pw.Border.all(color: _danger, width: 0.8),
        ),
        child: pw.Text(
          pdfSafe('La curva es singular: el discriminante 4a³ + 27b² es congruente con 0 '
              'módulo p. No forma un grupo, por lo que no se listan puntos ni operaciones.'),
          style: pw.TextStyle(fontSize: 9, font: mono, color: _danger),
        ),
      ),
    if (r.isSingular) pw.SizedBox(height: 18),
  ];
}

pw.Widget _pointsGrid(List<ECPoint> points, pw.Font mono) {
  const int cols = 6;
  final int rows = (points.length + cols - 1) ~/ cols;

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    children: [
      for (int r = 0; r < rows; r++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: r.isOdd ? _zebra : PdfColors.white),
          children: [
            for (int c = 0; c < cols; c++)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: pw.Text(
                  r * cols + c < points.length ? pdfSafe(_pt(points[r * cols + c])) : '',
                  style: pw.TextStyle(font: mono, fontSize: 8),
                ),
              ),
          ],
        ),
    ],
  );
}

List<pw.Widget> _ordersSection(CurveReport r, pw.Font mono, pw.Font bold) {
  return [
    _sectionTitle('Orden de cada punto y generadores (${r.cardinality})'),
    pw.SizedBox(height: 6),
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: r.isCyclic ? const PdfColor.fromInt(0xFFE9F7F0) : const PdfColor.fromInt(0xFFFDECEA),
        border: pw.Border.all(color: r.isCyclic ? _ok : _danger, width: 0.8),
      ),
      child: pw.Text(
        pdfSafe(r.isCyclic
            ? 'Grupo cíclico: ${r.generatorCount} de ${r.cardinality} puntos tienen orden '
                '${r.cardinality} y generan el grupo completo.'
            : 'Grupo no cíclico: ningún punto alcanza orden ${r.cardinality}.'),
        style: pw.TextStyle(fontSize: 9, font: bold, color: r.isCyclic ? _ok : _danger),
      ),
    ),
    pw.SizedBox(height: 8),
    pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(3),
        4: pw.FlexColumnWidth(2),
        5: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerBg),
          children: [
            for (int i = 0; i < 2; i++) ...[
              _th('Punto', bold),
              _th('Orden', bold),
              _th('Generador', bold),
            ],
          ],
        ),
        // Dos pares de columnas por fila para aprovechar el ancho.
        for (int i = 0; i < (r.orders.length + 1) ~/ 2; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: i.isOdd ? _zebra : PdfColors.white),
            children: [
              ..._orderCells(r.orders, i, mono),
              ..._orderCells(r.orders, i + (r.orders.length + 1) ~/ 2, mono),
            ],
          ),
      ],
    ),
    pw.SizedBox(height: 18),
  ];
}

List<pw.Widget> _orderCells(List<PointOrder> orders, int index, pw.Font mono) {
  if (index >= orders.length) {
    return [_td('', mono), _td('', mono), _td('', mono)];
  }
  final o = orders[index];
  return [
    _td(_pt(o.point), mono),
    _td('${o.order}', mono),
    _td(o.isGenerator ? 'si' : '-', mono, color: o.isGenerator ? _ok : _muted),
  ];
}

pw.Widget _th(String text, pw.Font bold) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(pdfSafe(text), style: pw.TextStyle(font: bold, fontSize: 8, color: _accent)),
    );

pw.Widget _td(String text, pw.Font mono, {PdfColor? color}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(pdfSafe(text), style: pw.TextStyle(font: mono, fontSize: 8, color: color)),
    );

/// Tabla N×N partida en bloques verticales de columnas para que quepa a lo ancho.
List<pw.Widget> _operationTable({
  required String title,
  required String corner,
  required int count,
  required String Function(int) colLabel,
  required String Function(int) rowLabel,
  required String Function(int, int) cell,
  required pw.Font mono,
  required pw.Font monoBold,
}) {
  final widgets = <pw.Widget>[
    _sectionTitle(title),
    pw.SizedBox(height: 4),
    pw.Text(
      pdfSafe('La tabla se divide en bloques de $_kColsPerChunk columnas '
          'para que quepa en la página.'),
      style: const pw.TextStyle(fontSize: 8, color: _muted),
    ),
    pw.SizedBox(height: 10),
  ];

  for (int start = 0; start < count; start += _kColsPerChunk) {
    final int end = (start + _kColsPerChunk).clamp(0, count);

    widgets.add(
      pw.Text(
        pdfSafe('Columnas ${start + 1} a $end de $count'),
        style: pw.TextStyle(font: monoBold, fontSize: 8, color: _accent),
      ),
    );
    widgets.add(pw.SizedBox(height: 4));
    widgets.add(
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _headerBg),
            children: [
              _cellBox(corner, monoBold, color: _accent),
              for (int c = start; c < end; c++) _cellBox(colLabel(c), monoBold, color: _accent),
            ],
          ),
          for (int r = 0; r < count; r++)
            pw.TableRow(
              decoration: pw.BoxDecoration(color: r.isOdd ? _zebra : PdfColors.white),
              children: [
                _cellBox(rowLabel(r), monoBold, color: _accent),
                for (int c = start; c < end; c++) _cellBox(cell(r, c), mono),
              ],
            ),
        ],
      ),
    );
    widgets.add(pw.SizedBox(height: 14));
  }

  return widgets;
}

pw.Widget _cellBox(String text, pw.Font font, {PdfColor? color}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
      child: pw.Text(
        pdfSafe(text),
        maxLines: 1,
        style: pw.TextStyle(font: font, fontSize: 6.5, color: color),
      ),
    );
