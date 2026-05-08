import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';

class DataExportPage extends ConsumerStatefulWidget {
  const DataExportPage({super.key});

  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  bool _isExporting = false;

  Future<void> _export(String type) async {
    setState(() => _isExporting = true);
    try {
      final client = ref.read(dioProvider);
      final response = await client.dio.get('/admin/export/$type', queryParameters: {'format': 'json'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出成功，数据包含 ${(response.data as List?)?.length ?? 0} 条记录'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      appBar: AppBar(
        title: const Text('数据导出', style: TextStyle(color: AppColors.onPrimary)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),
      body: _isExporting
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _exportCard(
                  icon: Icons.description,
                  title: '任务信息',
                  subtitle: '导出所有任务信息，包括配置、状态、进度等',
                  onTap: () => _export('tasks'),
                ),
                SizedBox(height: 12.h),
                _exportCard(
                  icon: Icons.upload_file,
                  title: '采集信息',
                  subtitle: '导出个人采集数据，包括提交时间、质检结果等',
                  onTap: () => _export('submissions'),
                ),
                SizedBox(height: 12.h),
                _exportCard(
                  icon: Icons.audio_file,
                  title: '音频文件链接',
                  subtitle: '导出音频文件URL列表，可直接在线播放',
                  onTap: () => _export('audio-links'),
                ),
                SizedBox(height: 24.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('脚本导出', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                      SizedBox(height: 8.h),
                      Text('使用导出脚本进行线下批量导出音频及数据文件', style: TextStyle(fontSize: 13.sp, color: AppColors.onSurfaceVariant)),
                      SizedBox(height: 12.h),
                      Text('导出格式支持：JSON / CSV 表格', style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _exportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 44.w, height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, size: 22.sp, color: AppColors.primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                  SizedBox(height: 4.h),
                  Text(subtitle, style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20.sp, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
