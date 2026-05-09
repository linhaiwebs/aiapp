import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/text_collection_model.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/services/text_collection_service.dart';
import '../../../core/services/submission_service.dart';
import '../../../core/services/task_service.dart';

class TextCollectionPage extends ConsumerStatefulWidget {
  final String taskId;
  const TextCollectionPage({super.key, required this.taskId});

  @override
  ConsumerState<TextCollectionPage> createState() => _TextCollectionPageState();
}

class _TextCollectionPageState extends ConsumerState<TextCollectionPage> {
  List<TextCollectionModel> _texts = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final [texts, stats] = await Future.wait([
        ref.read(textCollectionServiceProvider).findAll(taskId: widget.taskId),
        ref.read(textCollectionServiceProvider).getStats(widget.taskId),
      ]);
      if (mounted) {
        setState(() {
          _texts = texts as List<TextCollectionModel>;
          _stats = stats as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _toIntVal(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _submitCollected() async {
    final completedTexts = _texts.where((t) => t.status == TextStatus.collecting || t.status == TextStatus.completed).toList();
    if (completedTexts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可提交的采集数据'), backgroundColor: AppColors.orange),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Find the claim for this task
      final claims = await ref.read(taskServiceProvider).getMyClaims();
      final claim = claims.where((c) => c.taskId == widget.taskId && (c.status == ClaimStatus.claimed || c.status == ClaimStatus.inProgress)).firstOrNull;

      if (claim == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到对应的领取记录'), backgroundColor: AppColors.error),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      await ref.read(submissionServiceProvider).create(
        claimId: claim.id,
        data: {
          'collectedCount': completedTexts.length,
          'textIds': completedTexts.map((t) => t.id).toList(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提交成功，共 ${completedTexts.length} 条文本'),
            backgroundColor: AppColors.secondary,
          ),
        );
        // Reload data
        _loadData();
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

  void _showTextDetail(TextCollectionModel text) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  _buildStatusIndicator(text.status, size: 10.w),
                  SizedBox(width: 8.w),
                  Text(text.statusLabel, style: TextStyle(fontSize: 13.sp, color: _statusColor(text.status))),
                  const Spacer(),
                  _buildFormatTag(text.formatLabel),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                text.content,
                style: TextStyle(fontSize: 14.sp, color: AppColors.onSurface, height: 1.5),
              ),
              SizedBox(height: 16.h),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(TextStatus status) => switch (status) {
    TextStatus.pending => AppColors.outline,
    TextStatus.assigned => AppColors.orange,
    TextStatus.collecting => AppColors.primary,
    TextStatus.completed => AppColors.secondary,
    TextStatus.qcFailed => AppColors.error,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('文本采集', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                if (_stats != null) _buildStatsHeader(),
                Expanded(
                  child: _texts.isEmpty
                      ? Center(
                          child: Text(
                            '暂无文本数据',
                            style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          itemCount: _texts.length,
                          itemBuilder: (context, index) => _buildTextCard(_texts[index]),
                        ),
                ),
                _buildSubmitBar(),
              ],
            ),
    );
  }

  // ─── Stats Header ─────────────────────────────────────────────

  Widget _buildStatsHeader() {
    final total = _toIntVal(_stats?['total']);
    final pending = _toIntVal(_stats?['pending']);
    final assigned = _toIntVal(_stats?['assigned']);
    final completed = _toIntVal(_stats?['completed']);
    final remaining = pending + assigned;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('总计', total, AppColors.primary),
          _buildStatDivider(),
          _buildStatItem('剩余', remaining, AppColors.outline),
          _buildStatDivider(),
          _buildStatItem('已完成', completed, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: color),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28.h,
      color: AppColors.outlineVariant,
    );
  }

  // ─── Text Card ────────────────────────────────────────────────

  Widget _buildTextCard(TextCollectionModel text) {
    final statusColor = _statusColor(text.status);

    return GestureDetector(
      onTap: () => _showTextDetail(text),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator dot
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: _buildStatusIndicator(text.status, size: 8.w),
            ),
            SizedBox(width: 12.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.content,
                    style: TextStyle(fontSize: 14.sp, color: AppColors.onSurface, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      _buildFormatTag(text.formatLabel),
                      SizedBox(width: 8.w),
                      _buildStatusChip(text.statusLabel, statusColor),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            Padding(
              padding: EdgeInsets.only(top: 2.h, left: 8.w),
              child: Icon(Icons.chevron_right, size: 18.sp, color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(TextStatus status, {double size = 8}) {
    final color = _statusColor(status);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildFormatTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w500, color: AppColors.outline),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  // ─── Submit Bar ───────────────────────────────────────────────

  Widget _buildSubmitBar() {
    final hasCollectable = _texts.any(
      (t) => t.status == TextStatus.collecting || t.status == TextStatus.completed,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, MediaQuery.of(context).padding.bottom + 12.h),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainer,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 44.h,
        child: ElevatedButton(
          onPressed: hasCollectable && !_isSubmitting ? _submitCollected : null,
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
              : Text('提交', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
