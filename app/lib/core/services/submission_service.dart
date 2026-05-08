import '../models/submission_model.dart';
import '../network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubmissionService {
  final DioClient _client;
  SubmissionService(this._client);

  Future<SubmissionModel> create({
    required String claimId,
    required Map<String, dynamic> data,
    List<String>? fileIds,
  }) async {
    final res = await _client.dio.post('/submissions', data: {
      'claimId': claimId,
      'data': data,
      if (fileIds != null) 'fileIds': fileIds,
    });
    return SubmissionModel.fromJson(res.data);
  }

  Future<List<SubmissionModel>> findMine({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _client.dio.get('/submissions/mine', queryParameters: {
      if (status != null) 'status': status,
      'page': page,
      'pageSize': pageSize,
    });
    final list = res.data['items'] ?? res.data as List;
    return (list as List)
        .map((e) => SubmissionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SubmissionModel> findOne(String id) async {
    final res = await _client.dio.get('/submissions/$id');
    return SubmissionModel.fromJson(res.data);
  }

  Future<SubmissionModel> update(String id, Map<String, dynamic> data) async {
    final res = await _client.dio.patch('/submissions/$id', data: data);
    return SubmissionModel.fromJson(res.data);
  }

  Future<void> remove(String id) async {
    await _client.dio.delete('/submissions/$id');
  }

  Future<SubmissionModel> approve(String id) async {
    final res = await _client.dio.post('/submissions/$id/approve');
    return SubmissionModel.fromJson(res.data);
  }

  Future<SubmissionModel> reject(String id, String reason) async {
    final res = await _client.dio.post('/submissions/$id/reject', data: {
      'reason': reason,
    });
    return SubmissionModel.fromJson(res.data);
  }
}

final submissionServiceProvider = Provider<SubmissionService>((ref) {
  return SubmissionService(ref.read(dioProvider));
});
