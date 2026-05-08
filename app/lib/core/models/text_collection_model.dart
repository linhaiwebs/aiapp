enum TextFormat { plain, sml }

enum TextStatus { pending, assigned, collecting, completed, qcFailed }

int _toInt(dynamic v, [int defaults = 0]) {
  if (v == null) return defaults;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? defaults;
  return defaults;
}

class TextCollectionModel {
  final String id;
  final String taskId;
  final String content;
  final TextFormat format;
  final TextStatus status;
  final String? assignedUserId;
  final String? assignedUserName;
  final DateTime? assignedAt;
  final String? templateId;
  final int sortOrder;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TextCollectionModel({
    required this.id,
    required this.taskId,
    required this.content,
    this.format = TextFormat.plain,
    this.status = TextStatus.pending,
    this.assignedUserId,
    this.assignedUserName,
    this.assignedAt,
    this.templateId,
    this.sortOrder = 0,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TextCollectionModel.fromJson(Map<String, dynamic> json) =>
      TextCollectionModel(
        id: json['id'] as String,
        taskId: json['taskId'] as String,
        content: json['content'] as String,
        format: _parseFormat(json['format'] as String?),
        status: _parseStatus(json['status'] as String?),
        assignedUserId: json['assignedUserId'] as String?,
        assignedUserName: json['assignedUserName'] as String?,
        assignedAt: json['assignedAt'] != null
            ? DateTime.parse(json['assignedAt'] as String)
            : null,
        templateId: json['templateId'] as String?,
        sortOrder: _toInt(json['sortOrder']),
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  String get statusLabel => switch (status) {
        TextStatus.pending => '待分配',
        TextStatus.assigned => '已分配',
        TextStatus.collecting => '采集中',
        TextStatus.completed => '已完成',
        TextStatus.qcFailed => '质检未通过',
      };

  String get formatLabel => format == TextFormat.sml ? 'SML' : '纯文本';
}

TextFormat _parseFormat(String? value) {
  if (value == null) return TextFormat.plain;
  return switch (value) {
    'sml' => TextFormat.sml,
    _ => TextFormat.plain,
  };
}

TextStatus _parseStatus(String? value) {
  if (value == null) return TextStatus.pending;
  return switch (value) {
    'pending' => TextStatus.pending,
    'assigned' => TextStatus.assigned,
    'collecting' => TextStatus.collecting,
    'completed' => TextStatus.completed,
    'qc_failed' => TextStatus.qcFailed,
    _ => TextStatus.pending,
  };
}
