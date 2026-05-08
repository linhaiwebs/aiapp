import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

const _kBaseUrlKey = 'api_base_url';

/// 跨平台键值存储：Web 用 SharedPreferences，原生用 FlutterSecureStorage
class _CrossPlatformStorage {
  FlutterSecureStorage? _secureStorage;

  Future<String?> read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
    _secureStorage ??= const FlutterSecureStorage();
    return await _secureStorage!.read(key: key);
  }

  Future<void> write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    _secureStorage ??= const FlutterSecureStorage();
    await _secureStorage!.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      return;
    }
    _secureStorage ??= const FlutterSecureStorage();
    await _secureStorage!.delete(key: key);
  }

  Future<void> deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      return;
    }
    _secureStorage ??= const FlutterSecureStorage();
    await _secureStorage!.deleteAll();
  }
}

class DioClient {
  late final Dio dio;
  final _CrossPlatformStorage _storage = _CrossPlatformStorage();

  DioClient() {
    dio = Dio(BaseOptions(
      baseUrl: defaultApiBaseUrl,
      connectTimeout: connectionTimeout,
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 从本地存储读取运行时覆盖的 baseUrl
        final saved = await _storage.read(_kBaseUrlKey);
        if (saved != null && saved.isNotEmpty && dio.options.baseUrl != saved) {
          dio.options.baseUrl = saved;
        }
        final token = await _storage.read('access_token');
        if (token != null && token != 'undefined') {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final originalRequest = error.requestOptions;
          // Avoid refresh loop for auth endpoints
          final isAuthEndpoint = originalRequest.path.contains('/auth/login') ||
              originalRequest.path.contains('/auth/refresh') ||
              originalRequest.path.contains('/auth/register');
          if (isAuthEndpoint || originalRequest.extra['_retry'] == true) {
            handler.next(error);
            return;
          }

          final refreshToken = await _storage.read('refresh_token');
          if (refreshToken != null && refreshToken != 'undefined') {
            try {
              final refreshDio = Dio(BaseOptions(
                baseUrl: dio.options.baseUrl,
                headers: {'Content-Type': 'application/json'},
              ));
              final response = await refreshDio.post('/auth/refresh', data: {
                'refreshToken': refreshToken,
              });
              final newAccessToken = response.data['accessToken'] as String;
              final newRefreshToken = response.data['refreshToken'] as String;
              await _storage.write('access_token', newAccessToken);
              await _storage.write('refresh_token', newRefreshToken);
              originalRequest.headers['Authorization'] = 'Bearer $newAccessToken';
              originalRequest.extra['_retry'] = true;
              final retryResponse = await dio.fetch(originalRequest);
              handler.resolve(retryResponse);
            } catch (_) {
              await _storage.deleteAll();
              handler.next(error);
            }
          } else {
            handler.next(error);
          }
        } else {
          handler.next(error);
        }
      },
    ));
  }

  /// 获取当前生效的 baseUrl
  Future<String> getCurrentBaseUrl() async {
    final saved = await _storage.read(_kBaseUrlKey);
    return saved ?? defaultApiBaseUrl;
  }

  /// 运行时切换 baseUrl（持久化到本地存储，下次启动也生效）
  Future<void> setBaseUrl(String url) async {
    dio.options.baseUrl = url;
    await _storage.write(_kBaseUrlKey, url);
  }

  /// 重置为平台默认 baseUrl
  Future<void> resetBaseUrl() async {
    dio.options.baseUrl = defaultApiBaseUrl;
    await _storage.delete(_kBaseUrlKey);
  }

  /// 测试连通性，返回状态码（null=无法连接）
  Future<int?> testConnection(String url) async {
    try {
      final testDio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      // 用 POST /auth/login 不发数据，预期返回 400（参数校验失败），说明服务器在线
      final res = await testDio.post('/auth/login', data: {});
      return res.statusCode;
    } catch (e) {
      // 400/401/500 都算连通（服务器在线，只是参数/认证错误）
      if (e is DioException && e.response?.statusCode != null) {
        return e.response!.statusCode;
      }
      return null;
    }
  }
}

final dioProvider = Provider<DioClient>((ref) => DioClient());
