/// Helper: parse a value that may be String or num into int
int _toInt(dynamic v, [int defaults = 0]) {
  if (v == null) return defaults;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? defaults;
  return defaults;
}

enum ClaimStatus {
  pendingApproval, // backend: pending_approval
  claimed,
  inProgress,   // backend: in_progress
  submitted,
  completed,
  abandoned,
  expired,
  rejected,
}

class TaskClaimModel {
  final String id;
  final String userId;
  final String taskId;
  final ClaimStatus status;
  final DateTime? claimedAt;
  final DateTime? deadline;
  final DateTime? submittedAt;
  final DateTime? completedAt;
  final int submittedCount;
  final int passedCount;
  final int rejectedCount;
  final String? taskType; // from joined task: audio, text, image, video
  final String? taskTitle; // from joined task
  final String? taskDescription; // from joined task
  final String? taskInstructions; // from joined task
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskClaimModel({
    required this.id,
    required this.userId,
    required this.taskId,
    this.status = ClaimStatus.claimed,
    this.claimedAt,
    this.deadline,
    this.submittedAt,
    this.completedAt,
    this.submittedCount = 0,
    this.passedCount = 0,
    this.rejectedCount = 0,
    this.taskType,
    this.taskTitle,
    this.taskDescription,
    this.taskInstructions,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskClaimModel.fromJson(Map<String, dynamic> json) => TaskClaimModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        taskId: json['taskId'] as String,
        status: _parseClaimStatus(json['status'] as String?),
        claimedAt: json['claimedAt'] != null
            ? DateTime.parse(json['claimedAt'] as String)
            : null,
        deadline: json['deadline'] != null
            ? DateTime.parse(json['deadline'] as String)
            : null,
        submittedAt: json['submittedAt'] != null
            ? DateTime.parse(json['submittedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        submittedCount: _toInt(json['submittedCount']),
        passedCount: _toInt(json['passedCount']),
        rejectedCount: _toInt(json['rejectedCount']),
        taskType: json['task']?['type'] as String?,
        taskTitle: json['task']?['title'] as String?,
        taskDescription: json['task']?['description'] as String?,
        taskInstructions: json['task']?['instructions'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  String get statusLabel => switch (status) {
        ClaimStatus.pendingApproval => '待审批',
        ClaimStatus.claimed => '已领取',
        ClaimStatus.inProgress => '采集中',
        ClaimStatus.submitted => '已提交',
        ClaimStatus.completed => '已完成',
        ClaimStatus.abandoned => '已放弃',
        ClaimStatus.expired => '已过期',
        ClaimStatus.rejected => '已拒绝',
      };
}

ClaimStatus _parseClaimStatus(String? value) {
  if (value == null) return ClaimStatus.claimed;
  return switch (value) {
    'pending_approval' => ClaimStatus.pendingApproval,
    'claimed' => ClaimStatus.claimed,
    'in_progress' || 'inProgress' => ClaimStatus.inProgress,
    'submitted' => ClaimStatus.submitted,
    'completed' => ClaimStatus.completed,
    'abandoned' => ClaimStatus.abandoned,
    'expired' => ClaimStatus.expired,
    'rejected' => ClaimStatus.rejected,
    _ => ClaimStatus.claimed,
  };
}
