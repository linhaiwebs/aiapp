import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';

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

  final _logger = Logger();

  /// 检查是否有新版本，返回 UpdateInfo 或 null（无更新）
  Future<UpdateInfo?> checkUpdate() async {
    try {
      final res = await _client.dio.get('/app/version');
      final remote = UpdateInfo.fromJson(res.data as Map<String, dynamic>);
      final local = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(local.buildNumber) ?? 0;

      _logger.i('Update check: local=$localCode, remote=${remote.versionCode}, '
          'version=${remote.version}, force=${remote.forceUpdate}');

      if (remote.versionCode > localCode) {
        _logger.i('Update available: v${remote.version} (code ${remote.versionCode})');
        return remote;
      }
      _logger.i('Already up to date');
      return null;
    } catch (e) {
      _logger.w('Update check failed: $e');
      return null;
    }
  }

  /// 显示更新弹窗
  Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) {
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
              onPressed: () => _startDownload(ctx, context, info),
              child: const Text('立即更新'),
            ),
          ],
        ),
      ),
    );
  }

  /// 在 APP 内下载并显示进度条
  Future<void> _startDownload(BuildContext dialogCtx, BuildContext pageCtx, UpdateInfo info) async {
    if (info.downloadUrl.isEmpty) {
      ScaffoldMessenger.of(pageCtx).showSnackBar(
        const SnackBar(content: Text('下载地址无效，请联系管理员'), backgroundColor: Colors.red),
      );
      return;
    }

    // Pop update dialog first
    Navigator.pop(dialogCtx);
    // Wait for dialog close animation
    await Future.delayed(const Duration(milliseconds: 300));

    if (!pageCtx.mounted) return;

    // Show download progress dialog
    showDialog(
      context: pageCtx,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        downloadUrl: info.downloadUrl,
        onDone: (filePath) {
          Navigator.pop(ctx);
          OpenFilex.open(filePath);
        },
        onError: (msg) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(pageCtx).showSnackBar(
            SnackBar(content: Text('下载失败: $msg'), backgroundColor: Colors.red),
          );
        },
      ),
    );
  }
}

/// 下载进度弹窗（StatefulWidget 管理下载状态）
class _DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final void Function(String filePath) onDone;
  final void Function(String msg) onError;

  const _DownloadProgressDialog({
    required this.downloadUrl,
    required this.onDone,
    required this.onError,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  String _status = '准备下载...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _doDownload();
  }

  Future<void> _doDownload() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/app_update.apk';
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      setState(() => _status = '正在下载...');

      // Use a fresh Dio instance for download (not the auth-intercepted one)
      final downloadDio = Dio();
      await downloadDio.download(
        widget.downloadUrl,
        filePath,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _progress = received / total;
              _status = '${(received / 1048576).toStringAsFixed(1)} / ${(total / 1048576).toStringAsFixed(1)} MB';
            });
          }
        },
      );

      if (mounted) {
        setState(() => _progress = 1.0);
        setState(() => _status = '下载完成，正在安装...');
        await Future.delayed(const Duration(milliseconds: 500));
        widget.onDone(filePath);
      }
    } catch (e) {
      widget.onError('${e}'.replaceAll(RegExp(r'Exception:?'), '').trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_progress >= 1 ? '下载完成' : '正在更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _status,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          if (_progress > 0 && _progress < 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(ref.read(dioProvider));
});
