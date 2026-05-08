import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/auth_service.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<TaskClaimModel> _claims = [];
  List<TaskModel> _availableTasks = [];
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load claims first so we can filter available tasks
    await _loadClaims();
    await Future.wait([_loadAvailableTasks(), _loadUser()]);
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    try {
      final claims = await ref.read(taskServiceProvider).getMyClaims();
      if (mounted) setState(() { _claims = claims; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAvailableTasks() async {
    try {
      final tasks = await ref.read(taskServiceProvider).findAll();
      // Filter out tasks the user has already claimed
      final claimedTaskIds = _claims.map((c) => c.taskId).toSet();
      final available = tasks.where((t) => !claimedTaskIds.contains(t.id)).toList();
      if (mounted) setState(() => _availableTasks = available);
    } catch (_) {}
  }

  Future<void> _loadUser() async {
    try {
      final user = await ref.read(authServiceProvider).getMe();
      if (mounted) setState(() => _currentUser = user);
    } catch (_) {}
  }

  /// Only show approved claims (claimed / in_progress) — these can be started directly
  List<TaskClaimModel> get _approvedClaims => _claims
      .where((c) => c.status == ClaimStatus.claimed || c.status == ClaimStatus.inProgress)
      .toList();

  List<TaskClaimModel> get _pendingClaims => _claims
      .where((c) => c.status == ClaimStatus.pendingApproval)
      .toList();

  List<TaskClaimModel> get _submittedClaims => _claims
      .where((c) => c.status == ClaimStatus.submitted || c.status == ClaimStatus.completed)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // Top bar
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12.h,
                  left: 20.w, right: 20.w, bottom: 16.h,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        width: 40.w, height: 40.w,
                        decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                        child: Icon(Icons.person, size: 20.sp, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    Icon(Icons.cloud_sync_outlined, size: 32.sp, color: AppColors.primary),
                    Container(
                      width: 40.w, height: 40.w,
                      decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                      child: Icon(Icons.notifications_none, size: 20.sp, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            // Welcome banner
            SliverToBoxAdapter(child: _buildWelcomeBanner()),
            // Pending approval notice
            if (_pendingClaims.isNotEmpty)
              SliverToBoxAdapter(child: _buildPendingNotice()),
            // My tasks section - approved only
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 4.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('我的采集任务', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    Text('${_approvedClaims.length} 项可开始', style: TextStyle(fontSize: 12.sp, color: AppColors.outline)),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_approvedClaims.isEmpty && _submittedClaims.isEmpty && _pendingClaims.isEmpty && _availableTasks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48.sp, color: AppColors.outline),
                      SizedBox(height: 12.h),
                      Text('暂无进行中的任务', style: TextStyle(color: AppColors.outline, fontSize: 14.sp)),
                      SizedBox(height: 8.h),
                      GestureDetector(
                        onTap: () => context.push('/tasks'),
                        child: Text('前往任务大厅领取', style: TextStyle(color: AppColors.primary, fontSize: 14.sp, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Approved tasks - can start directly
              if (_approvedClaims.isNotEmpty) ...[
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildTaskClaimCard(_approvedClaims[i], canStart: true),
                      childCount: _approvedClaims.length,
                    ),
                  ),
                ),
              ],
              // Submitted/completed section
              if (_submittedClaims.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 4.h),
                    child: Text('已完成/审核中', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildTaskClaimCard(_submittedClaims[i], canStart: false),
                      childCount: _submittedClaims.length,
                    ),
                  ),
                ),
              ],
              // Available tasks section - tasks the user can claim
              if (_availableTasks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 4.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('可领取任务', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                        GestureDetector(
                          onTap: () => context.push('/tasks'),
                          child: Text('查看全部', style: TextStyle(fontSize: 12.sp, color: AppColors.primary, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildAvailableTaskCard(_availableTasks[i]),
                      childCount: _availableTasks.length > 5 ? 5 : _availableTasks.length,
                    ),
                  ),
                ),
              ],
            ],
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 8.h),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Color(0xFF004395), Color(0xFF1A73E8)],
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentUser != null ? '你好，${_currentUser!.displayName}' : '你好，采集员',
              style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            SizedBox(height: 4.h),
            Text(
              '${_approvedClaims.length} 个任务待采集',
              style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.9)),
            ),
            SizedBox(height: 16.h),
            GestureDetector(
              onTap: () => context.push('/tasks'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('前往任务大厅', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  SizedBox(width: 4.w),
                  Icon(Icons.arrow_forward, size: 14.sp, color: AppColors.primary),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingNotice() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 8.h),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFFFD591)),
        ),
        child: Row(children: [
          Icon(Icons.schedule, size: 18.sp, color: const Color(0xFFFA8C16)),
          SizedBox(width: 8.w),
          Expanded(child: Text('${_pendingClaims.length} 个任务申请待审批', style: TextStyle(fontSize: 13.sp, color: const Color(0xFFD46B08)))),
        ]),
      ),
    );
  }

  Widget _buildTaskClaimCard(TaskClaimModel claim, {required bool canStart}) {
    final isTextTask = claim.taskType == 'text';
    final onTapRoute = canStart
        ? (isTextTask ? '/text-collection/${claim.taskId}' : '/collection/${claim.id}')
        : null;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFF9FAFB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 30, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: canStart ? () => context.push(onTapRoute!) : null,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(children: [
              Container(
                width: 44.w, height: 44.w,
                decoration: BoxDecoration(
                  color: canStart ? AppColors.primary.withValues(alpha: 0.08) : AppColors.outline.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTextTask
                      ? (canStart ? Icons.text_fields : Icons.text_fields_outlined)
                      : (canStart ? Icons.play_circle_fill : Icons.check_circle_outline),
                  size: 22.sp,
                  color: canStart ? AppColors.primary : AppColors.outline,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(claim.taskTitle ?? '任务 #${claim.taskId.substring(0, 8)}', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                  SizedBox(height: 4.h),
                  Text(claim.statusLabel, style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
                ],
              )),
              if (canStart)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8.r)),
                  child: Text(isTextTask ? '查看文本' : '开始采集', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: Colors.white)),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(color: _statusColor(claim.status).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6.r)),
                  child: Text(claim.statusLabel, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: _statusColor(claim.status))),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Color _statusColor(ClaimStatus status) => switch (status) {
    ClaimStatus.pendingApproval => const Color(0xFFFA8C16),
    ClaimStatus.claimed => AppColors.primary,
    ClaimStatus.inProgress => AppColors.primaryContainer,
    ClaimStatus.submitted => AppColors.orange,
    ClaimStatus.completed => AppColors.secondary,
    ClaimStatus.abandoned => AppColors.error,
    ClaimStatus.expired => AppColors.outline,
    ClaimStatus.rejected => AppColors.error,
  };

  Widget _buildAvailableTaskCard(TaskModel task) {
    final typeIcon = switch (task.type) {
      TaskType.audio => Icons.mic,
      TaskType.text => Icons.text_fields,
      TaskType.image => Icons.image,
      TaskType.video => Icons.videocam,
    };
    final remaining = task.totalQuantity - task.claimedQuantity;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: () => context.push('/tasks/${task.id}'),
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(14.w),
            child: Row(children: [
              Container(
                width: 40.w, height: 40.w,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10.r)),
                child: Icon(typeIcon, size: 20.sp, color: AppColors.primary),
              ),
              SizedBox(width: 12.w),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 4.h),
                  Row(children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4.r)),
                      child: Text(task.typeLabel, style: TextStyle(fontSize: 10.sp, color: AppColors.primary)),
                    ),
                    SizedBox(width: 8.w),
                    Text('剩余 $remaining 份', style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant)),
                    if (task.unitPrice > 0) ...[
                      SizedBox(width: 8.w),
                      Text('¥${task.unitPrice.toStringAsFixed(task.unitPrice.truncateToDouble() == task.unitPrice ? 0 : 2)}', style: TextStyle(fontSize: 11.sp, color: AppColors.secondary, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ],
              )),
              Icon(Icons.chevron_right, size: 20.sp, color: AppColors.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}
