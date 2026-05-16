import '../models/text_collection_model.dart';
import '../network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaginatedTexts {
  final List<TextCollectionModel> items;
  final int total;
  const PaginatedTexts({required this.items, required this.total});
}

class TextCollectionService {
  final DioClient _client;
  TextCollectionService(this._client);

  Future<PaginatedTexts> findAll({
    String? taskId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _client.dio.get('/text-collections', queryParameters: {
      if (taskId != null) 'taskId': taskId,
      if (status != null) 'status': status,
      'page': page,
      'pageSize': pageSize,
    });
    final data = res.data as Map<String, dynamic>;
    final list = data['items'] as List? ?? [];
    final items = list.map((e) => TextCollectionModel.fromJson(e as Map<String, dynamic>)).toList();
    final total = data['total'] as int? ?? items.length;
    return PaginatedTexts(items: items, total: total);
  }

  Future<TextCollectionModel> findOne(String id) async {
    final res = await _client.dio.get('/text-collections/$id');
    return TextCollectionModel.fromJson(res.data);
  }

  Future<TextCollectionModel> create(Map<String, dynamic> data) async {
    final res = await _client.dio.post('/text-collections', data: data);
    return TextCollectionModel.fromJson(res.data);
  }

  Future<Map<String, dynamic>> batchCreate(String taskId, List<String> texts, {String format = 'plain'}) async {
    final res = await _client.dio.post('/text-collections/batch', data: {
      'taskId': taskId,
      'texts': texts,
      'format': format,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assign({
    String? taskId,
    List<String>? textIds,
    String? assignedUserId,
    bool? autoAssign,
    int? assignCount,
    bool? copyForAssign,
  }) async {
    final res = await _client.dio.post('/text-collections/assign', data: {
      if (taskId != null) 'taskId': taskId,
      if (textIds != null) 'textIds': textIds,
      if (assignedUserId != null) 'assignedUserId': assignedUserId,
      if (autoAssign != null) 'autoAssign': autoAssign,
      if (assignCount != null) 'assignCount': assignCount,
      if (copyForAssign != null) 'copyForAssign': copyForAssign,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> recycle() async {
    final res = await _client.dio.post('/text-collections/recycle');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStats(String taskId) async {
    final res = await _client.dio.get('/text-collections/stats/$taskId');
    return res.data as Map<String, dynamic>;
  }
}

final textCollectionServiceProvider = Provider<TextCollectionService>((ref) {
  return TextCollectionService(ref.read(dioProvider));
});
