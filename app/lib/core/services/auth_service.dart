import '../models/user_model.dart';
import '../network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  final DioClient _client;
  AuthService(this._client);

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String smsCode,
  }) async {
    final res = await _client.dio.post('/auth/register', data: {
      'phone': phone,
      'password': password,
      'smsCode': smsCode,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final res = await _client.dio.post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> smsLogin({
    required String phone,
    required String smsCode,
  }) async {
    final res = await _client.dio.post('/auth/sms/login', data: {
      'phone': phone,
      'smsCode': smsCode,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> sendSmsCode(String phone) async {
    final res = await _client.dio.post('/auth/sms/send', data: {'phone': phone});
    return res.data is Map<String, dynamic> ? res.data : {};
  }

  Future<Map<String, dynamic>> refreshToken(String token) async {
    final res = await _client.dio
        .post('/auth/refresh', data: {'refreshToken': token});
    return res.data;
  }

  Future<Map<String, dynamic>> verifyRealName({
    required String realName,
    required String idCardNumber,
    String? idCardFrontUrl,
    String? idCardBackUrl,
  }) async {
    final res = await _client.dio.post('/auth/real-name', data: {
      'realName': realName,
      'idCardNumber': idCardNumber,
      if (idCardFrontUrl != null) 'idCardFrontUrl': idCardFrontUrl,
      if (idCardBackUrl != null) 'idCardBackUrl': idCardBackUrl,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> ocrIdCardFront(String base64Str) async {
    final res = await _client.dio.post('/real-name/ocr-front', data: {
      'base64Str': base64Str,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> ocrIdCardBack(String base64Str) async {
    final res = await _client.dio.post('/real-name/ocr-back', data: {
      'base64Str': base64Str,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> verifyIdentity({
    required String cardNo,
    required String realName,
  }) async {
    final res = await _client.dio.post('/real-name/verify', data: {
      'cardNo': cardNo,
      'realName': realName,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await _client.dio.post('/auth/change-password', data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    return res.data;
  }

  Future<UserModel> getMe() async {
    final res = await _client.dio.get('/auth/me');
    return UserModel.fromJson(res.data);
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});
