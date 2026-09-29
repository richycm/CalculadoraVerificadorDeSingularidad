import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:singularidad_calculator/export/pdf_export.dart';
import 'package:singularidad_calculator/math/ec_math.dart';

CurveReport reportFor(int a, int b, int p) {
  final curve = EllipticCurve(a: BigInt.from(a), b: BigInt.from(b), p: BigInt.from(p));
  final singular = curve.isSingular();
  final points = singular ? <ECPoint>[] : curve.getPoints();
  return CurveReport(
    curve: curve,
    isSingular: singular,
    points: points,
    orders: singular ? const [] : computePointOrders(curve, points),
  );
}

bool looksLikePdf(Uint8List bytes) =>
    bytes.length > 500 && String.fromCharCodes(bytes.take(5)) == '%PDF-';

void main() {
  test('genera un PDF válido con todas las secciones', () async {
    final bytes = await buildCurvePdf(
      report: reportFor(2, 3, 17),
      sections: const PdfSections(
        resumen: true,
        puntos: true,
        ordenes: true,
        tablaSuma: true,
        tablaEscalar: true,
      ),
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('genera un PDF solo con el resumen', () async {
    final bytes = await buildCurvePdf(
      report: reportFor(2, 3, 17),
      sections: const PdfSections(resumen: true, puntos: false, ordenes: false),
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('maneja una curva singular sin puntos', () async {
    final report = reportFor(0, 0, 17);
    expect(report.isSingular, isTrue);
    final bytes = await buildCurvePdf(report: report, sections: const PdfSections());
    expect(looksLikePdf(bytes), isTrue);
  });

  test('soporta curvas grandes sin las tablas N×N', () async {
    final report = reportFor(3, 8, 101);
    expect(report.cardinality, greaterThan(kMaxPdfTableSize));
    final bytes = await buildCurvePdf(
      report: report,
      sections: const PdfSections(resumen: true, puntos: true, ordenes: true),
    );
    expect(looksLikePdf(bytes), isTrue);
  });

  test('cubre varias curvas y tamaños sin lanzar', () async {
    for (final c in [
      [2, 3, 17],
      [1, 6, 11],
      [0, 7, 13],
      [2, 2, 5],
      [1, 1, 29],
      [4, 20, 59],
    ]) {
      final report = reportFor(c[0], c[1], c[2]);
      final bytes = await buildCurvePdf(
        report: report,
        sections: PdfSections(
          resumen: true,
          puntos: true,
          ordenes: true,
          tablaSuma: report.cardinality <= kMaxPdfTableSize,
          tablaEscalar: report.cardinality <= kMaxPdfTableSize,
        ),
      );
      expect(looksLikePdf(bytes), isTrue, reason: 'a=${c[0]} b=${c[1]} p=${c[2]}');
    }
  });

  group('pdfSafe', () {
    test('todo lo que devuelve se codifica en Latin-1', () {
      const entradas = [
        'y² ≡ x³ + 2x + 3 (mod 17)',
        'Cardinalidad #E(𝔽p) incluyendo 𝒪',
        '|#E − (p+1)| ≤ 2√p',
        'Módulo, cíclico, ningún, raíz, Página, SÍ',
        '22 × 22 celdas → 484',
        'sin nada raro',
        '',
      ];
      for (final s in entradas) {
        final safe = pdfSafe(s);
        // latin1.encode lanza si hay algún carácter fuera de rango; ese es
        // justo el fallo que haría desaparecer el texto del PDF.
        expect(() => latin1.encode(safe), returnsNormally, reason: s);
        for (final r in safe.runes) {
          expect(r, lessThanOrEqualTo(0xFF), reason: 'en "$s"');
        }
      }
    });

    test('conserva los acentos del español y traduce los símbolos', () {
      expect(pdfSafe('Módulo cíclico'), 'Módulo cíclico');
      expect(pdfSafe('a ≡ b'), 'a = b');
      expect(pdfSafe('d ≤ 2√p'), 'd <= 2raizp');
      expect(pdfSafe('𝒪 y 𝔽'), 'O y F');
      expect(pdfSafe('sin cambios'), 'sin cambios');
    });
  });

  test('el resumen refleja el discriminante y la ciclicidad', () {
    final r = reportFor(2, 3, 17);
    expect(r.cardinality, 22);
    expect(r.discriminant, (BigInt.from(4) * BigInt.from(8) + BigInt.from(27) * BigInt.from(9)) % BigInt.from(17));
    expect(r.isCyclic, isTrue);
    expect(r.generatorCount, greaterThan(0));
  });
}
