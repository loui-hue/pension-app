import 'dart:async';

/// Elección del servidor de la pensión entre varias direcciones posibles
/// (p. ej. el router de la pensión y la zona Wi-Fi de la laptop). Funciones
/// puras, sin red: se prueban en test/eleccion_servidor_test.dart.

/// Lista de direcciones escritas separadas por comas (como en --dart-define).
List<String> listaDeServidores(String texto) =>
    texto.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

/// Orden de prueba: primero la última que funcionó (si sigue en la lista).
List<String> ordenDePrueba(List<String> todos, String? ultimo) {
  if (ultimo == null || !todos.contains(ultimo)) return List.of(todos);
  return [ultimo, ...todos.where((s) => s != ultimo)];
}

/// Prueba todas a la vez y devuelve la primera que responde; null si ninguna.
/// Así, en una red donde una dirección no existe, no se espera su tiempo de
/// espera: basta con que la otra conteste.
Future<String?> primeroQueResponde(List<String> candidatos, Future<bool> Function(String) responde) {
  if (candidatos.isEmpty) return Future.value(null);
  final resultado = Completer<String?>();
  var pendientes = candidatos.length;
  Future<bool> probar(String c) async {
    try {
      return await responde(c);
    } catch (_) {
      return false;   // un fallo de red cuenta como "no responde"
    }
  }

  for (final c in candidatos) {
    probar(c).then((ok) {
      if (resultado.isCompleted) return;
      if (ok) {
        resultado.complete(c);
      } else if (--pendientes == 0) {
        resultado.complete(null);
      }
    });
  }
  return resultado.future;
}
