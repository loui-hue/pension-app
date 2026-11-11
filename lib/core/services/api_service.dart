import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late Dio _dio;

  /// Navegador de la app, para volver al login si la sesión deja de ser válida.
  static final navegador = GlobalKey<NavigatorState>();

  // Servidor en uso: el de la pensión (red local) o el portal en la nube.
  static String _servidor = AppConstants.baseUrl;
  static DateTime? _elegidoEn;

  /// true cuando la app está fuera de la pensión y consulta el portal en la nube.
  static bool modoRemoto = false;

  /// Cuándo recibió el portal la última copia de la pensión (solo en modo remoto).
  static DateTime? portalSincronizadoEn;

  /// Prueba primero la red de la pensión; si no responde, usa el portal en la nube.
  /// La elección se recuerda 30 segundos para no probar en cada pantalla.
  static Future<void> elegirServidor({bool forzar = false}) async {
    if (!forzar && _elegidoEn != null && DateTime.now().difference(_elegidoEn!).inSeconds < 30) return;

    Future<Map?> ping(String base, int segundos) async {
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

    if (await ping(AppConstants.baseUrl, 2) != null || AppConstants.portalUrl.isEmpty) {
      _servidor = AppConstants.baseUrl;
      modoRemoto = false;
      portalSincronizadoEn = null;
    } else {
      final portal = await ping(AppConstants.portalUrl, 6);
      if (portal != null) {
        _servidor = AppConstants.portalUrl;
        modoRemoto = true;
        portalSincronizadoEn = DateTime.tryParse('${portal['sincronizado_en']}')?.toLocal();
      } else {
        // Ninguno responde: se deja el local y las pantallas muestran la caché.
        _servidor = AppConstants.baseUrl;
        modoRemoto = false;
      }
    }
    _elegidoEn = DateTime.now();
  }

  Future<void> init() async {
    await elegirServidor();
    final token = await _storage.read(key: AppConstants.tokenKey);
    _dio = Dio(BaseOptions(
      baseUrl: _servidor,
      // Corto: fuera de la red de la pensión falla rápido y se muestra la caché.
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        // Sesión vencida o cerrada desde otro lado (p. ej. restablecieron la
        // contraseña): se borra la sesión recordada y se vuelve al login.
        if (error.response?.statusCode == 401 && error.requestOptions.path != '/login') {
          await _storage.deleteAll();
          navegador.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
        }
        handler.next(error);
      },
    ));
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<void> clearToken() async {
    await _storage.delete(key: AppConstants.tokenKey);
    _dio.options.headers.remove('Authorization');
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