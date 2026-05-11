import '../models/team_model.dart';
import '../network/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TeamService {
  final DioClient _client;
  TeamService(this._client);

  Future<List<TeamModel>> findAll({int page = 1, int pageSize = 20, String? keyword}) async {
    final res = await _client.dio.get('/teams', queryParameters: {
      if (keyword != null) 'keyword': keyword,
      'page': page,
      'pageSize': pageSize,
    });
    final list = res.data['items'] ?? res.data as List;
    return (list as List).map((e) => TeamModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TeamModel> findOne(String id) async {
    final res = await _client.dio.get('/teams/$id');
    return TeamModel.fromJson(res.data);
  }

  Future<TeamModel> create(Map<String, dynamic> data) async {
    final res = await _client.dio.post('/teams', data: data);
    return TeamModel.fromJson(res.data);
  }

  Future<TeamModel> update(String id, Map<String, dynamic> data) async {
    final res = await _client.dio.patch('/teams/$id', data: data);
    return TeamModel.fromJson(res.data);
  }

  Future<void> remove(String id) async {
    await _client.dio.delete('/teams/$id');
  }

  Future<List<TeamMemberModel>> getMembers(String teamId) async {
    final res = await _client.dio.get('/teams/$teamId/members');
    final list = res.data is List ? res.data : res.data['items'] ?? [];
    return (list as List).map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TeamMemberModel> addMember(String teamId, Map<String, dynamic> data) async {
    final res = await _client.dio.post('/teams/$teamId/members', data: data);
    return TeamMemberModel.fromJson(res.data);
  }

  Future<void> removeMember(String teamId, String memberId) async {
    await _client.dio.delete('/teams/$teamId/members/$memberId');
  }

  Future<TeamMemberModel> inviteMember(String teamId, Map<String, dynamic> data) async {
    final res = await _client.dio.post('/teams/$teamId/invite', data: data);
    return TeamMemberModel.fromJson(res.data);
  }

  Future<TeamMemberModel> joinByCode(String joinCode) async {
    final res = await _client.dio.post('/teams/join', data: {'joinCode': joinCode});
    return TeamMemberModel.fromJson(res.data);
  }

  Future<List<TeamModel>> getMyTeams() async {
    final res = await _client.dio.get('/teams', queryParameters: {'pageSize': 100});
    final list = res.data['items'] ?? res.data as List;
    return (list as List).map((e) => TeamModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<TeamMemberModel>> getPendingMembers(String teamId) async {
    final res = await _client.dio.get('/teams/$teamId/members/pending');
    final list = res.data is List ? res.data : res.data['items'] ?? [];
    return (list as List).map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TeamMemberModel> approveMember(String teamId, String memberId) async {
    final res = await _client.dio.post('/teams/$teamId/members/$memberId/approve');
    return TeamMemberModel.fromJson(res.data);
  }

  Future<TeamMemberModel> rejectMember(String teamId, String memberId, {String? reason}) async {
    final res = await _client.dio.post('/teams/$teamId/members/$memberId/reject', data: {
      if (reason != null) 'reason': reason,
    });
    return TeamMemberModel.fromJson(res.data);
  }
}

final teamServiceProvider = Provider<TeamService>((ref) {
  return TeamService(ref.read(dioProvider));
});
