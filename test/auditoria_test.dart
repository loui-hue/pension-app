import 'package:flutter_test/flutter_test.dart';
import 'package:pension_app/core/utils/auditoria.dart';

/// Formato de la pantalla «Auditoría».
void main() {
  final ahora = DateTime(2026, 11, 25, 18, 30);

  test('el encabezado del día dice Hoy, Ayer o la fecha', () {
    expect(etiquetaDia(DateTime(2026, 11, 25, 0, 5), ahora), 'Hoy');
    expect(etiquetaDia(DateTime(2026, 11, 24, 23, 59), ahora), 'Ayer');
    expect(etiquetaDia(DateTime(2026, 11, 3, 9), ahora), '03/11/2026');
  });

  test('muestra la hora con dos dígitos', () {
    expect(horaCorta(DateTime(2026, 11, 25, 9, 5)), '09:05');
  });

  test('la categoría es la primera parte de la acción', () {
    expect(categoriaDe('cobro.confirmado'), 'cobro');
    expect(categoriaDe('sesion.fallida'), 'sesion');
  });

  test('el autor muestra el nombre y el rol, o «Sin cuenta»', () {
    expect(autorDe({'user_name': 'Pedro Caja', 'user_role': 'caja'}), 'Pedro Caja · Caja');
    expect(autorDe({'user_name': 'Ana', 'user_role': 'cliente'}), 'Ana · Comensal');
    expect(autorDe({'user_name': null}), 'Sin cuenta');
  });

  test('lee la fecha del servidor (UTC) en la hora del teléfono', () {
    final f = fechaLocal('2026-11-25T18:30:00.000000Z')!;
    expect(f.isUtc, isFalse);
    expect(f.toUtc(), DateTime.utc(2026, 11, 25, 18, 30));
    expect(fechaLocal(null), isNull);
  });
}
