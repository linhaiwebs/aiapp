import '../models/task_model.dart';
import '../models/task_claim_model.dart';
import '../network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TaskService {
  final DioClient _client;
  TaskService(this._client);

  Future<List<TaskModel>> findAll({String? type, String? teamId, int page = 1, int pageSize = 20}) async {
    // Only show published & in_progress tasks in the task square
    final res = await _client.dio.get('/tasks', queryParameters: {
      if (type != null) 'type': type,
      if (teamId != null) 'teamId': teamId,
      'status': 'published,in_progress',
      'page': page,
      'pageSize': pageSize,
    });
    final list = res.data['items'] ?? res.data as List;
    return (list as List).map((e) {
      try {
        return TaskModel.fromJson(e as Map<String, dynamic>);
      } catch (err) {
        // Logging: TaskModel.fromJson parse failure
        rethrow;
      }
    }).toList();
  }

  Future<List<TaskModel>> search(String keyword, {int page = 1}) async {
    final res = await _client.dio.get('/tasks/search', queryParameters: {
      'keyword': keyword,
      'page': page,
    });
    final list = res.data['items'] ?? [];
    return (list as List).map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaskModel> findOne(String id) async {
    final res = await _client.dio.get('/tasks/$id');
    return TaskModel.fromJson(res.data);
  }

  Future<TaskClaimModel> claim(String taskId) async {
    final res = await _client.dio.post('/tasks/$taskId/claim');
    return TaskClaimModel.fromJson(res.data);
  }

  Future<void> abandon(String taskId, String claimId) async {
    await _client.dio.post('/tasks/$taskId/abandon', data: {'claimId': claimId});
  }

  Future<List<TaskClaimModel>> getMyClaims({String? status}) async {
    final res = await _client.dio.get('/tasks/claims/mine', queryParameters: {
      if (status != null) 'status': status,
    });
    final list = res.data is List ? res.data : res.data['items'] ?? [];
    return (list as List).map((e) => TaskClaimModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TaskModel> create(Map<String, dynamic> data) async {
    final res = await _client.dio.post('/tasks', data: data);
    return TaskModel.fromJson(res.data);
  }

  Future<Map<String, dynamic>> getApprovedClaims({int page = 1, int pageSize = 20, String? teamId}) async {
    final res = await _client.dio.get('/tasks/claims/approved', queryParameters: {
      'page': page,
      'pageSize': pageSize,
      if (teamId != null) 'teamId': teamId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPendingClaims({String? taskId, int page = 1, int pageSize = 20}) async {
    final res = await _client.dio.get('/tasks/claims/pending', queryParameters: {
      'page': page,
      'pageSize': pageSize,
      if (taskId != null) 'taskId': taskId,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveClaim(String claimId) async {
    final res = await _client.dio.post('/tasks/claims/$claimId/approve');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectClaim(String claimId, {String? reason}) async {
    final res = await _client.dio.post('/tasks/claims/$claimId/reject', data: {
      if (reason != null) 'reason': reason,
    });
    return res.data as Map<String, dynamic>;
  }
}

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService(ref.read(dioProvider));
});
