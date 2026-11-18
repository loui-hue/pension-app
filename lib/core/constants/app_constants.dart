class AppConstants {
  // Direcciones posibles del servidor local (laptop con Docker), en orden de preferencia.
  // La app prueba todas y usa la primera que responde (ver ApiService.elegirServidor):
  //  - 192.168.0.200: IP fija de la laptop en el Wi-Fi «Pension-Dona-Roberta» del router;
  //  - 192.168.137.1: la laptop cuando ella misma emite la zona Wi-Fi (fuera de la pensión).
  // Se cambian sin tocar código, separadas por comas:
  //   flutter run --dart-define=API_URLS=http://<IP-1>:8000/api,http://<IP-2>:8000/api
  static const String servidoresLocales = String.fromEnvironment(
    'API_URLS',
    defaultValue: 'http://192.168.0.200:8000/api,http://192.168.137.1:8000/api',
  );
  static const String servidorLocalKey = 'servidor_local'; // última dirección que respondió
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