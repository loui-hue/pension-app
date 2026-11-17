import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';

/// Consulta periódica al servidor (cada 5 s por defecto) para que cocina, mesero,
/// caja y comensal vean los pedidos nuevos o sus cambios de estado sin tocar
/// "actualizar".
///
/// Se eligió frente a WebSockets o notificaciones push porque son pocos
/// dispositivos en la red local, no requiere otro servicio en el servidor y
/// funciona sin Internet.
///
/// - No consulta si la app está en segundo plano ni si la pantalla está tapada
///   (otra pantalla o un diálogo encima): no gasta batería ni interrumpe al usuario.
/// - Al volver a la app consulta de inmediato.
/// - Nunca lanza una consulta mientras la anterior sigue en curso.
class ConsultaPeriodica with WidgetsBindingObserver {
  final Future<void> Function() alConsultar;
  final bool Function() puedeConsultar;
  final Duration cada;

  Timer? _timer;
  bool _enCurso = false;
  bool _enPrimerPlano = true;

  ConsultaPeriodica({
    required this.alConsultar,
    required this.puedeConsultar,
    this.cada = const Duration(seconds: 5),
  });

  void iniciar() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(cada, (_) => _consultar());
  }

  void detener() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> _consultar() async {
    if (_enCurso || !_enPrimerPlano || !puedeConsultar()) return;
    _enCurso = true;
    try {
      await alConsultar();
    } catch (_) {
      // Un fallo puntual de red no interrumpe: se reintenta en la siguiente vuelta.
    } finally {
      _enCurso = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPrimerPlano = state == AppLifecycleState.resumed;
    if (_enPrimerPlano) _consultar();
  }

  /// true si los datos nuevos difieren de los que ya se muestran; así la pantalla
  /// solo se redibuja cuando de verdad cambió algo (sin parpadeo cada 5 s).
  static bool cambio(Object? antes, Object? ahora) => jsonEncode(antes) != jsonEncode(ahora);
}
