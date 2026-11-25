// Cortesía de las insignias: «Cliente Frecuente» invita un refresco del día, una
// sola vez. El mesero lo agrega al pedido a precio 0 y el servidor comprueba que
// el comensal la tenga disponible. Funciones puras: test/cortesia_test.dart.

/// El plato del pedido es una cortesía (no se cobra).
bool esCortesia(Map item) => item['courtesy_badge_id'] != null;

/// Línea del plato en las listas de pedidos: «• Silpancho x1 — Bs. 14.00» o
/// «• Refresco del día (vaso) x1 — Cortesía».
String lineaDelPlato(Map item, {bool conPrecio = false}) {
  final base = '• ${item['product']?['name'] ?? 'Producto'} x${item['quantity']}';
  if (esCortesia(item)) return '$base — Cortesía';
  return conPrecio ? '$base — Bs. ${item['subtotal']}' : base;
}

/// La cortesía que el comensal puede usar ahora (estado «disponible»), o null.
Map? cortesiaDisponible(List cortesias) {
  for (final c in cortesias) {
    if (c is Map && c['estado'] == 'disponible') return c;
  }
  return null;
}

/// Aviso de la pantalla «Insignias» sobre la cortesía, o null si ninguna insignia
/// invita algo. estado: disponible, usada o pendiente (aún no tiene la insignia).
({String estado, String titulo, String detalle})? avisoDeCortesia(List insignias, List cortesias) {
  Map? conPremio;
  for (final i in insignias) {
    if (i is Map && i['reward_product'] != null) {
      conPremio = i;
      break;
    }
  }
  if (conPremio == null) return null;

  final insignia = conPremio['name'];
  final producto = conPremio['reward_product']['name'];
  final disponible = cortesiaDisponible(cortesias);
  if (disponible != null) {
    return (
      estado: 'disponible',
      titulo: 'Tienes un ${disponible['producto'] ?? producto} de cortesía',
      detalle: 'Por tu insignia «${disponible['insignia'] ?? insignia}». Pídeselo al mesero en tu próximo pedido: no se cobra.',
    );
  }
  for (final c in cortesias) {
    if (c is Map && c['estado'] == 'usada') {
      final fecha = DateTime.tryParse('${c['usada_en'] ?? ''}')?.toLocal();
      final cuando = fecha == null ? '' : ' el ${_dos(fecha.day)}/${_dos(fecha.month)}/${fecha.year}';
      return (
        estado: 'usada',
        titulo: 'Ya disfrutaste tu ${c['producto'] ?? producto} de cortesía',
        detalle: 'Se entregó en el pedido #${c['pedido_id']}$cuando. ¡Gracias por ser cliente frecuente!',
      );
    }
  }
  return (
    estado: 'pendiente',
    titulo: 'Gana un $producto de cortesía',
    detalle: 'Al llegar a ${conPremio['xp_required']} XP obtienes «$insignia» y la casa te lo invita una vez.',
  );
}

String _dos(int n) => n.toString().padLeft(2, '0');
