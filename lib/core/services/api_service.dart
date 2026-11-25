import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../utils/eleccion_servidor.dart';

/// Comunicación con el servidor. La app trabaja con dos servidores:
/// - el de la pensión (red local, Wi-Fi "Pension-Dona-Roberta"): todo el sistema;
/// - el portal en la nube: solo consultas del comensal fuera de la pensión.
///
/// El servidor se elige de nuevo cada vez que cambia la red (al entrar o salir del
/// Wi-Fi), no solo al abrir la app: cada petición va al servidor vigente y, si la
/// red se cayó, se vuelve a elegir y se reintenta en el que sí responde.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static Dio? _dioCreado;
  static String? _token;

  /// Navegador de la app, para volver al login si la sesión deja de ser válida.
  static final navegador = GlobalKey<NavigatorState>();

  // Direcciones posibles del servidor de la pensión y la que respondió la última vez
  // (router de la pensión o zona Wi-Fi de la laptop).
  static final List<String> _locales = listaDeServidores(AppConstants.servidoresLocales);
  static String _local = _locales.first;
  static bool _localRecordado = false;

  // Servidor en uso: el de la pensión (red local) o el portal en la nube.
  static String _servidor = _local;
  static DateTime? _elegidoEn;
  static Future<void>? _eligiendo;

  /// true cuando la app está fuera de la pensión y consulta el portal en la nube.
  /// Las pantallas que dependen de esto (el menú) lo escuchan y se rearman solas.
  static final ValueNotifier<bool> remoto = ValueNotifier(false);
  static bool get modoRemoto => remoto.value;

  /// true cuando el servidor de la pensión no responde (el teléfono no está en su
  /// Wi-Fi). Para el personal, el menú muestra el aviso de que está fuera.
  static final ValueNotifier<bool> fueraDeLaPension = ValueNotifier(false);

  /// Cuándo recibió el portal la última copia de la pensión (solo en modo remoto).
  static DateTime? portalSincronizadoEn;

  /// Los tokens creados en el portal tienen id desde 1.000.000.000 (ver PortalSync).
  static const int _primerIdPortal = 1000000000;

  static Future<Map?> _ping(String base, int segundos) async {
    try {
      final r = await Dio(BaseOptions(
        connectTimeout: Duration(seconds: segundos),
        receiveTimeout: Duration(seconds: segundos),
      )).get('$base/ping');
      return r.data is Map ? r.data as Map : null;
    } catch (_) {
      return null;
    }
  }

  /// Prueba primero la red de la pensión; si no responde, usa el portal en la nube
  /// (solo para el comensal: el personal trabaja únicamente en la pensión).
  /// Sin [forzar], la elección se reutiliza hasta que cambie la red.
  static Future<void> elegirServidor({bool forzar = false}) {
    if (!forzar && _elegidoEn != null && DateTime.now().difference(_elegidoEn!).inSeconds < 60) {
      return Future.value();
    }
    // Varias pantallas pueden pedirlo a la vez: se hace una sola prueba.
    return _eligiendo ??= _elegir().whenComplete(() => _eligiendo = null);
  }

  static Future<void> _elegir() async {
    final rol = await _storage.read(key: AppConstants.userKey);
    final puedeUsarPortal = AppConstants.portalUrl.isNotEmpty &&
        (rol == null || rol == AppConstants.roleCliente);

    var nuevoRemoto = false;
    final encontrado = await _buscarLocal();
    final fuera = encontrado == null;
    if (encontrado != null && encontrado != _local) {
      _local = encontrado;
      await _storage.write(key: AppConstants.servidorLocalKey, value: encontrado);
    }
    if (fuera && puedeUsarPortal) {
      final portal = await _ping(AppConstants.portalUrl, 6);
      if (portal != null) {
        nuevoRemoto = true;
        portalSincronizadoEn = DateTime.tryParse('${portal['sincronizado_en']}')?.toLocal();
      }
      // Si ninguno responde se deja el local y las pantallas muestran la caché.
    }
    _servidor = nuevoRemoto ? AppConstants.portalUrl : _local;
    if (!nuevoRemoto) portalSincronizadoEn = null;
    _elegidoEn = DateTime.now();
    remoto.value = nuevoRemoto;
    fueraDeLaPension.value = fuera;
  }

  /// Prueba a la vez todas las direcciones de la pensión (la última que funcionó
  /// primero) con el mismo tiempo de espera de siempre (2 s) y devuelve la primera
  /// que responde a /ping, o null si el teléfono no está en ninguna de esas redes.
  static Future<String?> _buscarLocal() async {
    if (!_localRecordado) {
      _localRecordado = true;
      final guardado = await _storage.read(key: AppConstants.servidorLocalKey);
      if (guardado != null && _locales.contains(guardado)) _local = guardado;
    }
    return primeroQueResponde(ordenDePrueba(_locales, _local), (s) async => await _ping(s, 2) != null);
  }

  /// Vigila la red mientras la app está abierta (ver [_VigilanteDeRed]).
  static void vigilarRed() => _VigilanteDeRed().iniciar();

  static Dio get _dio => _dioCreado ??= _crearDio();

  static Dio _crearDio() {
    final dio = Dio(BaseOptions(
      // Corto: si la red se cayó falla rápido, se elige otro servidor o se muestra la caché.
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opciones, handler) async {
        await elegirServidor();
        opciones.baseUrl = _servidor;
        if (_token != null) opciones.headers['Authorization'] = 'Bearer $_token';
        handler.next(opciones);
      },
      onError: (error, handler) async {
        final reintento = await _recuperar(error);
        if (reintento != null) return handler.resolve(reintento);
        handler.next(error);
      },
    ));
    return dio;
  }

  /// Intenta resolver un fallo causado por un cambio de red. Devuelve la respuesta
  /// del reintento, o null si el error es real y debe llegar a la pantalla.
  static Future<Response?> _recuperar(DioException error) async {
    final o = error.requestOptions;
    if (o.extra['reintento'] == true) return null;
    o.extra['reintento'] = true;

    // 1) No hubo conexión con el servidor (se salió o se entró al Wi-Fi): se elige
    //    de nuevo y se reintenta si ahora corresponde otro. La petición no llegó a
    //    enviarse, así que repetirla no duplica nada. Al portal solo van consultas.
    final sinConexion = error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout;
    if (sinConexion) {
      final antes = _servidor;
      await elegirServidor(forzar: true);
      if (_servidor != antes && (_servidor != AppConstants.portalUrl || o.method == 'GET')) {
        return _reintentar(o);
      }
      return null;
    }

    if (error.response?.statusCode != 401 || o.path == '/login') return null;

    final idToken = int.tryParse((_token ?? '').split('|').first) ?? 0;
    final tokenDelPortal = idToken >= _primerIdPortal;
    final respondioPortal = o.baseUrl == AppConstants.portalUrl;

    // 2) Sesión iniciada fuera (portal) y ahora está en la pensión: el servidor de la
    //    pensión la valida con el portal y la acepta, sin pedir otra vez la contraseña.
    if (tokenDelPortal && !respondioPortal) {
      // Varias pantallas pueden recibir el 401 a la vez: se valida una sola vez.
      final valida = await (_trayendoSesion ??= _traerSesion().whenComplete(() => _trayendoSesion = null));
      if (valida == true) return await _reintentar(o);
      // null: no se pudo comprobar (sin Internet en la pensión, red inestable). No se
      // cierra la sesión: la pantalla muestra lo guardado y se reintenta en la siguiente.
      if (valida == null) return null;
    }

    // 3) Sesión de la pensión que el portal todavía no recibió: no se cierra la
    //    sesión, la pantalla muestra lo guardado hasta que llegue la copia.
    if (!tokenDelPortal && respondioPortal) return null;

    // 4) Sesión vencida o cerrada desde otro lado (p. ej. restablecieron la
    //    contraseña): se borra la sesión recordada y se vuelve al login.
    await _storage.deleteAll();
    _token = null;
    navegador.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
    return null;
  }

  static Future<bool?>? _trayendoSesion;

  /// Pide al servidor de la pensión que valide con el portal la sesión iniciada fuera.
  /// true = aceptada; false = el portal la rechazó (sesión cerrada); null = no se pudo comprobar.
  static Future<bool?> _traerSesion() async {
    try {
      await Dio(BaseOptions(
        baseUrl: _local,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $_token'},
      )).post('/portal/traer-sesion');
      return true;
    } on DioException catch (e) {
      return e.response?.statusCode == 401 ? false : null;
    }
  }

  static Future<Response?> _reintentar(RequestOptions o) async {
    try {
      return await _dio.fetch(o);
    } catch (_) {
      return null;
    }
  }

  /// Carga la sesión guardada. Las pantallas lo llaman al abrir.
  Future<void> init() async {
    _token = await _storage.read(key: AppConstants.tokenKey);
    _dio;
    await elegirServidor();
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    _token = token;
  }

  Future<void> clearToken() async {
    await _storage.delete(key: AppConstants.tokenKey);
    _token = null;
  }

  Future<Response> get(String path) async => await _dio.get(path);
  Future<Response> post(String path, dynamic data) async => await _dio.post(path, data: data);
  Future<Response> put(String path, dynamic data) async => await _dio.put(path, data: data);
  Future<Response> patch(String path, dynamic data) async => await _dio.patch(path, data: data);
  Future<Response> delete(String path) async => await _dio.delete(path);

  // Subida de archivos (p. ej. imagen del QR); Dio arma el multipart a partir del FormData.
  Future<Response> postMultipart(String path, FormData data) async => await _dio.post(
        path,
        data: data,
        options: Options(contentType: 'multipart/form-data'),
      );

  // Descarga binaria con el token de sesión (imágenes protegidas del API).
  Future<List<int>> getBytes(String path) async {
    final res = await _dio.get<List<int>>(path, options: Options(responseType: ResponseType.bytes));
    return res.data ?? [];
  }
}

/// Revisa la red al volver a la app y cada 5 s mientras está abierta: si el teléfono
/// entró o salió del Wi-Fi de la pensión, cambia de servidor solo.
class _VigilanteDeRed with WidgetsBindingObserver {
  bool _enPrimerPlano = true;

  void iniciar() {
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_enPrimerPlano || ApiService._eligiendo != null) return;
      // Se vuelve a elegir solo si la red de la pensión apareció (estando fuera),
      // desapareció (estando dentro) o el servidor responde en la otra dirección
      // (se pasó del router de la pensión a la zona Wi-Fi de la laptop, o al revés).
      final encontrado = await ApiService._buscarLocal();
      final hayPension = encontrado != null;
      if (hayPension == ApiService.fueraDeLaPension.value ||
          (hayPension && encontrado != ApiService._local)) {
        await ApiService.elegirServidor(forzar: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPrimerPlano = state == AppLifecycleState.resumed;
    // Al volver a la app el teléfono pudo cambiar de red mientras tanto.
    if (_enPrimerPlano) ApiService.elegirServidor(forzar: true);
  }
}
