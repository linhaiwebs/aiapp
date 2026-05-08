/// Helper: parse a value that may be String or num into double
double _toDouble(dynamic v, double defaults) {
  if (v == null) return defaults;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? defaults;
  return defaults;
}

/// Helper: parse a value that may be String or num into int
int _toInt(dynamic v, [int defaults = 0]) {
  if (v == null) return defaults;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? defaults;
  return defaults;
}

enum TaskType { audio, image, video, text }

enum TaskStatus {
  draft,
  published,
  inProgress,   // backend: in_progress
  completed,
  closed,
  archived,
}

enum TaskDifficulty { easy, medium, hard }

enum QcMethod { spotCheck, manualSpotCheck }

enum AudioFormat { wav, pcm }

enum AudioChannel { mono, stereo }

enum SampleRate { sr16000, sr44100, sr48000 }

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final TaskType type;
  final TaskStatus status;
  final TaskDifficulty difficulty;
  final double unitPrice;
  final int totalQuantity;
  final int claimedQuantity;
  final int completedQuantity;
  final int maxClaimsPerUser;
  final String? region;
  final String? language;
  final double minQualityScore;
  final double passRateRequirement;
  final DateTime? deadline;
  final String? instructions;
  final Map<String, dynamic>? qcConfig;
  final Map<String, dynamic>? typeConfig;
  final String? projectId;
  final String? categoryId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New fields
  final QcMethod? qcMethod;
  final AudioFormat? audioFormat;
  final AudioChannel? audioChannel;
  final SampleRate? sampleRate;
  final int? noiseLimit;
  final int? maxSpeechLength;
  final int? silencePadding;
  final bool assistRecognition;
  final bool silenceDetection;
  final bool voiceprintDetection;
  final bool gainDetection;
  final bool signalDetection;
  final bool allowMultipleClaims;
  final int reviewRounds;
  final int recycleHours;
  final int textAssignCount;
  final bool textCopyForAssign;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.status = TaskStatus.published,
    this.difficulty = TaskDifficulty.easy,
    required this.unitPrice,
    required this.totalQuantity,
    this.claimedQuantity = 0,
    this.completedQuantity = 0,
    this.maxClaimsPerUser = 1,
    this.region,
    this.language,
    this.minQualityScore = 60,
    this.passRateRequirement = 0,
    this.deadline,
    this.instructions,
    this.qcConfig,
    this.typeConfig,
    this.projectId,
    this.categoryId,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.qcMethod,
    this.audioFormat,
    this.audioChannel,
    this.sampleRate,
    this.noiseLimit,
    this.maxSpeechLength,
    this.silencePadding,
    this.assistRecognition = false,
    this.silenceDetection = false,
    this.voiceprintDetection = false,
    this.gainDetection = false,
    this.signalDetection = false,
    this.allowMultipleClaims = false,
    this.reviewRounds = 1,
    this.recycleHours = 48,
    this.textAssignCount = 0,
    this.textCopyForAssign = false,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        type: TaskType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => TaskType.audio,
        ),
        status: _parseTaskStatus(json['status'] as String?),
        difficulty: TaskDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => TaskDifficulty.easy,
        ),
        unitPrice: _toDouble(json['unitPrice'], 0),
        totalQuantity: _toInt(json['totalQuantity']),
        claimedQuantity: _toInt(json['claimedQuantity']),
        completedQuantity: _toInt(json['completedQuantity']),
        maxClaimsPerUser: _toInt(json['maxClaimsPerUser'], 1),
        region: json['region'] as String?,
        language: json['language'] as String?,
        minQualityScore: _toDouble(json['minQualityScore'], 60),
        passRateRequirement: _toDouble(json['passRateRequirement'], 0),
        deadline: json['deadline'] != null
            ? DateTime.parse(json['deadline'] as String)
            : null,
        instructions: json['instructions'] as String?,
        qcConfig: json['qcConfig'] as Map<String, dynamic>?,
        typeConfig: json['typeConfig'] as Map<String, dynamic>?,
        projectId: json['projectId'] as String?,
        categoryId: json['categoryId'] as String?,
        sortOrder: _toInt(json['sortOrder']),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        qcMethod: _parseQcMethod(json['qcMethod'] as String?),
        audioFormat: _parseAudioFormat(json['audioFormat'] as String?),
        audioChannel: _parseAudioChannel(json['audioChannel'] as String?),
        sampleRate: _parseSampleRate(_toInt(json['sampleRate'], -1) == -1 ? null : _toInt(json['sampleRate'])),
        noiseLimit: _toInt(json['noiseLimit'], 0) == 0 ? null : _toInt(json['noiseLimit']),
        maxSpeechLength: _toInt(json['maxSpeechLength'], 0) == 0 ? null : _toInt(json['maxSpeechLength']),
        silencePadding: _toInt(json['silencePadding'], 0) == 0 ? null : _toInt(json['silencePadding']),
        assistRecognition: json['assistRecognition'] as bool? ?? false,
        silenceDetection: json['silenceDetection'] as bool? ?? false,
        voiceprintDetection: json['voiceprintDetection'] as bool? ?? false,
        gainDetection: json['gainDetection'] as bool? ?? false,
        signalDetection: json['signalDetection'] as bool? ?? false,
        allowMultipleClaims: json['allowMultipleClaims'] as bool? ?? false,
        reviewRounds: _toInt(json['reviewRounds'], 1),
        recycleHours: _toInt(json['recycleHours'], 48),
        textAssignCount: _toInt(json['textAssignCount']),
        textCopyForAssign: json['textCopyForAssign'] as bool? ?? false,
      );

  int get remainingQuantity => totalQuantity - claimedQuantity;

  String get typeLabel => switch (type) {
        TaskType.audio => '音频',
        TaskType.image => '图像',
        TaskType.video => '视频',
        TaskType.text => '文本',
      };

  String get typeUnit => switch (type) {
        TaskType.audio => '条',
        TaskType.image => '图',
        TaskType.video => '条',
        TaskType.text => '条',
      };

  String get statusLabel => switch (status) {
        TaskStatus.draft => '草稿',
        TaskStatus.published => '已发布',
        TaskStatus.inProgress => '进行中',
        TaskStatus.completed => '已完成',
        TaskStatus.closed => '已关闭',
        TaskStatus.archived => '已归档',
      };

  String get priceLabel => '¥${unitPrice.toStringAsFixed(unitPrice.truncateToDouble() == unitPrice ? 0 : 2)}/$typeUnit';

  String get audioConfigSummary {
    final parts = <String>[];
    if (audioFormat != null) parts.add(audioFormat!.name.toUpperCase());
    if (audioChannel != null) parts.add(audioChannel == AudioChannel.mono ? '单声道' : '双声道');
    if (sampleRate != null) parts.add('${sampleRate!.label}Hz');
    return parts.isEmpty ? '默认' : parts.join(' · ');
  }
}

