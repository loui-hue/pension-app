class AppConstants {
  static const String baseUrl = 'http://192.168.0.213:8000/api';
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