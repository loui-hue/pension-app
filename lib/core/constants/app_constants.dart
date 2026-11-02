class AppConstants {
  // IP del servidor local (PC con Docker en el Wi-Fi de la pensión). Se cambia sin tocar código:
  //   flutter run --dart-define=API_URL=http://<IP-del-servidor>:8000/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.0.50:8000/api',
  );
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';

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