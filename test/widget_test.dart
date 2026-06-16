import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pension_app/main.dart';

void main() {
  testWidgets('App arranca mostrando la pantalla de login', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Pensión Doña Roberta'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
