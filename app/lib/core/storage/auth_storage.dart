import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

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

class AuthStorage {
  final _storage = _CrossPlatformStorage();

  Future<String?> getToken() async => await _storage.read('access_token');
  Future<String?> getRefreshToken() async => await _storage.read('refresh_token');

  Future<void> saveToken(String accessToken) async {
    await _storage.write('access_token', accessToken);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write('refresh_token', refreshToken);
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await saveToken(accessToken);
    await saveRefreshToken(refreshToken);
  }

  Future<void> saveUser(UserModel user) async {
    await _storage.write('user_data', jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final data = await _storage.read('user_data');
    if (data == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTokens() async {
    await _storage.delete('access_token');
    await _storage.delete('refresh_token');
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());
