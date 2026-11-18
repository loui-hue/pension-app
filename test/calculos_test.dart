// Pruebas unitarias de los cálculos de la app (funciones puras, sin pantallas
// ni red). Se ejecutan con: flutter test test/calculos_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pension_app/core/utils/calculos.dart';

void main() {
  // Carta como la entrega el API: el precio llega como texto ("14.00").
  final carta = [
    {'id': 1, 'name': 'Silpancho', 'price': '14.00'},
    {'id': 2, 'name': 'Gelatina', 'price': '3.00'},
    {'id': 3, 'name': 'Jugo natural sabor Tumbo', 'price': 15},
  ];

  group('Total del carrito', () {
    test('suma precio por cantidad de cada producto', () {
      // 2 silpanchos (28) + 1 jugo (15) = 43, como en ModificarPedidoTest del API.
      expect(totalDelCarrito({1: 2, 3: 1}, carta), 43.0);
      expect(totalDelCarrito({1: 1, 2: 1}, carta), 17.0);
    });

    test('un carrito vacío vale cero', () {
      expect(totalDelCarrito({}, carta), 0.0);
    });

    test('un producto que ya no está en la carta no suma', () {
      expect(totalDelCarrito({1: 1, 99: 4}, carta), 14.0);
    });

    test('cuenta las unidades del carrito', () {
      expect(unidadesDelCarrito({1: 2, 3: 1}), 3);
      expect(unidadesDelCarrito({}), 0);
    });
  });

  group('Cuenta regresiva del pago por QR', () {
    test('se muestra en minutos y segundos (mm:ss)', () {
      expect(formatoCuentaRegresiva(600), '10:00');
      expect(formatoCuentaRegresiva(125), '02:05');
      expect(formatoCuentaRegresiva(59), '00:59');
      expect(formatoCuentaRegresiva(0), '00:00');
    });

    test('un valor negativo se muestra como 00:00', () {
      expect(formatoCuentaRegresiva(-3), '00:00');
    });

    test('descuenta el tiempo transcurrido desde que se cargó la lista', () {
      expect(segundosRestantes(600, const Duration(seconds: 45)), 555);
      expect(segundosRestantes(30, const Duration(minutes: 1)), 0);   // ya venció
    });
  });
}
