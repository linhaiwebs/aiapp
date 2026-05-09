enum UserRole { member, leader, superAdmin }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.member => '会员',
        UserRole.leader => '团长',
        UserRole.superAdmin => '超级管理员',
      };
}

enum UserStatus { active, inactive, blacklisted }

UserRole _parseRole(String? value) {
  if (value == null) return UserRole.member;
  return switch (value) {
    'leader' => UserRole.leader,
    'super_admin' || 'superAdmin' => UserRole.superAdmin,
    _ => UserRole.member,
  };
}

/// Helper: parse a value that may be String or num into double
double _toDouble(dynamic v, double defaults) {
  if (v == null) return defaults;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? defaults;
  return defaults;
}

class UserModel {
  final String id;
  final String phone;
  final String? nickname;
  final String? avatar;
  final UserRole role;
  final UserStatus status;
  final double qualityScore;
  final double balance;
  final double frozenBalance;
  final double totalEarnings;
  final bool isRealNameVerified;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.phone,
    this.nickname,
    this.avatar,
    this.role = UserRole.member,
    this.status = UserStatus.active,
    this.qualityScore = 100,
    this.balance = 0,
    this.frozenBalance = 0,
    this.totalEarnings = 0,
    this.isRealNameVerified = false,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        phone: json['phone'] as String,
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
        role: _parseRole(json['role'] as String?),
        status: UserStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => UserStatus.active,
        ),
        qualityScore: _toDouble(json['qualityScore'], 100),
        balance: _toDouble(json['balance'], 0),
        frozenBalance: _toDouble(json['frozenBalance'], 0),
        totalEarnings: _toDouble(json['totalEarnings'], 0),
        isRealNameVerified: json['isRealNameVerified'] as bool? ?? false,
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.parse(json['lastLoginAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  String get displayName => nickname ?? phone.replaceRange(3, 7, '****');

  String get roleLabel => switch (role) {
        UserRole.member => '会员',
        UserRole.leader => '团长',
        UserRole.superAdmin => '超级管理员',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'nickname': nickname,
        'avatar': avatar,
        'role': role.name,
        'status': status.name,
        'qualityScore': qualityScore,
        'balance': balance,
        'frozenBalance': frozenBalance,
        'totalEarnings': totalEarnings,
        'isRealNameVerified': isRealNameVerified,
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
