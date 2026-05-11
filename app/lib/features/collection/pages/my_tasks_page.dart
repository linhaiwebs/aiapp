import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/services/task_service.dart';

class MyTasksPage extends ConsumerStatefulWidget {
  const MyTasksPage({super.key});

  @override
  ConsumerState<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends ConsumerState<MyTasksPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TaskClaimModel> _claims = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadClaims();
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  Future<void> _loadClaims() async {
    try {
      final claims = await ref.read(taskServiceProvider).getMyClaims();
      if (mounted) setState(() { _claims = claims; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TaskClaimModel> _filterByStatus(ClaimStatus status) => _claims.where((c) => c.status == status).toList();

  int get _totalCount => _claims.length;
  int get _inProgressCount => _filterByStatus(ClaimStatus.inProgress).length;
  int get _submittedCount => _filterByStatus(ClaimStatus.submitted).length;
  int get _completedCount => _filterByStatus(ClaimStatus.completed).length;

  Color _statusColor(ClaimStatus status) => switch (status) {
    ClaimStatus.pendingApproval => AppColors.orange,
    ClaimStatus.claimed => AppColors.primary,
    ClaimStatus.inProgress => AppColors.primary,
    ClaimStatus.submitted => AppColors.orange,
    ClaimStatus.completed => AppColors.secondary,
    ClaimStatus.abandoned => AppColors.error,
    ClaimStatus.expired => AppColors.outline,
    ClaimStatus.rejected => AppColors.error,
  };

  /// Returns a string label for button text on task cards.
  String _actionLabel(ClaimStatus status) => switch (status) {
    ClaimStatus.claimed || ClaimStatus.inProgress => '继续采集',
    ClaimStatus.pendingApproval => '等待审批',
    _ => '查看详情',
  };

  @override
  Widget build(BuildContext context) {
    final tabs = ['待审批', '待采集', '采集中', '待审核', '已通过', '已驳回'];
    final filters = [ClaimStatus.pendingApproval, ClaimStatus.claimed, ClaimStatus.inProgress, ClaimStatus.submitted, ClaimStatus.completed, ClaimStatus.abandoned];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('我的任务', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          tabAlignment: TabAlignment.start,
          labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w400),
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? _buildSkeletonList()
          : _claims.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildStatsBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: filters.map((status) {
                          final items = _filterByStatus(status);
                          if (items.isEmpty) {
                            return Center(
                              child: Text(
                                '暂无${tabs[filters.indexOf(status)]}任务',
                                style: TextStyle(color: AppColors.outline, fontSize: 14.sp),
                              ),
                            );
                          }
                          return ListView.builder(
                            padding: EdgeInsets.all(16.w),
                            itemCount: items.length,
                            itemBuilder: (ctx, i) => _buildTaskCard(items[i]),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ─── Stats Bar ────────────────────────────────────────────────

  Widget _buildStatsBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('全部', _totalCount, AppColors.primary),
          _buildStatDivider(),
          _buildStatItem('采集中', _inProgressCount, AppColors.primary),
          _buildStatDivider(),
          _buildStatItem('已提交', _submittedCount, AppColors.orange),
          _buildStatDivider(),
          _buildStatItem('已完成', _completedCount, AppColors.secondary),
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

  // ─── Task Card ────────────────────────────────────────────────

  Widget _buildTaskCard(TaskClaimModel claim) {
    final statusColor = _statusColor(claim.status);
    final isActive = claim.status == ClaimStatus.claimed || claim.status == ClaimStatus.inProgress;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title + status chip
          Row(
            children: [
              Expanded(
                child: Text(
                  claim.taskTitle ?? '任务 #${claim.taskId.substring(0, 8)}',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              _buildStatusChip(claim.statusLabel, statusColor),
            ],
          ),
          SizedBox(height: 6.h),
          // Task ID mono
          Text(
            'ID: ${claim.taskId}',
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.outline,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(height: 10.h),
          // Progress bar
          _buildTaskProgress(claim),
          SizedBox(height: 12.h),
          // Action button
          SizedBox(
            width: double.infinity,
            height: 36.h,
            child: isActive
                ? ElevatedButton(
                    onPressed: () => context.push('/collection/${claim.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      padding: EdgeInsets.zero,
                      textStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                    child: Text(_actionLabel(claim.status)),
                  )
                : OutlinedButton(
                    onPressed: claim.status == ClaimStatus.submitted
                        ? () => context.push('/submission/${claim.id}')
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                      side: const BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      padding: EdgeInsets.zero,
                      textStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                    ),
                    child: Text(_actionLabel(claim.status)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildTaskProgress(TaskClaimModel claim) {
    final submitted = claim.submittedCount;
    final passed = claim.passedCount;
    final rejected = claim.rejectedCount;
    final total = submitted + passed + rejected;
    final value = total > 0 ? ((passed + rejected) / (total + 1)).clamp(0.0, 1.0) : 0.0;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2.r),
            child: LinearProgressIndicator(
              value: claim.status == ClaimStatus.completed ? 1.0 : value,
              minHeight: 6.h,
              backgroundColor: AppColors.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                claim.status == ClaimStatus.completed ? AppColors.secondary : AppColors.primary,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '${claim.passedCount}/${total > 0 ? total + 1 : (claim.status == ClaimStatus.completed ? claim.passedCount : '-')}',
          style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  // ─── Empty ────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56.sp, color: AppColors.outline.withValues(alpha: 0.4)),
          SizedBox(height: 16.h),
          Text(
            '暂无领取的任务',
            style: TextStyle(fontSize: 15.sp, color: AppColors.outline),
          ),
          SizedBox(height: 8.h),
          Text(
            '前往任务大厅领取新任务',
            style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ─── Skeleton ─────────────────────────────────────────────────

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: 5,
      itemBuilder: (ctx, i) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title placeholder
          Container(
            width: 180.w,
            height: 14.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          SizedBox(height: 10.h),
          // ID placeholder
          Container(
            width: 100.w,
            height: 10.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          SizedBox(height: 12.h),
          // Progress bar placeholder
          Container(
            width: double.infinity,
            height: 6.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          SizedBox(height: 14.h),
          // Button placeholder
          Container(
            width: double.infinity,
            height: 36.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ],
      ),
    );
  }
}
