import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:singularidad_calculator/main.dart';

void main() {
  testWidgets('la app arranca con las pestañas y los campos a, b, p', (WidgetTester tester) async {
    await tester.pumpWidget(const SingularityApp());
    await tester.pump();

    expect(find.text('General'), findsOneWidget);
    expect(find.text('Calculadora'), findsOneWidget);
    expect(find.text('Tablas'), findsOneWidget);
    expect(find.text('Generadores'), findsOneWidget);

    expect(find.widgetWithText(TextField, '2'), findsOneWidget); // a
    expect(find.widgetWithText(TextField, '3'), findsOneWidget); // b
    expect(find.widgetWithText(TextField, '17'), findsOneWidget); // p
    expect(find.widgetWithText(ElevatedButton, 'Calcular'), findsOneWidget);
  });
}
