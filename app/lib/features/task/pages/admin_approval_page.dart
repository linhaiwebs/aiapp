import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/task_service.dart';

/// 团长/管理员审批页（APP 内使用）
/// Tab: 待审批 | 已审批

class AdminApprovalPage extends ConsumerStatefulWidget {
  const AdminApprovalPage({super.key});

  @override
  ConsumerState<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends ConsumerState<AdminApprovalPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPending();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(taskServiceProvider).getPendingClaims(pageSize: 100);
      if (mounted) {
        setState(() {
          _pending = ((data['items'] as List?) ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(String claimId) async {
    try {
      await ref.read(taskServiceProvider).approveClaim(claimId);
      _loadPending();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已通过申请'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _reject(String claimId) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('驳回申请'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('确定驳回此申请吗？'),
          SizedBox(height: AppSpacing.sm.h),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(labelText: '驳回原因（可选）', border: OutlineInputBorder()),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(reasonController.text),
            child: const Text('驳回', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(taskServiceProvider).rejectClaim(claimId, reason: result.isEmpty ? null : result);
      _loadPending();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('审批管理', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.outline,
          indicatorColor: AppColors.primary,
          labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: '待审批 (${_pending.length})'),
            const Tab(text: '已审批'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildApprovedTab(),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pending.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, size: 48.sp, color: AppColors.outline),
          SizedBox(height: AppSpacing.sm.h),
          Text('暂无待审批申请', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.md.w),
        itemCount: _pending.length,
        itemBuilder: (ctx, i) => _buildClaimItem(_pending[i], pending: true),
      ),
    );
  }

  Widget _buildApprovedTab() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.history, size: 48.sp, color: AppColors.outline),
        SizedBox(height: AppSpacing.sm.h),
        Text('已审批记录请在后台查看', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)),
      ]),
    );
  }

  Widget _buildClaimItem(Map<String, dynamic> claim, {bool pending = false}) {
    final task = claim['task'] as Map<String, dynamic>? ?? {};
    final user = claim['user'] as Map<String, dynamic>? ?? {};
    final taskTitle = task['title'] as String? ?? '未知任务';
    final userName = user['nickname'] as String? ?? user['phone'] as String? ?? '未知用户';
    final taskType = task['type'] as String? ?? '';
    final createdAt = claim['createdAt'] as String?;
    final timeStr = createdAt != null ? _formatTime(DateTime.parse(createdAt)) : '';

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36.w, height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Center(
              child: Text(userName.substring(0, 1).toUpperCase(),
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(userName, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              SizedBox(height: 2.h),
              Text(timeStr, style: TextStyle(fontSize: 11.sp, color: AppColors.outline)),
            ]),
          ),
          if (taskType.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(taskType, style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant)),
            ),
        ]),
        SizedBox(height: AppSpacing.sm.h),
        Container(
          padding: EdgeInsets.all(AppSpacing.sm.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
          ),
          child: Row(children: [
            Expanded(
              child: Text(taskTitle, style: TextStyle(fontSize: 13.sp, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.chevron_right, size: 16.sp, color: AppColors.outline),
          ]),
        ),
        if (pending) ...[
          SizedBox(height: AppSpacing.sm.h),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            SizedBox(
              height: 34.h,
              child: ElevatedButton(
                onPressed: () => _approve(claim['id'] as String),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                ),
                child: Text('通过', style: TextStyle(fontSize: 13.sp, color: AppColors.onPrimary)),
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            SizedBox(
              height: 34.h,
              child: OutlinedButton(
                onPressed: () => _reject(claim['id'] as String),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                ),
                child: Text('驳回', style: TextStyle(fontSize: 13.sp)),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
