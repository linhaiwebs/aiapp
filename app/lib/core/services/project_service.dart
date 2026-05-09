import '../models/project_model.dart';
import '../network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectService {
  final DioClient _client;
  ProjectService(this._client);

  Future<List<ProjectModel>> findAll({int page = 1, int pageSize = 100}) async {
    final res = await _client.dio.get('/projects', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    final data = res.data;
    final list = data['items'] ?? data as List;
    return (list as List)
        .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final projectServiceProvider = Provider<ProjectService>((ref) {
  return ProjectService(ref.read(dioProvider));
});
