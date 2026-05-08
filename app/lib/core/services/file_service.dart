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

  /// Simple upload for small files
  Future<Map<String, dynamic>> simpleUpload(
    String filePath, {
    String? taskId,
    String? taskType,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (taskId != null) 'taskId': taskId,
      if (taskType != null) 'taskType': taskType,
    });
    final res = await _client.dio.post('/files/upload', data: formData);
    return res.data;
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
