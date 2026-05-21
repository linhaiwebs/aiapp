import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/text_collection_model.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/services/text_collection_service.dart';
import '../../../core/services/submission_service.dart';
import '../../../core/services/file_service.dart';
import '../../../core/network/dio_client.dart';
import '../widgets/audio_check_dialog.dart';

class TextCarouselPage extends ConsumerStatefulWidget {
  final String claimId;
  const TextCarouselPage({super.key, required this.claimId});

  @override
  ConsumerState<TextCarouselPage> createState() => _TextCarouselPageState();
}

class _TextCarouselPageState extends ConsumerState<TextCarouselPage> {
  List<TextCollectionModel> _texts = [];
  TaskClaimModel? _claim;
  bool _isLoading = true;
  bool _showInstructions = false;

  // Recording state
  bool _isRecording = false;
  String? _recordingTextId;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // Completed map: textId -> fileId
  Map<String, String> _recordingFileIds = {};
  Map<String, double> _durations = {};

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final claims = await ref.read(taskServiceProvider).getMyClaims();
      final claim = claims.where((c) => c.id == widget.claimId).firstOrNull;
      final texts = await ref.read(textCollectionServiceProvider).getMyTexts(widget.claimId);

      final fileIds = <String, String>{};
      final durations = <String, double>{};
      for (final t in texts) {
        if (t.metadata != null && t.metadata!['fileId'] is String) {
          fileIds[t.id] = t.metadata!['fileId'] as String;
        }
        if (t.metadata != null && t.metadata!['duration'] is num) {
          durations[t.id] = (t.metadata!['duration'] as num).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _claim = claim;
          _texts = texts;
          _recordingFileIds = fileIds;
          _durations = durations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _taskType => _claim?.taskType ?? 'text';
  bool get _allDone => _texts.isNotEmpty && _texts.every((t) => _recordingFileIds.containsKey(t.id));
  int get _doneCount => _recordingFileIds.length;

  // ─── Recording ──────────────────────────────────────────────

  Future<void> _startRecording(String textId) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      final granted = await Permission.microphone.request();
      if (!granted.isGranted) return;
    }

    // Pre-recording audio check (if detection features are enabled)
    final needsCheck = _claim?.signalDetection == true ||
        _claim?.gainDetection == true ||
        _claim?.silenceDetection == true;
    if (needsCheck) {
      final result = await showAudioCheckDialog(
        context: context,
        checkSignal: _claim?.signalDetection ?? false,
        checkGain: _claim?.gainDetection ?? false,
        checkSilence: _claim?.silenceDetection ?? false,
        noiseLimitDb: _claim?.noiseLimit ?? 60,
      );
      if (result == null || !result.allPassed) return;
    }

    // Start actual recording
    final config = const RecordConfig(encoder: AudioEncoder.opus, bitRate: 64000, numChannels: 1);
    final path = kIsWeb
        ? 'rec_${DateTime.now().millisecondsSinceEpoch}.opus'
        : '${(await getTemporaryDirectory()).path}/rec_${DateTime.now().millisecondsSinceEpoch}.opus';
    await _recorder.start(config, path: path);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingDuration += const Duration(seconds: 1));
    });
    setState(() {
      _isRecording = true;
      _recordingTextId = textId;
    });
  }

  Future<void> _stopRecording(String textId) async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path == null || !mounted) return;

    final dur = _recordingDuration;
    setState(() {
      _isRecording = false;
      _recordingTextId = null;
      _recordingDuration = Duration.zero;
    });

    // Upload
    Map<String, dynamic> fileEntity;
    if (kIsWeb) {
      final bytes = (await Dio().get(path, options: Options(responseType: ResponseType.bytes))).data as Uint8List;
      fileEntity = await ref.read(fileServiceProvider).simpleUploadBytes(
        fileName: 'rec_opus_${DateTime.now().millisecondsSinceEpoch}.opus',
        bytes: bytes,
        taskId: _claim?.taskId,
        taskType: 'audio',
      );
    } else {
      fileEntity = await ref.read(fileServiceProvider).simpleUpload(path,
        taskId: _claim?.taskId,
        taskType: 'audio',
      );
    }

    if (!mounted) return;
    final fileId = fileEntity['id'] as String;

    await ref.read(textCollectionServiceProvider).updateStatus(
      textId, 'completed',
      fileId: fileId,
    );

    if (!mounted) return;
    setState(() {
      _recordingFileIds[textId] = fileId;
      _durations[textId] = dur.inMilliseconds / 1000.0;
    });
  }

  // ─── Re-record ──────────────────────────────────────────────

  Future<void> _reRecord(String textId) async {
    setState(() {
      _recordingFileIds.remove(textId);
      _durations.remove(textId);
    });
    try {
      await ref.read(textCollectionServiceProvider).updateStatus(textId, 'assigned');
    } catch (_) {}
  }

  // ─── Playback ───────────────────────────────────────────────

  Future<void> _playRecording(String textId) async {
    final fileId = _recordingFileIds[textId];
    if (fileId == null) return;
    final serverBase = ref.read(dioProvider).dio.options.baseUrl;
    final url = '$serverBase/files/$fileId/stream';
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  // ─── Submit ─────────────────────────────────────────────────

  Future<void> _submitAll() async {
    if (!_allDone) return;
    setState(() => _isSubmitting = true);

    try {
      final textResults = _texts.where((t) => _recordingFileIds.containsKey(t.id)).map((t) {
        return {
          'textId': t.id,
          'fileId': _recordingFileIds[t.id],
          'duration': _durations[t.id] ?? 0,
        };
      }).toList();

      final fileIds = textResults.map((r) => r['fileId'] as String).toList();

      await ref.read(submissionServiceProvider).create(
        claimId: widget.claimId,
        data: {
          'textResults': textResults,
          'totalCount': _texts.length,
        },
        fileIds: fileIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提交成功'), backgroundColor: AppColors.secondary),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _claim?.taskTitle ?? (_taskType == 'audio' ? '语音采集' : '文本采集'),
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        ),
        actions: [
          if (_texts.isNotEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16.w),
                child: Text(
                  '$_doneCount/${_texts.length}',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _texts.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    // Progress bar
                    LinearProgressIndicator(
                      value: _doneCount / _texts.length,
                      minHeight: 3.h,
                      backgroundColor: AppColors.outlineVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    // Instructions (collapsible)
                    _buildInstructions(),
                    // Card carousel
                    Expanded(
                      child: PageView.builder(
                        scrollDirection: Axis.vertical,
                        physics: _isRecording
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        itemCount: _texts.length,
                        itemBuilder: (ctx, i) => _buildCard(_texts[i], i),
                      ),
                    ),
                    // Bottom submit bar
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildInstructions() {
    final instructions = _claim?.taskInstructions;
    if (instructions == null || instructions.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showInstructions = !_showInstructions),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            color: AppColors.surfaceContainerHigh,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16.sp, color: AppColors.primary),
                SizedBox(width: 6.w),
                Text('任务说明', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppColors.primary)),
                const Spacer(),
                Icon(
                  _showInstructions ? Icons.expand_less : Icons.expand_more,
                  size: 20.sp,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_showInstructions)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            color: AppColors.surfaceContainer,
            child: Text(
              instructions,
              style: TextStyle(fontSize: 13.sp, color: AppColors.onSurfaceVariant, height: 1.6),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(TextCollectionModel text, int index) {
    final isDone = _recordingFileIds.containsKey(text.id);
    final isCurrentRecording = _recordingTextId == text.id;
    final dur = _durations[text.id];

    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Index badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.secondary.withValues(alpha: 0.1)
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: isDone
                  ? Border.all(color: AppColors.secondary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDone) ...[
                  Icon(Icons.check_circle, size: 16.sp, color: AppColors.secondary),
                  SizedBox(width: 6.w),
                  Text(
                    '已完成',
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.secondary),
                  ),
                ] else ...[
                  Text(
                    '第 ${index + 1}/${_texts.length} 条',
                    style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 20.h),
          // Main text card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(28.w),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.surfaceContainerLowest
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isDone
                    ? AppColors.secondary.withValues(alpha: 0.25)
                    : isCurrentRecording
                        ? AppColors.error.withValues(alpha: 0.35)
                        : AppColors.outlineVariant,
                width: isCurrentRecording ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text.content,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isDone && dur != null) ...[
                  SizedBox(height: 16.h),
                  Text(
                    '录音时长 ${dur.toStringAsFixed(1)} 秒',
                    style: TextStyle(fontSize: 13.sp, color: AppColors.secondary),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 28.h),
          // Recording timer
          if (isCurrentRecording) ...[
            Text(
              '${_recordingDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 36.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _taskType == 'audio' ? '录音中...录完点击停止按钮' : '朗读中...读取完毕后点击停止',
              style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant),
            ),
            SizedBox(height: 16.h),
          ] else ...[
            SizedBox(height: 8.h),
          ],
          // Action buttons
          if (!isCurrentRecording)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isDone)
                  _CircleButton(
                    onTap: () => _startRecording(text.id),
                    icon: Icons.mic,
                    color: AppColors.primary,
                    label: _taskType == 'audio' ? '朗读录音' : '录音',
                  ),
                if (isDone) ...[
                  _CircleButton(
                    onTap: () => _playRecording(text.id),
                    icon: Icons.play_arrow,
                    color: AppColors.secondary,
                    size: 52.sp,
                    label: '试听',
                  ),
                  SizedBox(width: 20.w),
                  _CircleButton(
                    onTap: () => _reRecord(text.id),
                    icon: Icons.refresh,
                    color: AppColors.orange,
                    size: 52.sp,
                    label: '重录',
                  ),
                ],
              ],
            )
          else
            _CircleButton(
              onTap: () => _stopRecording(text.id),
              icon: Icons.stop,
              color: AppColors.error,
              size: 72.sp,
              label: '停止',
              isPulsing: true,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          // Progress dots
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (int i = 0; i < _texts.length && i < 40; i++)
                      Container(
                        width: 6.w,
                        height: 6.w,
                        margin: EdgeInsets.only(right: 3.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _recordingFileIds.containsKey(_texts[i].id)
                              ? AppColors.secondary
                              : AppColors.outlineVariant,
                        ),
                      ),
                    if (_texts.length > 40)
                      Text(' ...', style: TextStyle(fontSize: 10.sp, color: AppColors.outline)),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  _taskType == 'audio' ? '已录制 $_doneCount/${_texts.length} 条' : '已录制 $_doneCount/${_texts.length} 条',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44.h,
            child: ElevatedButton(
              onPressed: _allDone && !_isSubmitting ? _submitAll : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _allDone ? AppColors.primary : AppColors.surfaceContainerHigh,
                foregroundColor: _allDone ? AppColors.onPrimary : AppColors.outline,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(
                      _allDone ? '提交全部' : '未全部完成 ($_doneCount/${_texts.length})',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56.sp, color: AppColors.outline.withValues(alpha: 0.4)),
          SizedBox(height: 16.h),
          Text('暂无分配到的条目', style: TextStyle(fontSize: 15.sp, color: AppColors.outline)),
          SizedBox(height: 8.h),
          Text('请确认任务是否已分配采集内容', style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─── Circle Button ──────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Color color;
  final double? size;
  final bool isPulsing;
  final String? label;

  const _CircleButton({
    required this.onTap,
    required this.icon,
    required this.color,
    this.size,
    this.isPulsing = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final s = size ?? 60.sp;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isPulsing
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Icon(icon, color: Colors.white, size: s * 0.5),
          ),
          if (label != null) ...[
            SizedBox(height: 6.h),
            Text(
              label!,
              style: TextStyle(fontSize: 11.sp, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}
