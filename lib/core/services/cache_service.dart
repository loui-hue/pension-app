import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Copia local de las últimas respuestas del API (XP, retos, racha, pedidos).
/// Permite que el comensal vea su avance aunque esté fuera de la red de la
/// pensión; se actualiza cada vez que la app logra conectarse.
class CacheService {
  static const _prefijo = 'cache_';

  /// Las claves incluyen el usuario para no mezclar datos de dos cuentas.
  static String clave(int? usuarioId, String nombre) => '$_prefijo${usuarioId ?? 0}_$nombre';

  static Future<void> guardar(String clave, Object datos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(clave, jsonEncode({
      'guardado': DateTime.now().toIso8601String(),
      'datos': datos,
    }));
  }

  /// Devuelve los datos guardados y cuándo se guardaron, o null si no hay.
  static Future<({dynamic datos, DateTime guardado})?> leer(String clave) async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(clave);
    if (texto == null) return null;
    try {
      final json = jsonDecode(texto) as Map<String, dynamic>;
      return (datos: json['datos'], guardado: DateTime.parse(json['guardado'] as String));
    } catch (_) {
      return null;
    }
  }

  /// "hoy 14:05", "ayer 09:30" o "07/11 18:20".
  static String describirFecha(DateTime fecha) {
    final hora = '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    final hoy = DateTime.now();
    final dias = DateTime(hoy.year, hoy.month, hoy.day)
        .difference(DateTime(fecha.year, fecha.month, fecha.day))
        .inDays;
    if (dias == 0) return 'hoy $hora';
    if (dias == 1) return 'ayer $hora';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} $hora';
  }
}
