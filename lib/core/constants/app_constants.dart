class AppConstants {
  // IP del servidor local (PC con Docker en el Wi-Fi de la pensión). Se cambia sin tocar código:
  //   flutter run --dart-define=API_URL=http://<IP-del-servidor>:8000/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.0.50:8000/api',
  );
  // Portal en la nube (solo consultas del comensal fuera de la pensión). Vacío = sin portal.
  //   flutter build apk --dart-define=PORTAL_URL=https://<IP-del-VPS>.sslip.io/api
  static const String portalUrl = String.fromEnvironment('PORTAL_URL', defaultValue: '');

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';      // rol del usuario con sesión
  static const String userIdKey = 'auth_user_id'; // id, para la caché por usuario

  // Roles
  static const String roleAdmin = 'administrador';
  static const String roleMesero = 'mesero';
  static const String roleCocina = 'cocina';
  static const String roleCaja = 'caja';
  static const String roleCliente = 'cliente';

  // Order status
  static const String statusPendiente = 'pendiente';
  static const String statusEnPreparacion = 'en_preparacion';
  static const String statusListo = 'listo';
  static const String statusEntregado = 'entregado';
  static const String statusPagado = 'pagado';
  static const String statusCancelado = 'cancelado';
}