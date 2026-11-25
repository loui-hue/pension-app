// Formato de la pantalla «Auditoría». Funciones puras: test/auditoria_test.dart.

/// Categoría de una acción («cobro.confirmado» → «cobro»).
String categoriaDe(String accion) => accion.split('.').first;

String _dos(int n) => n.toString().padLeft(2, '0');

/// Encabezado del día: «Hoy», «Ayer» o la fecha (25/11/2026).
String etiquetaDia(DateTime fecha, DateTime ahora) {
  final dia = DateTime(fecha.year, fecha.month, fecha.day);
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final diferencia = hoy.difference(dia).inDays;
  if (diferencia == 0) return 'Hoy';
  if (diferencia == 1) return 'Ayer';
  return '${_dos(fecha.day)}/${_dos(fecha.month)}/${fecha.year}';
}

/// Hora de la acción (14:05).
String horaCorta(DateTime fecha) => '${_dos(fecha.hour)}:${_dos(fecha.minute)}';

/// Fecha del servidor (UTC) en la hora del teléfono; null si no se puede leer.
DateTime? fechaLocal(dynamic valor) => DateTime.tryParse('${valor ?? ''}')?.toLocal();

const nombresDeRol = {
  'administrador': 'Administrador',
  'mesero': 'Mesero',
  'cocina': 'Cocina',
  'caja': 'Caja',
  'cliente': 'Comensal',
};

/// «Juan Mesero · Mesero», o «Sin cuenta» si la acción no tiene usuario
/// (por ejemplo, un intento de inicio de sesión con un correo que no existe).
String autorDe(Map registro) {
  final nombre = registro['user_name'];
  if (nombre == null || '$nombre'.isEmpty) return 'Sin cuenta';
  final rol = nombresDeRol[registro['user_role']] ?? registro['user_role'];
  return rol == null ? '$nombre' : '$nombre · $rol';
}
