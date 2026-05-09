import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';

class DataExportPage extends ConsumerStatefulWidget {
  const DataExportPage({super.key});

  @override
  ConsumerState<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends ConsumerState<DataExportPage> {
  bool _isExporting = false;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now.subtract(const Duration(days: 30)))
          : (_endDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: AppColors.onPrimary,
                  surface: AppColors.surfaceContainer,
                  onSurface: AppColors.onSurface,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未选择';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _export(String type) async {
    setState(() => _isExporting = true);
    try {
      final client = ref.read(dioProvider);
      final params = <String, dynamic>{'format': 'json'};
      if (_startDate != null) {
        params['startDate'] = _startDate!.toIso8601String();
      }
      if (_endDate != null) {
        params['endDate'] = _endDate!.toIso8601String();
      }
      final response = await client.dio.get('/admin/export/$type', queryParameters: params);

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          '数据导出',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        ),
      ),
      body: _isExporting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: AppSpacing.md.h),
                  Text(
                    '正在导出数据...',
                    style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.all(AppSpacing.layoutMargin.w),
              children: [
                // ── Date range picker ──
                _sectionLabel('日期范围（可选）'),
                SizedBox(height: AppSpacing.sm.h),
                Row(
                  children: [
                    Expanded(
                      child: _dateTile('开始日期', _startDate, () => _pickDate(true)),
                    ),
                    SizedBox(width: AppSpacing.dataGutter.w),
                    Icon(Icons.arrow_forward, size: 16.sp, color: AppColors.outline),
                    SizedBox(width: AppSpacing.dataGutter.w),
                    Expanded(
                      child: _dateTile('结束日期', _endDate, () => _pickDate(false)),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg.h),

                // ── Export options ──
                _sectionLabel('导出数据'),
                SizedBox(height: AppSpacing.sm.h),

                _exportCard(
                  icon: Icons.description_outlined,
                  title: '导出采集记录',
                  description: '导出个人采集数据，包括提交时间、质检结果等',
                  onExport: () => _export('submissions'),
                ),
                SizedBox(height: AppSpacing.dataGutter.h),

                _exportCard(
                  icon: Icons.receipt_long_outlined,
                  title: '导出收益记录',
                  description: '导出个人收益明细，包括任务收入、提现记录等',
                  onExport: () => _export('earnings'),
                ),
                SizedBox(height: AppSpacing.dataGutter.h),

                _exportCard(
                  icon: Icons.person_outline,
                  title: '导出个人数据',
                  description: '导出个人账户数据、操作日志等完整信息',
                  onExport: () => _export('user-data'),
                ),

                SizedBox(height: AppSpacing.lg.h),

                // ── Script export info card ──
                Container(
                  padding: EdgeInsets.all(AppSpacing.cardPadding.w),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.outlineVariant, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36.w,
                            height: 36.w,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              Icons.terminal_outlined,
                              size: 18.sp,
                              color: AppColors.secondary,
                            ),
                          ),
                          SizedBox(width: AppSpacing.dataGutter.w),
                          Expanded(
                            child: Text(
                              '脚本导出',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      Text(
                        '使用导出脚本进行线下批量导出音频及数据文件',
                        style: TextStyle(fontSize: 13.sp, color: AppColors.onSurfaceVariant),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '支持格式：JSON / CSV 表格',
                          style: TextStyle(fontSize: 11.sp, color: AppColors.primary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 80.h),
              ],
            ),
    );
  }

  // ── Section label ──

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }

  // ── Date picker tile ──

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11.sp, color: AppColors.outline),
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14.sp,
                  color: date != null ? AppColors.primary : AppColors.onSurfaceVariant,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: date != null ? AppColors.onSurface : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Export card ──

  Widget _exportCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onExport,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.cardPadding.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 22.sp, color: AppColors.primary),
          ),
          SizedBox(width: AppSpacing.dataGutter.w),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(fontSize: 13.sp, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.dataGutter.w),

          // Export button
          OutlinedButton(
            onPressed: onExport,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            child: Text(
              '导出',
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
