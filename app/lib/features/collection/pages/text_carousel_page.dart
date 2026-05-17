import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/text_collection_model.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/services/text_collection_service.dart';
import '../../../core/services/submission_service.dart';
import '../../../core/services/file_service.dart';
import '../../../core/network/dio_client.dart';

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
  int _currentIndex = 0;

  // Recording state
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // Completed map: textId -> fileId
  Map<String, String> _recordingFileIds = {};
  Map<String, double> _durations = {};

  bool _isSubmitting = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final claims = await ref.read(taskServiceProvider).getMyClaims();
      final claim = claims.where((c) => c.id == widget.claimId).firstOrNull;
      final texts = await ref.read(textCollectionServiceProvider).getMyTexts(widget.claimId);

      // 恢复已完成条目
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

  bool get _allDone => _texts.isNotEmpty && _texts.every((t) => _recordingFileIds.containsKey(t.id));
  int get _doneCount => _recordingFileIds.length;

  // ─── Recording ──────────────────────────────────────────────────

  Future<void> _toggleRecording(String textId) async {
    if (_isRecording) {
      await _stopRecording(textId);
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      final granted = await Permission.microphone.request();
      if (!granted.isGranted) return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingDuration += const Duration(seconds: 1));
    });
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording(String textId) async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path == null || !mounted) return;

    final dur = _recordingDuration;
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    // Upload
    final fileEntity = await ref.read(fileServiceProvider).simpleUpload(path,
      taskId: _claim?.taskId,
      taskType: 'audio',
    );

    if (!mounted) return;
    final fileId = fileEntity['id'] as String;

    // Update server
    await ref.read(textCollectionServiceProvider).updateStatus(
      textId, 'completed',
      fileId: fileId,
    );

    if (!mounted) return;
    setState(() {
      _recordingFileIds[textId] = fileId;
      _durations[textId] = dur.inMilliseconds / 1000.0;
    });

    // Auto-advance
    if (_currentIndex < _texts.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ─── Re-record ──────────────────────────────────────────────────

  Future<void> _reRecord(String textId) async {
    setState(() {
      _recordingFileIds.remove(textId);
      _durations.remove(textId);
      _recordingDuration = Duration.zero;
    });
    // Also reset server-side status
    try {
      await ref.read(textCollectionServiceProvider).updateStatus(textId, 'assigned');
    } catch (_) {}
  }

  // ─── Playback ───────────────────────────────────────────────────

  Future<void> _playRecording(String textId) async {
    final fileId = _recordingFileIds[textId];
    if (fileId == null) return;
    final serverBase = ref.read(dioProvider).dio.options.baseUrl;
    final url = '$serverBase/files/$fileId/stream';
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  // ─── Submit ─────────────────────────────────────────────────────

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

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _claim?.taskTitle ?? '文本采集',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        ),
        actions: [
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
          ? _buildSkeleton()
          : _texts.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    // Progress bar
                    if (_texts.isNotEmpty)
                      LinearProgressIndicator(
                        value: _doneCount / _texts.length,
                        minHeight: 3.h,
                        backgroundColor: AppColors.outlineVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    // Carousel
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: _isRecording
                            ? const NeverScrollableScrollPhysics()
                            : const BouncingScrollPhysics(),
                        itemCount: _texts.length,
                        onPageChanged: (i) => setState(() => _currentIndex = i),
                        itemBuilder: (ctx, i) => _buildTextCard(_texts[i]),
                      ),
                    ),
                    // Bottom bar
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  Widget _buildTextCard(TextCollectionModel text) {
    final isDone = _recordingFileIds.containsKey(text.id);
    final dur = _durations[text.id];

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          SizedBox(height: 16.h),
          // Index indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '第 ${_currentIndex + 1} 条',
              style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant),
            ),
          ),
          SizedBox(height: 20.h),
          // Text card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: isDone ? AppColors.secondary.withValues(alpha: 0.3) : AppColors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
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
                if (isDone) ...[
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 18.sp, color: AppColors.secondary),
                      SizedBox(width: 6.w),
                      Text(
                        '已完成${dur != null ? ' · ${dur.toStringAsFixed(1)}秒' : ''}',
                        style: TextStyle(fontSize: 13.sp, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24.h),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Record button
              _CircleButton(
                onTap: _isRecording ? () => _stopRecording(text.id) : () => _toggleRecording(text.id),
                icon: _isRecording ? Icons.stop : Icons.mic,
                color: _isRecording ? AppColors.error : AppColors.primary,
                isPulsing: _isRecording,
              ),
              SizedBox(width: 24.w),
              // Play button (only when done)
              if (isDone)
                _CircleButton(
                  onTap: () => _playRecording(text.id),
                  icon: Icons.play_arrow,
                  color: AppColors.secondary,
                  size: 48.sp,
                ),
              if (isDone) SizedBox(width: 24.w),
              // Re-record button (only when done)
              if (isDone)
                _CircleButton(
                  onTap: () => _reRecord(text.id),
                  icon: Icons.refresh,
                  color: AppColors.orange,
                  size: 48.sp,
                ),
            ],
          ),
          // Recording timer
          if (_isRecording) ...[
            SizedBox(height: 16.h),
            Text(
              '${_recordingDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '朗读中...读完点击停止按钮',
              style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant),
            ),
          ],
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
                    for (int i = 0; i < _texts.length && i < 30; i++)
                      Container(
                        width: 6.w,
                        height: 6.w,
                        margin: EdgeInsets.only(right: 3.w),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _recordingFileIds.containsKey(_texts[i].id)
                              ? AppColors.secondary
                              : i == _currentIndex
                                  ? AppColors.primary
                                  : AppColors.outlineVariant,
                        ),
                      ),
                    if (_texts.length > 30)
                      Text(' ...', style: TextStyle(fontSize: 10.sp, color: AppColors.outline)),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '已录制 $_doneCount/${_texts.length} 条',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Submit button
          SizedBox(
            height: 40.h,
            child: ElevatedButton(
              onPressed: _allDone && !_isSubmitting ? _submitAll : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                disabledBackgroundColor: AppColors.surfaceContainerHigh,
                disabledForegroundColor: AppColors.outline,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(
                      _allDone ? '提交全部' : '未全部完成',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty / Skeleton ──────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56.sp, color: AppColors.outline.withValues(alpha: 0.4)),
          SizedBox(height: 16.h),
          Text('暂无分配到的文本', style: TextStyle(fontSize: 15.sp, color: AppColors.outline)),
          SizedBox(height: 8.h),
          Text('请确认任务是否已分配', style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16.h),
          Text('加载文本中...', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)),
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

  const _CircleButton({
    required this.onTap,
    required this.icon,
    required this.color,
    this.size,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = size ?? 60.sp;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
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
    );
  }
}
