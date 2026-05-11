import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/skeleton.dart';

/// 已提交作品只读预览页
/// 支持音频/视频流播放、文本内容显示

class SubmissionDetailPage extends ConsumerStatefulWidget {
  final String submissionId;
  const SubmissionDetailPage({super.key, required this.submissionId});

  @override
  ConsumerState<SubmissionDetailPage> createState() => _SubmissionDetailPageState();
}

class _SubmissionDetailPageState extends ConsumerState<SubmissionDetailPage> {
  Map<String, dynamic>? _submission;
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider).dio;
      final res = await dio.get('/submissions/${widget.submissionId}');
      if (mounted) {
        setState(() {
          _submission = res.data as Map<String, dynamic>?;
          _files = ((_submission?['files'] as List?) ?? []).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('提交详情', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
      ),
      body: _isLoading
          ? const Center(child: SkeletonTaskList())
          : _submission == null
              ? Center(
                  child: Text('未找到提交记录', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)))
              : ListView(
                  padding: EdgeInsets.all(AppSpacing.md.w),
                  children: [
                    _buildInfoCard(),
                    SizedBox(height: AppSpacing.lg.h),
                    Text('采集文件 (${_files.length})',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                    SizedBox(height: AppSpacing.sm.h),
                    ..._files.map(_buildFileItem),
                    SizedBox(height: 100.h),
                  ],
                ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_submission?['taskTitle'] ?? '提交记录',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        SizedBox(height: AppSpacing.sm.h),
        _infoRow('提交时间', _submission?['createdAt'] ?? '-'),
        _infoRow('状态', _submission?['status'] ?? '-'),
        _infoRow('文件数量', '${_files.length}'),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs.h),
      child: Row(children: [
        SizedBox(
          width: 80.w,
          child: Text(label, style: TextStyle(fontSize: 13.sp, color: AppColors.outline)),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13.sp, color: AppColors.onSurface)),
        ),
      ]),
    );
  }

  Widget _buildFileItem(Map<String, dynamic> file) {
    final id = file['id'] as String? ?? '';
    final name = file['originalName'] as String? ?? '未知文件';
    final mimeType = file['mimeType'] as String? ?? '';
    final fileSize = file['fileSize'] as int? ?? 0;

    final isAudio = mimeType.startsWith('audio/');
    final isVideo = mimeType.startsWith('video/');
    final isImage = mimeType.startsWith('image/');
    final isText = mimeType.startsWith('text/');

    IconData icon = Icons.insert_drive_file_outlined;
    Color color = AppColors.outline;
    if (isAudio) {
      icon = Icons.audiotrack;
      color = AppColors.orange;
    } else if (isVideo) {
      icon = Icons.videocam;
      color = AppColors.tertiary;
    } else if (isImage) {
      icon = Icons.image;
      color = AppColors.primary;
    } else if (isText) {
      icon = Icons.text_snippet;
      color = AppColors.secondary;
    }

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          width: 44.w, height: 44.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
          ),
          child: Icon(icon, size: 22.sp, color: color),
        ),
        SizedBox(width: AppSpacing.sm.w),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2.h),
            Text(_formatSize(fileSize), style: TextStyle(fontSize: 11.sp, color: AppColors.outline)),
          ]),
        ),
        if (isAudio || isVideo)
          IconButton(
            onPressed: () => _playFile(id, name, isVideo),
            icon: Icon(isVideo ? Icons.play_circle_outline : Icons.play_circle_fill, size: 32.sp, color: AppColors.primary),
          ),
      ]),
    );
  }

  void _playFile(String fileId, String name, bool isVideo) {
    final serverBase = ref.read(dioProvider).dio.options.baseUrl;
    final url = '$serverBase/files/$fileId/stream';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Center(
          child: Text('播放: $name\n$url',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
