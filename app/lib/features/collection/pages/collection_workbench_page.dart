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
      if (mounted) setState(() { _claim = claim; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: _collectedFiles.isEmpty
                        ? _buildEmptyState()
                        : _buildFileList(),
                  ),
                  _buildControls(),
                ],
              ),
            ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Icon(Icons.close, size: 24.sp, color: Colors.white70),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              _claim?.taskTitle ?? '语音采集',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _isRecording ? Colors.red.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              _isRecording ? '录音中' : '就绪',
              style: TextStyle(
                fontSize: 11.sp,
                color: _isRecording ? Colors.redAccent : AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_none_outlined, size: 64.sp, color: Colors.white24),
          SizedBox(height: 16.h),
          Text('点击下方录音按钮开始采集', style: TextStyle(fontSize: 15.sp, color: Colors.white38)),
          SizedBox(height: 8.h),
          Text('或上传已有的音频文件', style: TextStyle(fontSize: 13.sp, color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _collectedFiles.length,
      itemBuilder: (ctx, i) => _buildFileCard(i),
    );
  }

  Widget _buildFileCard(int index) {
    final f = _collectedFiles[index];
    final isRecorded = f.type == _FileType.recorded;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w, height: 40.w,
            decoration: BoxDecoration(
              color: (isRecorded ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              isRecorded ? Icons.mic : Icons.upload_file,
              size: 20.sp,
              color: isRecorded ? AppColors.primary : AppColors.secondary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Row(children: [
                  Text(_formatFileSize(f.size), style: TextStyle(fontSize: 11.sp, color: Colors.white54)),
                  if (f.duration != null) ...[
                    SizedBox(width: 8.w),
                    Text(_formatDuration(f.duration!), style: TextStyle(fontSize: 11.sp, color: Colors.white54)),
                  ],
                ]),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _removeFile(index),
            child: Icon(Icons.close, size: 18.sp, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, MediaQuery.of(context).padding.bottom + 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 8.w, height: 8.w, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  SizedBox(width: 8.w),
                  Text(_durationLabel, style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w300, color: Colors.white, fontFamily: 'monospace', letterSpacing: 2)),
                ],
              ),
            ),
          if (_collectedFiles.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Text('已采集 ${_collectedFiles.length} 份', style: TextStyle(fontSize: 13.sp, color: Colors.white54)),
            ),
          if (_isUploading)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  SizedBox(width: 8.w),
                  Text('上传中...', style: TextStyle(fontSize: 12.sp, color: AppColors.primary)),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionButton(Icons.upload_file, '上传', onTap: _isRecording ? null : _pickAndUploadAudio),
              GestureDetector(
                onTap: _toggleRecording,
                child: Container(
                  width: 72.w, height: 72.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _isRecording ? Colors.redAccent : Colors.white.withValues(alpha: 0.4), width: 3),
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: _isRecording ? 28.w : 52.w,
                      height: _isRecording ? 28.w : 52.w,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.redAccent,
                        borderRadius: BorderRadius.circular(_isRecording ? 6.r : 26.r),
                      ),
                    ),
                  ),
                ),
              ),
              _actionButton(Icons.send, '提交', onTap: _canSubmit ? _submit : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, {VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48.w, height: 48.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Icon(icon, color: enabled ? Colors.white : Colors.white38, size: 22.sp),
            ),
            SizedBox(height: 6.h),
            Text(label, style: TextStyle(fontSize: 11.sp, color: enabled ? Colors.white70 : Colors.white38, fontWeight: FontWeight.w500)),
          ],
        ),
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
