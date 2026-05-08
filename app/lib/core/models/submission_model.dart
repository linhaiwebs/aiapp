enum SubmissionStatus {
  draft,
  submitted,
  qcProcessing,   // backend: qc_processing
  qcPassed,       // backend: qc_passed
  qcFailed,       // backend: qc_failed
  pendingReview,  // backend: pending_review
  approved,
  rejected,
}

double _toDouble(dynamic v, [double defaults = 0]) {
  if (v == null) return defaults;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? defaults;
  return defaults;
}

int _toInt(dynamic v, [int defaults = 0]) {
  if (v == null) return defaults;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? defaults;
  return defaults;
}

class SubmissionModel {
  final String id;
  final String userId;
  final String taskId;
  final String claimId;
  final SubmissionStatus status;
  final Map<String, dynamic>? data;
  final List<String>? fileIds;
  final Map<String, dynamic>? annotations;
  final double? qcScore;
  final Map<String, dynamic>? qcReport;
  final String? rejectReason;
  final DateTime? reviewedAt;
  final String? reviewerId;
  final int retryCount;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubmissionModel({
    required this.id,
    required this.userId,
    required this.taskId,
    required this.claimId,
    this.status = SubmissionStatus.draft,
    this.data,
    this.fileIds,
    this.annotations,
    this.qcScore,
    this.qcReport,
    this.rejectReason,
    this.reviewedAt,
    this.reviewerId,
    this.retryCount = 0,
    this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubmissionModel.fromJson(Map<String, dynamic> json) => SubmissionModel(
        id: json['id'] as String,
        userId: json['userId'] as String,
        taskId: json['taskId'] as String,
        claimId: json['claimId'] as String,
        status: _parseSubmissionStatus(json['status'] as String?),
        data: json['data'] as Map<String, dynamic>?,
        fileIds: (json['fileIds'] as List?)?.cast<String>(),
        annotations: json['annotations'] as Map<String, dynamic>?,
        qcScore: _toDouble(json['qcScore']),
        qcReport: json['qcReport'] as Map<String, dynamic>?,
        rejectReason: json['rejectReason'] as String?,
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.parse(json['reviewedAt'] as String)
            : null,
        reviewerId: json['reviewerId'] as String?,
        retryCount: _toInt(json['retryCount']),
        submittedAt: json['submittedAt'] != null
            ? DateTime.parse(json['submittedAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  String get statusLabel => switch (status) {
        SubmissionStatus.draft => '草稿',
        SubmissionStatus.submitted => '已提交',
        SubmissionStatus.qcProcessing => '质检中',
        SubmissionStatus.qcPassed => '质检通过',
        SubmissionStatus.qcFailed => '质检未通过',
        SubmissionStatus.pendingReview => '待审核',
        SubmissionStatus.approved => '审核通过',
        SubmissionStatus.rejected => '已驳回',
      };
}

SubmissionStatus _parseSubmissionStatus(String? value) {
  if (value == null) return SubmissionStatus.draft;
  return switch (value) {
    'draft' => SubmissionStatus.draft,
    'submitted' => SubmissionStatus.submitted,
    'qc_processing' || 'qcProcessing' => SubmissionStatus.qcProcessing,
    'qc_passed' || 'qcPassed' => SubmissionStatus.qcPassed,
    'qc_failed' || 'qcFailed' => SubmissionStatus.qcFailed,
    'pending_review' || 'pendingReview' => SubmissionStatus.pendingReview,
    'approved' => SubmissionStatus.approved,
    'rejected' => SubmissionStatus.rejected,
    _ => SubmissionStatus.draft,
  };
}
