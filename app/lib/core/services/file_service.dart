import 'dart:io';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FileService {
  final DioClient _client;
  FileService(this._client);

  /// Initialize chunked upload
  Future<Map<String, dynamic>> initUpload({
    required String originalName,
    required int fileSize,
    required String mimeType,
    String? taskId,
    String? taskType,
    int totalChunks = 1,
  }) async {
    final res = await _client.dio.post('/files/init', data: {
      'originalName': originalName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      if (taskId != null) 'taskId': taskId,
      if (taskType != null) 'taskType': taskType,
      'totalChunks': totalChunks,
    });
    return res.data;
  }

  /// Upload a chunk
  Future<void> uploadChunk(String fileId, int chunkIndex, List<int> bytes) async {
    final formData = FormData.fromMap({
      'fileId': fileId,
      'chunkIndex': chunkIndex,
      'chunk': MultipartFile.fromBytes(bytes, filename: 'chunk_$chunkIndex'),
    });
    await _client.dio.post('/files/chunk', data: formData);
  }

  /// Complete chunked upload
  Future<Map<String, dynamic>> completeUpload(String fileId) async {
    final res = await _client.dio.post('/files/complete', data: {
      'fileId': fileId,
    });
    return res.data;
  }

  /// 智能上传：OSS 直传，其他存储走服务端
  Future<Map<String, dynamic>> simpleUpload(
    String filePath, {
    String? taskId,
    String? taskType,
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();
    final fileName = filePath.split('/').last;
    final mimeType = _mimeFromExt(fileName);

    // Step 1: initUpload — 获取 presignedUrl（OSS 模式）或只初始化
    final initRes = await initUpload(
      originalName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      taskId: taskId,
      taskType: taskType,
      totalChunks: 1,
    );

    final fileId = initRes['id'] as String;
    final presignedUrl = initRes['presignedUrl'] as String?;

    if (presignedUrl != null) {
      // OSS 直传：PUT 文件到 OSS，不经过服务端
      await _putToOss(presignedUrl, filePath, mimeType, onProgress);
    } else {
      // MinIO / Local: 走传统多分片上传
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'fileId': fileId,
        'chunkIndex': 0,
        'chunk': MultipartFile.fromBytes(bytes, filename: fileName),
      });
      await _client.dio.post('/files/chunk', data: formData,
        onSendProgress: onProgress,
      );
    }

    // Step 3: completeUpload — 确认文件已到位
    final completeRes = await completeUpload(fileId);
    return completeRes;
  }

  /// PUT 文件到 OSS 预签名 URL
  Future<void> _putToOss(
    String presignedUrl,
    String filePath,
    String mimeType,
    void Function(int sent, int total)? onProgress,
  ) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // 使用独立 Dio 实例（不走 auth 拦截器，直接访问 OSS）
    final ossDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ));

    await ossDio.put(
      presignedUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': mimeType,
          'Content-Length': bytes.length,
        },
      ),
      onSendProgress: onProgress,
    );
  }

  String _mimeFromExt(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'wav': return 'audio/wav';
      case 'mp3': return 'audio/mpeg';
      case 'm4a': return 'audio/mp4';
      case 'aac': return 'audio/aac';
      case 'mp4': return 'video/mp4';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'gif': return 'image/gif';
      case 'webp': return 'image/webp';
      default: return 'application/octet-stream';
    }
  }

  /// Get file info + download URL
  Future<Map<String, dynamic>> getFile(String id) async {
    final res = await _client.dio.get('/files/$id');
    return res.data;
  }

  /// Get download URL only
  Future<String> getDownloadUrl(String id) async {
    final res = await _client.dio.get('/files/$id/download-url');
    return res.data['url'] as String;
  }

  /// Delete file
  Future<void> remove(String id) async {
    await _client.dio.delete('/files/$id');
  }
}

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService(ref.read(dioProvider));
});
