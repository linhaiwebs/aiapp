import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/services/submission_service.dart';
import '../../../core/services/file_service.dart';
import '../../../core/network/dio_client.dart';

class CollectionWorkbenchPage extends ConsumerStatefulWidget {
  final String claimId;
  const CollectionWorkbenchPage({super.key, required this.claimId});

  @override
  ConsumerState<CollectionWorkbenchPage> createState() => _CollectionWorkbenchPageState();
}

class _CollectionWorkbenchPageState extends ConsumerState<CollectionWorkbenchPage> {
  TaskClaimModel? _claim;
  bool _isLoading = true;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  final List<_CollectedFile> _collectedFiles = [];
  bool _isSubmitting = false;
  bool _isUploading = false;

  final AudioRecorder _recorder = AudioRecorder();

  @override
  void initState() {
    super.initState();
    _loadClaim();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _loadClaim() async {
    try {
      final claims = await ref.read(taskServiceProvider).getMyClaims();
      final claim = claims.where((c) => c.id == widget.claimId).firstOrNull;
      if (mounted) {
        setState(() { _claim = claim; _isLoading = false; });
        if (claim == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('任务领取记录未找到'), backgroundColor: AppColors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── Recording ────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要麦克风权限才能录音'), backgroundColor: AppColors.orange),
            );
          }
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() { _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1); });
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音启动失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          final duration = _recordingDuration;
          setState(() { _isRecording = false; _recordingDuration = Duration.zero; });
          await _uploadFile(path, source: '录音_${_collectedFiles.length + 1}.wav', duration: duration);
          return;
        }
      }
      setState(() { _isRecording = false; _recordingDuration = Duration.zero; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音停止失败: $e'), backgroundColor: AppColors.error),
        );
      }
      setState(() { _isRecording = false; _recordingDuration = Duration.zero; });
    }
  }

  // ─── File Upload ──────────────────────────────────────────────

  Future<void> _pickAndUploadAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            await _uploadFile(file.path!, source: file.name);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _uploadFile(String filePath, {String source = '', Duration? duration}) async {
    setState(() => _isUploading = true);
    try {
      final result = await ref.read(fileServiceProvider).simpleUpload(
        filePath,
        taskId: _claim?.taskId,
        taskType: 'audio',
      );
      final fileId = result['id'] as String;
      final file = File(filePath);
      final size = await file.length();
      if (mounted) {
        setState(() {
          _collectedFiles.add(_CollectedFile(
            id: fileId,
            name: source.isNotEmpty ? source : filePath.split('/').last,
            size: size,
            duration: duration,
            type: duration != null ? _FileType.recorded : _FileType.uploaded,
          ));
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$source 上传成功'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() { _collectedFiles.removeAt(index); });
  }

  void _previewFile(String fileId, String name) {
    final serverBase = ref.read(dioProvider).dio.options.baseUrl;
    final url = '$serverBase/files/$fileId/stream';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.5,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.play_circle_outline, color: Colors.white54, size: 48),
            SizedBox(height: 16.h),
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
            SizedBox(height: 8.h),
            Text(url, style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
        ),
      ),
    );
  }

  // ─── Submit ───────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_collectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先采集数据'), backgroundColor: AppColors.orange),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final fileIds = _collectedFiles.map((f) => f.id).toList();
      final totalDuration = _collectedFiles
          .where((f) => f.duration != null)
          .fold<int>(0, (sum, f) => sum + f.duration!.inSeconds);

      await ref.read(submissionServiceProvider).create(
        claimId: widget.claimId,
        data: {
          'duration': totalDuration,
          'collectedCount': _collectedFiles.length,
          'fileNames': _collectedFiles.map((f) => f.name).toList(),
        },
        fileIds: fileIds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提交成功，等待审核'), backgroundColor: AppColors.secondary),
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

  String get _durationLabel {
    final h = _recordingDuration.inHours.toString().padLeft(2, '0');
    final m = (_recordingDuration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_recordingDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canSubmit => _collectedFiles.isNotEmpty && !_isSubmitting && !_isUploading;

  int get _totalRequired => 10; // fallback target

  // ─── UI ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: Column(
                children: [
                  _buildStatsBar(),
                  Expanded(
                    child: _collectedFiles.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildRecordSection(),
                                  SizedBox(height: 32.h),
                                  _buildEmptyHint(),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              _buildCompactRecordSection(),
                              Expanded(child: _buildFileList()),
                            ],
                          ),
                  ),
                  _buildSubmitBar(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsBar() {
    final collected = _collectedFiles.length;
    final previousSubmitted = _claim?.submittedCount ?? 0;
    final totalSubmitted = previousSubmitted + collected;
    final progress = previousSubmitted > 0
        ? (totalSubmitted / (previousSubmitted + _totalRequired)).clamp(0.0, 1.0)
        : (collected / _totalRequired).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Icon(Icons.arrow_back_ios_new, size: 20.sp, color: AppColors.onSurfaceVariant),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _claim?.taskTitle ?? '语音采集',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      '已采集 $totalSubmitted 份',
                      style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2.r),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4.h,
                          backgroundColor: AppColors.outlineVariant,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 24.h),
        _buildRecordButton(),
        SizedBox(height: 20.h),
        if (_isRecording) _buildTimerDisplay(),
        if (_isRecording)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              '录音中... 点击按钮停止',
              style: TextStyle(fontSize: 12.sp, color: AppColors.error.withValues(alpha: 0.7)),
            ),
          ),
        if (!_isRecording)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Text(
              '点击按钮开始录音',
              style: TextStyle(fontSize: 13.sp, color: AppColors.onSurfaceVariant),
            ),
          ),
        SizedBox(height: 16.h),
        if (!_isRecording)
          GestureDetector(
            onTap: _pickAndUploadAudio,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_file, size: 18.sp, color: AppColors.onSurfaceVariant),
                  SizedBox(width: 8.w),
                  Text('上传音频文件', style: TextStyle(fontSize: 13.sp, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactRecordSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRecordButton(),
          if (_isRecording) ...[
            SizedBox(width: 16.w),
            _buildTimerDisplay(),
          ],
          if (!_isRecording && _isUploading) ...[
            SizedBox(width: 16.w),
            Row(
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                SizedBox(width: 8.w),
                Text('上传中...', style: TextStyle(fontSize: 12.sp, color: AppColors.primary)),
              ],
            ),
          ],
          if (!_isRecording && !_isUploading) ...[
            SizedBox(width: 16.w),
            GestureDetector(
              onTap: _pickAndUploadAudio,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.outlineVariant),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file, size: 16.sp, color: AppColors.onSurfaceVariant),
                    SizedBox(width: 6.w),
                    Text('上传', style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: _isRecording ? 80.w : 72.w,
        height: _isRecording ? 80.w : 72.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(
            color: _isRecording ? AppColors.error.withValues(alpha: 0.3) : Colors.transparent,
            width: 3,
          ),
        ),
        child: Center(
          child: Container(
            width: 56.w,
            height: 56.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error,
            ),
            child: Icon(Icons.mic, color: Colors.white, size: 28.sp),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerDisplay() {
    return Text(
      _durationLabel,
      style: TextStyle(
        fontSize: 28.sp,
        fontWeight: FontWeight.w300,
        color: AppColors.onSurface,
        fontFamily: 'monospace',
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildEmptyHint() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Icon(Icons.mic_none_outlined, size: 48.sp, color: AppColors.onSurfaceVariant.withValues(alpha: 0.4)),
          SizedBox(height: 12.h),
          Text(
            '点击录音按钮开始采集',
            style: TextStyle(fontSize: 14.sp, color: AppColors.outline),
          ),
          SizedBox(height: 6.h),
          Text(
            '或上传已有的音频文件',
            style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      itemCount: _collectedFiles.length,
      itemBuilder: (ctx, i) => _buildFileCard(i),
    );
  }

  Widget _buildFileCard(int index) {
    final f = _collectedFiles[index];
    final isRecorded = f.type == _FileType.recorded;
    final isAudio = isRecorded || f.name.endsWith('.wav') || f.name.endsWith('.mp3') || f.name.endsWith('.m4a') || f.name.endsWith('.ogg');
    final isVideo = f.name.endsWith('.mp4') || f.name.endsWith('.mov') || f.name.endsWith('.avi');
    final canPlay = isAudio || isVideo;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: (isRecorded ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              isRecorded ? Icons.mic : Icons.upload_file,
              size: 18.sp,
              color: isRecorded ? AppColors.primary : AppColors.secondary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.name,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Text(
                      _formatFileSize(f.size),
                      style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant),
                    ),
                    if (f.duration != null) ...[
                      SizedBox(width: 8.w),
                      Container(
                        width: 4.w,
                        height: 4.w,
                        decoration: const BoxDecoration(
                          color: AppColors.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        _formatDuration(f.duration!),
                        style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (canPlay)
            GestureDetector(
              onTap: () => _previewFile(f.id, f.name),
              child: Container(
                width: 28.w, height: 28.w,
                margin: EdgeInsets.only(right: 8.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.play_arrow, size: 18.sp, color: AppColors.primary),
              ),
            ),
          GestureDetector(
            onTap: () => _removeFile(index),
            child: Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.delete_outline, size: 16.sp, color: AppColors.error.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, MediaQuery.of(context).padding.bottom + 12.h),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUploading)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  SizedBox(width: 8.w),
                  Text('文件上传中...', style: TextStyle(fontSize: 12.sp, color: AppColors.primary)),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text('提交采集', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
            ),
          ),
          if (_collectedFiles.isNotEmpty && !_isSubmitting)
            Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Text(
                '已采集 ${_collectedFiles.length} 份文件',
                style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

enum _FileType { recorded, uploaded }

class _CollectedFile {
  final String id;
  final String name;
  final int size;
  final Duration? duration;
  final _FileType type;

  _CollectedFile({
    required this.id,
    required this.name,
    required this.size,
    this.duration,
    required this.type,
  });
}
