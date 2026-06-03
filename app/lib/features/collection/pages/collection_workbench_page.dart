import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
import 'package:audioplayers/audioplayers.dart';
import '../../../core/network/dio_client.dart';
import '../widgets/audio_check_dialog.dart';
import '../widgets/sound_wave_background.dart';

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
  double _uploadProgress = 0;
  String _uploadingFileName = '';
  bool _showFullDesc = false;

  final AudioRecorder _recorder = AudioRecorder();
  bool _audioCheckPassed = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadClaim();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
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

      // Pre-recording audio check (once per session, uses same recorder)
      if (!_audioCheckPassed) {
        final needsCheck = _claim?.signalDetection == true ||
            _claim?.gainDetection == true ||
            _claim?.silenceDetection == true;
        if (needsCheck) {
          final checkPath = '${dir.path}/check_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1), path: checkPath);
          final stream = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100));
          final result = await showAudioCheckDialog(
            context: context,
            checkSignal: _claim?.signalDetection ?? false,
            checkGain: _claim?.gainDetection ?? false,
            checkSilence: _claim?.silenceDetection ?? false,
            noiseLimitDb: _claim?.noiseLimit ?? 60,
            amplitudeStream: stream,
            stopCheck: () => _recorder.stop(),
          );
          try { await _recorder.stop(); } catch (_) {}
          await Future.delayed(const Duration(seconds: 1));
          if (result == null || !result.allPassed) {
            _audioCheckPassed = false;
            return;
          }
        }
        _audioCheckPassed = true;
      }

      final opusPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, numChannels: 1), path: opusPath);

      // 静音区预留检查：录音开始后，在 silencePadding ms 内检测是否有有效信号
      final silenceMs = _claim?.silencePadding ?? 0;
      if (silenceMs > 0) {
        final silenceAmps = <double>[];
        final silenceSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
          silenceAmps.add(amp.current);
        });
        await Future.delayed(Duration(milliseconds: silenceMs));
        await silenceSub.cancel();

        final validAmps = silenceAmps.where((a) => a.isFinite).toList();
        final hasSignal = validAmps.isNotEmpty && validAmps.any((a) => a > -40);
        if (validAmps.isNotEmpty && !hasSignal) {
          try { await _recorder.stop(); } catch (_) {}
          if (mounted) {
            showDialog(context: context, builder: (ctx) => AlertDialog(
              title: const Text('录音不合格'),
              content: Text('开头静音超过预留时间（${silenceMs}ms），请检测麦克风后重新录制'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
            ));
          }
          return;
        }
      }

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
        final duration = _recordingDuration;
        setState(() { _isRecording = false; _recordingDuration = Duration.zero; });

        if (kIsWeb) {
          // Web: 录音数据是 blob URL，用 Dio 获取字节
          final dio = Dio();
          final bytes = (await dio.get(path, options: Options(responseType: ResponseType.bytes))).data as Uint8List;
          await _uploadFileBytes(bytes, '录音_${_collectedFiles.length + 1}.opus', duration: duration);
        } else {
          final file = File(path);
          if (await file.exists()) {
            await _uploadFileNative(path, source: '录音_${_collectedFiles.length + 1}.opus', duration: duration);
            return;
          }
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

  Future<void> _pickAndUploadFiles() async {
    final taskType = _claim?.taskType ?? 'audio';
    final pickType = switch (taskType) {
      'image' => FileType.image,
      'video' => FileType.video,
      'audio' => FileType.audio,
      _ => FileType.any,
    };
    try {
      final result = await FilePicker.platform.pickFiles(
        type: pickType,
        allowMultiple: true,
      );
      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (kIsWeb) {
            if (file.bytes != null) {
              await _uploadFileBytes(file.bytes!, file.name);
            }
          } else if (file.path != null) {
            await _uploadFileNative(file.path!, source: file.name);
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

  Future<void> _uploadFileNative(String filePath, {String source = '', Duration? duration}) async {
    final fileName = source.isNotEmpty ? source : filePath.split('/').last;
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadingFileName = fileName;
    });
    _showProgressDialog(fileName);
    try {
      final result = await ref.read(fileServiceProvider).simpleUpload(
        filePath,
        taskId: _claim?.taskId,
        taskType: _claim?.taskType ?? 'audio',
        onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      final fileId = result['id'] as String;
      final size = await File(filePath).length();
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() {
          _collectedFiles.add(_CollectedFile(
            id: fileId,
            name: fileName,
            size: size,
            duration: duration,
            type: duration != null ? _FileType.recorded : _FileType.uploaded,
          ));
          _isUploading = false;
          _uploadProgress = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName 上传成功'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Web 端上传：使用字节流
  Future<void> _uploadFileBytes(Uint8List bytes, String fileName, {Duration? duration}) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadingFileName = fileName;
    });
    _showProgressDialog(fileName);
    try {
      final result = await ref.read(fileServiceProvider).simpleUploadBytes(
        fileName: fileName,
        bytes: bytes,
        taskId: _claim?.taskId,
        taskType: _claim?.taskType ?? 'audio',
        onProgress: (sent, total) {
          if (mounted && total > 0) {
            setState(() => _uploadProgress = sent / total);
          }
        },
      );
      final fileId = result['id'] as String;
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() {
          _collectedFiles.add(_CollectedFile(
            id: fileId,
            name: fileName,
            size: bytes.length,
            duration: duration,
            type: duration != null ? _FileType.recorded : _FileType.uploaded,
          ));
          _isUploading = false;
          _uploadProgress = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName 上传成功'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        setState(() { _isUploading = false; _uploadProgress = 0; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showProgressDialog(String fileName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceContainerLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_upload_outlined, size: 40.sp, color: AppColors.primary),
                SizedBox(height: 16.h),
                Text('正在上传', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                SizedBox(height: 8.h),
                Text(
                  fileName,
                  style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    minHeight: 6.h,
                    backgroundColor: AppColors.outlineVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  _uploadProgress > 0 ? '${(_uploadProgress * 100).toInt()}%' : '准备中...',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.primary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _removeFile(int index) {
    setState(() { _collectedFiles.removeAt(index); });
  }

  void _previewFile(String fileId, String name) {
    final serverBase = ref.read(dioProvider).dio.options.baseUrl;
    final url = '$serverBase/files/$fileId/stream';
    final isAudio = name.endsWith('.wav') || name.endsWith('.mp3') || name.endsWith('.m4a') || name.endsWith('.aac') || name.endsWith('.opus');

    if (!isAudio) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black,
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.5,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.insert_drive_file, color: Colors.white54, size: 48),
              SizedBox(height: 16.h),
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
      return;
    }

    _audioPlayer.stop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => _AudioPlayerSheet(url: url, name: name, player: _audioPlayer),
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
                  if (_claim?.taskDescription != null && _claim!.taskDescription!.isNotEmpty)
                    _buildDescriptionCard(),
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

  Widget _buildDescriptionCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, size: 14.sp, color: AppColors.primary),
            SizedBox(width: 6.w),
            Text('任务描述', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _showFullDesc = !_showFullDesc),
              child: Text(_showFullDesc ? '收起' : '展开', style: TextStyle(fontSize: 11.sp, color: AppColors.outline)),
            ),
          ]),
          SizedBox(height: 6.h),
          AnimatedCrossFade(
            firstChild: Text(
              _claim!.taskDescription!,
              style: TextStyle(fontSize: 13.sp, color: AppColors.onSurface, height: 1.5),
              maxLines: _showFullDesc ? 999 : 2,
              overflow: _showFullDesc ? null : TextOverflow.ellipsis,
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _showFullDesc ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
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
            onTap: _pickAndUploadFiles,
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
              onTap: _pickAndUploadFiles,
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
    final isAudio = isRecorded || f.name.endsWith('.wav') || f.name.endsWith('.mp3') || f.name.endsWith('.m4a') || f.name.endsWith('.ogg') || f.name.endsWith('.opus');
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          '上传中: $_uploadingFileName',
                          style: TextStyle(fontSize: 11.sp, color: AppColors.primary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2.r),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      minHeight: 4.h,
                      backgroundColor: AppColors.outlineVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
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

class _AudioPlayerSheet extends StatefulWidget {
  final String url;
  final String name;
  final AudioPlayer player;

  const _AudioPlayerSheet({required this.url, required this.name, required this.player});

  @override
  State<_AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<_AudioPlayerSheet> {
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    widget.player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    widget.player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _play();
  }

  @override
  void dispose() {
    widget.player.stop();
    super.dispose();
  }

  Future<void> _play() async {
    await widget.player.play(UrlSource(widget.url));
  }

  Future<void> _togglePlayPause() async {
    if (_playerState == PlayerState.playing) {
      await widget.player.pause();
    } else {
      await widget.player.resume();
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _playerState == PlayerState.playing;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w, height: 4.h,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2.r)),
          ),
          SizedBox(height: 24.h),
          Icon(Icons.audiotrack, size: 48.sp, color: Colors.white),
          SizedBox(height: 12.h),
          Text(widget.name, style: TextStyle(color: Colors.white, fontSize: 14.sp), textAlign: TextAlign.center),
          SizedBox(height: 20.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4.h,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(_position), style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
              Text(_fmt(_duration), style: TextStyle(color: Colors.white54, fontSize: 12.sp)),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 56.sp,
                onPressed: _togglePlayPause,
                icon: Icon(
                  isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
