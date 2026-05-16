import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/skeleton.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<TaskClaimModel> _claims = [];
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ref.read(taskServiceProvider).getMyClaims(),
        ref.read(authServiceProvider).getMe(),
      ]);
      if (!mounted) return;
      final claims = results[0] as List<TaskClaimModel>;
      final user = results[1] as UserModel;
      setState(() {
        _claims = claims;
        _currentUser = user;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TaskClaimModel> get _approvedClaims =>
      _claims.where((c) => c.status == ClaimStatus.claimed || c.status == ClaimStatus.inProgress).toList();
  List<TaskClaimModel> get _pendingClaims =>
      _claims.where((c) => c.status == ClaimStatus.pendingApproval).toList();
  List<TaskClaimModel> get _submittedClaims =>
      _claims.where((c) => c.status == ClaimStatus.submitted || c.status == ClaimStatus.completed).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.top + 12.h)),
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildHeroBanner()),
            SliverToBoxAdapter(child: _buildQuickNavCards()),
            if (_pendingClaims.isNotEmpty) SliverToBoxAdapter(child: _buildPendingNotice()),
            if (_isLoading)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                sliver: const SliverToBoxAdapter(child: SkeletonTaskList()),
              )
            else ...[
              if (_approvedClaims.isNotEmpty)
                SliverToBoxAdapter(child: _buildSectionHeader('我的采集任务', '${_approvedClaims.length} 项可开始')),
              if (_approvedClaims.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildTaskClaimCard(_approvedClaims[i], canStart: true),
                    childCount: _approvedClaims.length,
                  )),
                ),
              if (_submittedClaims.isNotEmpty)
                SliverToBoxAdapter(child: _buildSectionHeader('已完成/审核中', null)),
              if (_submittedClaims.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildTaskClaimCard(_submittedClaims[i], canStart: false),
                    childCount: _submittedClaims.length,
                  )),
                ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Header — cloud_sync icon + "端云智采" title + bell
  //  Spec: bg surface/80%, backdrop blur, border-b separator/20%
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, 0, AppSpacing.layoutMargin.w, AppSpacing.sm.h),
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border(
          bottom: BorderSide(color: AppColors.separator.withValues(alpha: 0.2), width: 1),
        ),
        boxShadow: AppShadows.topBar,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Image.asset('assets/logo.png', width: 24.w, height: 24.w),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Text(
            '端云智采',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface),
          ),
        ]),
        GestureDetector(
          onTap: () => context.push('/profile'),
          child: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none, size: 20.sp, color: AppColors.onSurfaceVariant),
                if (_pendingClaims.isNotEmpty)
                  Positioned(
                    top: 9.h,
                    right: 9.w,
                    child: Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Hero Banner — gradient overlay with title + carousel dots
  // ────────────────────────────────────────────────────────────

  Widget _buildHeroBanner() {
    final pendingCount = _approvedClaims.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, 0, AppSpacing.layoutMargin.w, AppSpacing.sm.h),
      child: Container(
        height: 160.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF7A45),
              Color(0xFFFFB59A),
              Color(0xFF353535),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
          boxShadow: AppShadows.card,
        ),
        child: Stack(
          children: [
            // Decorative ambient circles
            Positioned(
              top: -24.h,
              right: -24.w,
              child: Container(
                width: 130.w,
                height: 130.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -32.h,
              left: -16.w,
              child: Container(
                width: 90.w,
                height: 90.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.12),
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentUser != null ? '你好，${_currentUser!.displayName}' : '你好，采集员',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '全球数据加速采集中',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/tasks'),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: AppSpacing.sm.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                              pendingCount > 0 ? '$pendingCount 个任务待采集' : '前往任务大厅',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: AppSpacing.xs.w),
                            Icon(Icons.arrow_forward, size: 13.sp, color: Colors.white),
                          ]),
                        ),
                      ),
                      // Carousel indicator dots
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) => Container(
                          width: i == 0 ? 20.w : 6.w,
                          height: 6.w,
                          margin: EdgeInsets.only(left: i > 0 ? 4.w : 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            color: i == 0
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Quick-Access Nav Cards — 音频采集 / 图像采集 / 视频采集
  //  Breadcrumb-style cards with low-alpha icon and border
  // ────────────────────────────────────────────────────────────

  Widget _buildQuickNavCards() {
    final navItems = [
      const _QuickNavItem(Icons.mic, '音频采集', TaskType.audio, AppColors.orange),
      const _QuickNavItem(Icons.image, '图像采集', TaskType.image, AppColors.primary),
      const _QuickNavItem(Icons.videocam, '视频采集', TaskType.video, AppColors.tertiary),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, 0, AppSpacing.layoutMargin.w, AppSpacing.sm.h),
      child: Row(
        children: navItems.map((item) {
          return Expanded(
            child: GestureDetector(
              onTap: () => context.push('/tasks', extra: {'type': item.type.name}),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.card.r),
                  border: Border.all(color: AppColors.outlineVariant, width: 1),
                  boxShadow: AppShadows.card,
                ),
                child: Column(children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.card.r),
                    ),
                    child: Icon(item.icon, size: 22.sp, color: item.color),
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Pending Approval Notice ───

  Widget _buildPendingNotice() {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, 0, AppSpacing.layoutMargin.w, AppSpacing.sm.h),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.dataGutter.w),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(Icons.schedule, size: 18.sp, color: AppColors.orange),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(child: Text(
            '${_pendingClaims.length} 个任务申请待审批',
            style: TextStyle(fontSize: 13.sp, color: AppColors.orange),
          )),
        ]),
      ),
    );
  }

  // ─── Section Header ───

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, AppSpacing.md.h, AppSpacing.layoutMargin.w, AppSpacing.sm.h),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          title,
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant),
          ),
      ]),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  Task Claim Card — approved / submitted
  //  Card bg #20201f, #58423a border, rounded-28, neomorph shadow
  //  Decorative corner circle, type chip, status badge
  // ────────────────────────────────────────────────────────────

  Widget _buildTaskClaimCard(TaskClaimModel claim, {required bool canStart}) {
    final isTextTask = claim.taskType == 'text';
    final iconData = isTextTask
        ? (canStart ? Icons.text_fields : Icons.text_fields_outlined)
        : (canStart ? Icons.play_circle_fill : Icons.check_circle_outline);
    final iconColor = canStart ? AppColors.primary : AppColors.outline;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.dataGutter.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: Stack(
        children: [
          // Decorative corner circle
          Positioned(
            top: -14.h,
            right: -14.w,
            child: Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.08),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            child: InkWell(
              onTap: canStart
                  ? () => context.push(isTextTask ? '/text-collection/${claim.taskId}' : '/collection/${claim.id}')
                  : null,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding.w),
                child: Row(children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Icon(iconData, size: 22.sp, color: iconColor),
                  ),
                  SizedBox(width: AppSpacing.dataGutter.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          claim.taskTitle ?? '任务 #${claim.taskId.substring(0, 8)}',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        Text(
                          claim.statusLabel,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm.w),
                  if (canStart)
                    _buildActionButton(isTextTask ? '查看文本' : '开始采集', iconColor)
                  else
                    _buildStatusBadge(claim.status),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Action Button — rounded-lg, warm amber, tactile glow ───

  Widget _buildActionButton(String label, Color color) {
    return GestureDetector(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: AppSpacing.sm.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10.r,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.onPrimary),
        ),
      ),
    );
  }

  // ─── Status Badge — full-round, low-alpha bg, 1px matching border ───

  Widget _buildStatusBadge(ClaimStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Color _statusColor(ClaimStatus status) => switch (status) {
    ClaimStatus.pendingApproval => AppColors.orange,
    ClaimStatus.claimed || ClaimStatus.inProgress => AppColors.primary,
    ClaimStatus.submitted => AppColors.orange,
    ClaimStatus.completed => AppColors.secondary,
    ClaimStatus.abandoned || ClaimStatus.rejected => AppColors.error,
    ClaimStatus.expired => AppColors.outline,
  };

  String _statusLabel(ClaimStatus status) => switch (status) {
    ClaimStatus.pendingApproval => '待审批',
    ClaimStatus.claimed => '已领取',
    ClaimStatus.inProgress => '进行中',
    ClaimStatus.submitted => '已提交',
    ClaimStatus.completed => '已完成',
    ClaimStatus.abandoned => '已放弃',
    ClaimStatus.expired => '已过期',
    ClaimStatus.rejected => '已驳回',
  };

}

class _QuickNavItem {
  final IconData icon;
  final String label;
  final TaskType type;
  final Color color;
  const _QuickNavItem(this.icon, this.label, this.type, this.color);
}