TaskStatus _parseTaskStatus(String? value) {
  if (value == null) return TaskStatus.published;
  return switch (value) {
    'draft' => TaskStatus.draft,
    'published' => TaskStatus.published,
    'in_progress' || 'inProgress' => TaskStatus.inProgress,
    'completed' => TaskStatus.completed,
    'closed' => TaskStatus.closed,
    'archived' => TaskStatus.archived,
    _ => TaskStatus.published,
  };
}

QcMethod? _parseQcMethod(String? value) {
  if (value == null) return null;
  return switch (value) {
    'spot_check' => QcMethod.spotCheck,
    'manual_spot_check' => QcMethod.manualSpotCheck,
    _ => null,
  };
}

AudioFormat? _parseAudioFormat(String? value) {
  if (value == null) return null;
  return switch (value) {
    'wav' => AudioFormat.wav,
    'pcm' => AudioFormat.pcm,
    _ => null,
  };
}

AudioChannel? _parseAudioChannel(String? value) {
  if (value == null) return null;
  return switch (value) {
    'mono' => AudioChannel.mono,
    'stereo' => AudioChannel.stereo,
    _ => null,
  };
}

SampleRate? _parseSampleRate(int? value) {
  if (value == null) return null;
  return switch (value) {
    16000 => SampleRate.sr16000,
    44100 => SampleRate.sr44100,
    48000 => SampleRate.sr48000,
    _ => null,
  };
}

extension SampleRateLabel on SampleRate {
  String get label => switch (this) {
    SampleRate.sr16000 => '16000',
    SampleRate.sr44100 => '44100',
    SampleRate.sr48000 => '48000',
  };
}
