/// Cálculos de la app como funciones puras (sin pantallas ni red), para
/// probarlos con pruebas unitarias (test/calculos_test.dart).
library;

/// Total del carrito: suma de precio × cantidad de cada producto.
/// [carrito] es id del producto → cantidad; [productos] es la carta recibida del
/// API (cada uno con 'id' y 'price'). Un producto que ya no está en la carta no suma.
double totalDelCarrito(Map<int, int> carrito, List productos) {
  double total = 0;
  carrito.forEach((productoId, cantidad) {
    for (final producto in productos) {
      if (producto['id'] == productoId) {
        total += (double.tryParse('${producto['price']}') ?? 0) * cantidad;
        break;
      }
    }
  });
  return total;
}

/// Cantidad total de unidades en el carrito.
int unidadesDelCarrito(Map<int, int> carrito) =>
    carrito.values.fold(0, (suma, cantidad) => suma + cantidad);

/// Tiempo de la cuenta regresiva del pago por QR en formato mm:ss.
String formatoCuentaRegresiva(int segundos) {
  final s = segundos < 0 ? 0 : segundos;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Segundos que quedan para verificar un pago: los que informó el servidor
/// menos el tiempo transcurrido desde que se cargó la lista (nunca negativo).
int segundosRestantes(int informadosPorElServidor, Duration transcurrido) {
  final restantes = informadosPorElServidor - transcurrido.inSeconds;
  return restantes < 0 ? 0 : restantes;
}
