import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singularidad_calculator/math/ec_math.dart';
import 'package:singularidad_calculator/screens/tabs/tables_tab.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('curva pequeña: muestra la tabla directamente', (tester) async {
    final curve = EllipticCurve(a: BigInt.two, b: BigInt.from(3), p: BigInt.from(17));
    final points = curve.getPoints();
    expect(points.length, lessThanOrEqualTo(kTablePreviewLimit));

    await tester.pumpWidget(wrap(TablesTab(curve: curve, points: points, isSingular: false)));
    await tester.pumpAndSettle();

    expect(find.text('Mostrar tabla completa'), findsNothing);
    expect(find.byType(DataTable), findsOneWidget);
  });

  testWidgets('curva grande: pide confirmación y luego dibuja la tabla completa', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final curve = EllipticCurve(a: BigInt.from(3), b: BigInt.from(8), p: BigInt.from(101));
    final points = curve.getPoints();
    expect(points.length, greaterThan(kTablePreviewLimit));

    await tester.pumpWidget(wrap(TablesTab(curve: curve, points: points, isSingular: false)));
    await tester.pumpAndSettle();

    // Primero el aviso, sin tabla.
    expect(find.textContaining('La cardinalidad es ${points.length}'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);

    await tester.tap(find.text('Mostrar tabla completa'));
    await tester.pumpAndSettle();

    // La tabla completa se dibuja, pero virtualizada: jamás un DataTable de
    // 102×102 ni nada remotamente cercano a 10404 celdas en el árbol.
    expect(find.byType(DataTable), findsNothing);
    final int textWidgets = find.byType(Text).evaluate().length;
    expect(textWidgets, greaterThan(20), reason: 'debe haber celdas dibujadas');
    expect(textWidgets, lessThan(1500),
        reason: 'solo deben construirse las celdas visibles, no $points.length²');
  });

  testWidgets('la tabla completa se desplaza sin romperse', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final curve = EllipticCurve(a: BigInt.from(3), b: BigInt.from(8), p: BigInt.from(101));
    final points = curve.getPoints();

    await tester.pumpWidget(wrap(TablesTab(curve: curve, points: points, isSingular: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar tabla completa'));
    await tester.pumpAndSettle();

    // Desplazamiento vertical y horizontal sobre el cuerpo de la tabla.
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('cambiar a la tabla escalar funciona en modo completo', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final curve = EllipticCurve(a: BigInt.from(3), b: BigInt.from(8), p: BigInt.from(101));
    final points = curve.getPoints();

    await tester.pumpWidget(wrap(TablesTab(curve: curve, points: points, isSingular: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar tabla completa'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escalar (k · P)'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('k \\ P'), findsOneWidget);
  });

  testWidgets('curva singular: no dibuja tabla', (tester) async {
    await tester.pumpWidget(wrap(const TablesTab(isSingular: true)));
    await tester.pumpAndSettle();
    expect(find.textContaining('singular'), findsOneWidget);
  });
}
