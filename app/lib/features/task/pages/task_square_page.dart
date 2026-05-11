import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/team_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/services/team_service.dart';
import '../../../shared/widgets/skeleton.dart';

/// 任务广场 → 已批准认领 Feed
/// 展示全平台已批准/采集中/已完成的认领记录

class TaskSquarePage extends ConsumerStatefulWidget {
  const TaskSquarePage({super.key});

  @override
  ConsumerState<TaskSquarePage> createState() => _TaskSquarePageState();
}

class _TaskSquarePageState extends ConsumerState<TaskSquarePage> {
  List<Map<String, dynamic>> _claims = [];
  List<TeamModel> _myTeams = [];
  String? _selectedTeamId;
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ref.read(taskServiceProvider).getApprovedClaims(page: 1),
        ref.read(teamServiceProvider).getMyTeams(),
      ]);
      if (!mounted) return;
      final claimsData = results[0] as Map<String, dynamic>;
      final items = (claimsData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final teams = results[1] as List<TeamModel>;
      setState(() {
        _claims = items;
        _myTeams = teams;
        _page = 1;
        _hasMore = items.length >= 20;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    final nextPage = _page + 1;
    try {
      final data = await ref.read(taskServiceProvider).getApprovedClaims(
        page: nextPage,
        teamId: _selectedTeamId,
      );
      final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) {
        setState(() {
          _claims.addAll(items);
          _page = nextPage;
          _hasMore = items.length >= 20;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm.h)),
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm.h)),
            if (_myTeams.length > 1)
              SliverToBoxAdapter(child: _buildTeamFilterRow()),
            SliverToBoxAdapter(child: _buildTitleRow()),
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm.h)),
            if (_isLoading)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                sliver: const SliverToBoxAdapter(child: SkeletonTaskList()),
              )
            else if (_claims.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48.sp, color: AppColors.outline),
                      SizedBox(height: AppSpacing.sm.h),
                      Text('暂无认领记录', style: TextStyle(fontSize: 14.sp, color: AppColors.outline, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      if (i == _claims.length - 3) _loadMore();
                      return _buildClaimCard(_claims[i]);
                    },
                    childCount: _claims.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Image.asset('assets/logo.png', width: 30.w, height: 30.w),
            SizedBox(width: AppSpacing.sm.w),
            Text('端云智采', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          ]),
          Container(
            width: 40.w, height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.outlineVariant, width: 0.5),
            ),
            child: Icon(Icons.notifications_outlined, size: 20.sp, color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamFilterRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, 0, AppSpacing.layoutMargin.w, AppSpacing.xs.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _buildTeamChip(null, '全部团队'),
          ..._myTeams.map((t) => _buildTeamChip(t.id, t.name)),
        ]),
      ),
    );
  }

  Widget _buildTeamChip(String? teamId, String label) {
    final active = _selectedTeamId == teamId;
    return Padding(
      padding: EdgeInsets.only(right: AppSpacing.sm.w),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTeamId = teamId);
          _loadData();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: active ? AppColors.secondary.withValues(alpha: 0.20) : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: active ? Border.all(color: AppColors.secondary.withValues(alpha: 0.40), width: 1) : null,
          ),
          child: Text(label, style: TextStyle(fontSize: 12.sp, color: active ? AppColors.secondary : AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, 0, AppSpacing.layoutMargin.w, AppSpacing.xs.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('采集动态', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          Text('共 ${_claims.length} 条', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.outline)),
        ],
      ),
    );
  }

  Widget _buildClaimCard(Map<String, dynamic> claim) {
    final task = claim['task'] as Map<String, dynamic>? ?? {};
    final user = claim['user'] as Map<String, dynamic>? ?? {};
    final team = task['team'] as Map<String, dynamic>? ?? {};
    final taskType = task['type'] as String? ?? '';
    final taskTitle = task['title'] as String? ?? '未知任务';
    final userName = user['nickname'] as String? ?? user['phone'] as String? ?? '匿名用户';
    final teamName = team['name'] as String?;
    final claimedAt = claim['claimedAt'] as String?;
    final status = claim['status'] as String? ?? '';

    final typeCfg = _typeConfigFor(taskType);
    final timeStr = claimedAt != null ? _formatTime(DateTime.parse(claimedAt)) : '';
    final statusLabel = _statusLabel(status);

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.listGap.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Avatar
            Container(
              width: 36.w, height: 36.w,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryContainer]),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Center(child: Text(userName.substring(0, 1).toUpperCase(), style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white))),
            ),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(userName, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface), overflow: TextOverflow.ellipsis)),
                SizedBox(width: AppSpacing.xs.w),
                if (typeCfg != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(color: typeCfg.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4.r)),
                    child: Text(typeCfg.label, style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: typeCfg.color)),
                  ),
              ]),
              SizedBox(height: 2.h),
              Text(timeStr, style: TextStyle(fontSize: 11.sp, color: AppColors.outline)),
            ])),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
              ),
              child: Text(statusLabel, style: TextStyle(fontSize: 11.sp, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ]),
          SizedBox(height: AppSpacing.sm.h),
          // Task info
          Container(
            padding: EdgeInsets.all(AppSpacing.sm.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(taskTitle, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (teamName != null) ...[
                  SizedBox(height: 4.h),
                  Row(children: [
                    Icon(Icons.group, size: 12.sp, color: AppColors.outline),
                    SizedBox(width: 4.w),
                    Text(teamName, style: TextStyle(fontSize: 11.sp, color: AppColors.outline)),
                  ]),
                ],
              ])),
              Icon(Icons.chevron_right, size: 18.sp, color: AppColors.outline),
            ]),
          ),
        ]),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'claimed' => '已领取',
    'in_progress' => '采集中',
    'submitted' => '已提交',
    'completed' => '已完成',
    _ => status,
  };

  _TypeCfg? _typeConfigFor(String type) => switch (type) {
    'audio' => const _TypeCfg('音频', AppColors.orange),
    'image' => const _TypeCfg('图像', AppColors.primary),
    'video' => const _TypeCfg('视频', AppColors.tertiary),
    'text' => const _TypeCfg('文本', AppColors.secondary),
    _ => null,
  };

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _TypeCfg {
  final String label;
  final Color color;
  const _TypeCfg(this.label, this.color);
}
