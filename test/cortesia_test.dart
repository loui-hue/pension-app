import 'package:flutter_test/flutter_test.dart';
import 'package:pension_app/core/utils/cortesia.dart';

/// Cortesía de «Cliente Frecuente»: un refresco del día, una vez.
void main() {
  const insignias = [
    {'name': 'Primer Pedido', 'xp_required': 0, 'reward_product': null},
    {'name': 'Cliente Frecuente', 'xp_required': 100, 'reward_product': {'id': 9, 'name': 'Refresco del día (vaso)'}},
  ];

  test('la cortesía se muestra como tal y no con precio', () {
    final refresco = {'product': {'name': 'Refresco del día (vaso)'}, 'quantity': 1, 'subtotal': '0.00', 'courtesy_badge_id': 2};
    final silpancho = {'product': {'name': 'Silpancho'}, 'quantity': 2, 'subtotal': '28.00', 'courtesy_badge_id': null};

    expect(esCortesia(refresco), isTrue);
    expect(esCortesia(silpancho), isFalse);
    expect(lineaDelPlato(refresco, conPrecio: true), '• Refresco del día (vaso) x1 — Cortesía');
    expect(lineaDelPlato(silpancho, conPrecio: true), '• Silpancho x2 — Bs. 28.00');
    expect(lineaDelPlato(silpancho), '• Silpancho x2');
  });

  test('solo se ofrece la cortesía disponible', () {
    expect(cortesiaDisponible([{'estado': 'usada'}]), isNull);
    expect(cortesiaDisponible([{'estado': 'disponible', 'product_id': 9}])?['product_id'], 9);
  });

  test('el aviso dice si la puede pedir, si ya la usó o cómo ganarla', () {
    expect(avisoDeCortesia(insignias, [])!.estado, 'pendiente');
    expect(avisoDeCortesia(insignias, [])!.detalle, contains('100 XP'));

    final disponible = avisoDeCortesia(insignias, [
      {'estado': 'disponible', 'insignia': 'Cliente Frecuente', 'producto': 'Refresco del día (vaso)'},
    ])!;
    expect(disponible.estado, 'disponible');
    expect(disponible.titulo, 'Tienes un Refresco del día (vaso) de cortesía');

    final usada = avisoDeCortesia(insignias, [
      {'estado': 'usada', 'producto': 'Refresco del día (vaso)', 'pedido_id': 12, 'usada_en': '2026-11-25T16:00:00.000000Z'},
    ])!;
    expect(usada.estado, 'usada');
    expect(usada.detalle, contains('pedido #12'));
  });

  test('sin insignias con premio no hay aviso', () {
    expect(avisoDeCortesia([insignias.first], []), isNull);
  });
}
