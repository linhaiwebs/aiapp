import 'package:flutter/foundation.dart' show kIsWeb;

/// 默认 API 端口（与后端 server PORT 对应）
const int kDefaultApiPort = 3000;

/// 根据运行平台自动选择 API 基地址
///
/// - Web (flutter run -d chrome): 相对路径 /api（同源部署）
/// - Android 模拟器: 10.0.2.2 映射到宿主机 localhost
/// - iOS 模拟器: localhost 直接访问宿主机
/// - 真机: 需要在 APP 内「设置→服务器设置」填写实际地址
/// - 编译参数覆盖: flutter build apk --dart-define=API_BASE_URL=https://cai.lhwebs.com/api
String get defaultApiBaseUrl {
  // 编译参数优先
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;

  // Web 平台：同源部署时使用相对路径
  if (kIsWeb) {
    return '/api';
  }

  // 原生平台：默认用 10.0.2.2（Android 模拟器）
  // 真机请在 APP 内「设置→服务器设置」切换为实际服务器地址
  return 'http://10.0.2.2:$kDefaultApiPort/api';
}

/// 编译期常量（用于 String.fromEnvironment 默认值）
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000/api',
);

const int maxUploadRetries = 3;
const int uploadChunkSize = 5 * 1024 * 1024; // 5MB
const Duration connectionTimeout = Duration(seconds: 30);
