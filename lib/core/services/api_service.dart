import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late Dio _dio;

  Future<void> init() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
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