import 'package:flutter_test/flutter_test.dart';
import 'package:pension_app/core/constants/app_constants.dart';
import 'package:pension_app/core/utils/eleccion_servidor.dart';

/// Elección del servidor de la pensión: router de la pensión (192.168.0.200) o
/// zona Wi-Fi de la laptop (192.168.137.1). Sin red: el "ping" se simula.
void main() {
  const router = 'http://192.168.0.200:8000/api';
  const zonaLaptop = 'http://192.168.137.1:8000/api';

  /// Simula la red: las direcciones de [vivas] responden tras [demora]; las demás
  /// fallan al cumplirse el tiempo de espera (2 s en la app, aquí 200 ms).
  Future<bool> Function(String) red(Set<String> vivas, {Duration demora = const Duration(milliseconds: 10)}) {
    return (s) async {
      if (vivas.contains(s)) {
        await Future.delayed(demora);
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      return false;
    };
  }

  test('la app trae las dos direcciones del servidor local, el router primero', () {
    expect(listaDeServidores(AppConstants.servidoresLocales), [router, zonaLaptop]);
    expect(listaDeServidores(' $router , ,$zonaLaptop,$router'), [router, zonaLaptop]);
  });

  test('la última dirección que funcionó se prueba primero', () {
    expect(ordenDePrueba([router, zonaLaptop], zonaLaptop), [zonaLaptop, router]);
    expect(ordenDePrueba([router, zonaLaptop], router), [router, zonaLaptop]);
    expect(ordenDePrueba([router, zonaLaptop], null), [router, zonaLaptop]);
    expect(ordenDePrueba([router, zonaLaptop], 'http://10.0.0.9:8000/api'), [router, zonaLaptop]);
  });

  test('en la pensión responde el router', () async {
    expect(await primeroQueResponde([router, zonaLaptop], red({router})), router);
  });

  test('con la zona Wi-Fi de la laptop responde 192.168.137.1 sin esperar al router', () async {
    final reloj = Stopwatch()..start();
    expect(await primeroQueResponde([router, zonaLaptop], red({zonaLaptop})), zonaLaptop);
    // Se probaron a la vez: no se esperó el tiempo de espera del router.
    expect(reloj.elapsedMilliseconds, lessThan(150));
  });

  test('si responden las dos se usa la que contesta primero', () async {
    final lenta = red({router}, demora: const Duration(milliseconds: 80));
    final rapida = red({zonaLaptop});
    expect(await primeroQueResponde([router, zonaLaptop], (s) => s == router ? lenta(s) : rapida(s)), zonaLaptop);
  });

  test('fuera de las dos redes no hay servidor local (se usa el portal)', () async {
    expect(await primeroQueResponde([router, zonaLaptop], red({})), isNull);
    expect(await primeroQueResponde([router, zonaLaptop], (_) async => throw Exception('sin red')), isNull);
    expect(await primeroQueResponde([], red({router})), isNull);
  });
}
