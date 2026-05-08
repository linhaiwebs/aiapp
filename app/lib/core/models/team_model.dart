class TeamModel {
  final String id;
  final String name;
  final String? description;
  final String? leaderId;
  final String? leaderName;
  final String joinCode;
  final bool isActive;
  final List<TeamMemberModel> members;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeamModel({
    required this.id,
    required this.name,
    this.description,
    this.leaderId,
    this.leaderName,
    this.joinCode = '',
    this.isActive = true,
    this.members = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeamModel.fromJson(Map<String, dynamic> json) => TeamModel(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        leaderId: json['leaderId'] as String?,
        leaderName: json['leaderName'] as String?,
        joinCode: (json['joinCode'] as String?) ?? '',
        isActive: json['isActive'] as bool? ?? true,
        members: (json['members'] as List?)
                ?.map((e) => TeamMemberModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class TeamMemberModel {
  final String id;
  final String teamId;
  final String userId;
  final String? userName;
  final String? phone;
  final String? email;
  final String role;
  final DateTime createdAt;

  const TeamMemberModel({
    required this.id,
    required this.teamId,
    required this.userId,
    this.userName,
    this.phone,
    this.email,
    this.role = 'member',
    required this.createdAt,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) => TeamMemberModel(
        id: json['id'] as String,
        teamId: json['teamId'] as String,
        userId: json['userId'] as String,
        userName: json['userName'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        role: json['role'] as String? ?? 'member',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String get displayLabel => userName ?? phone ?? email ?? userId.substring(0, 8);
  String get roleLabel => role == 'leader' ? '负责人' : '成员';
}
