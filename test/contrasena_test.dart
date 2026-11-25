import 'package:flutter_test/flutter_test.dart';
import 'package:pension_app/core/utils/contrasena.dart';

/// La misma regla que el servidor: al menos 8 caracteres, con letras y números.
void main() {
  test('rechaza contraseñas cortas, solo de números o solo de letras', () {
    for (final debil in ['abc12', 'rosa202', '12345678', 'contrasena', '123456', '']) {
      expect(esContrasenaSegura(debil), isFalse, reason: debil);
    }
  });

  test('acepta 8 o más caracteres con letras y números, también con ñ y tildes', () {
    for (final buena in ['pension24', 'montaña2026', 'admin123', 'Nueva-clave-9']) {
      expect(esContrasenaSegura(buena), isTrue, reason: buena);
    }
  });

  test('el mensaje explica la regla completa', () {
    expect(problemaDeContrasena('123'), 'La contraseña debe tener al menos 8 caracteres, con letras y números');
    expect(problemaDeContrasena('123', cual: 'La contraseña temporal'),
        'La contraseña temporal debe tener al menos 8 caracteres, con letras y números');
    expect(problemaDeContrasena('pension24'), isNull);
  });
}
