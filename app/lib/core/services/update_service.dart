import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateInfo {
  final String version;
  final int versionCode;
  final String downloadUrl;
  final String changelog;
  final bool forceUpdate;

  const UpdateInfo({
    required this.version,
    required this.versionCode,
    required this.downloadUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
    version: json['version'] as String? ?? '',
    versionCode: json['versionCode'] as int? ?? 0,
    downloadUrl: json['downloadUrl'] as String? ?? '',
    changelog: json['changelog'] as String? ?? '',
    forceUpdate: json['forceUpdate'] as bool? ?? false,
  );
}

class UpdateService {
  final DioClient _client;
  UpdateService(this._client);

  /// 检查是否有新版本，返回 UpdateInfo 或 null（无更新）
  Future<UpdateInfo?> checkUpdate() async {
    try {
      final res = await _client.dio.get('/app/version');
      final remote = UpdateInfo.fromJson(res.data as Map<String, dynamic>);
      final local = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(local.buildNumber) ?? 0;

      if (remote.versionCode > localCode) {
        return remote;
      }
      return null;
    } catch (_) {
      return null; // 网络异常等静默处理
    }
  }

  /// 显示更新弹窗
  static Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !info.forceUpdate,
        child: AlertDialog(
          title: const Text('发现新版本'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('最新版本：v${info.version}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (info.changelog.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('更新内容：', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(info.changelog, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
              if (info.forceUpdate)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('此版本为强制更新，请立即升级', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
            ElevatedButton(
              onPressed: () async {
                final uri = Uri.parse(info.downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(ref.read(dioProvider));
});
