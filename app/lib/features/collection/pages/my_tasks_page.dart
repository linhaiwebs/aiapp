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
    _tabController = TabController(length: 5, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    final tabs = ['待采集', '采集中', '待审核', '已通过', '已驳回'];
    final filters = [ClaimStatus.claimed, ClaimStatus.inProgress, ClaimStatus.submitted, ClaimStatus.completed, ClaimStatus.abandoned];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('我的任务', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          indicatorColor: AppColors.primary,
          tabs: tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: filters.map((status) {
                final items = _filterByStatus(status);
                if (items.isEmpty) return Center(child: Text('暂无${tabs[filters.indexOf(status)]}任务', style: TextStyle(color: AppColors.outline, fontSize: 14.sp)));
                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final claim = items[i];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(12.r), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20)]),
                      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(12.r), child: InkWell(
                        onTap: () => context.push('/collection/${claim.id}'),
                        borderRadius: BorderRadius.circular(12.r),
                        child: Padding(padding: EdgeInsets.all(16.w), child: Row(children: [
                          Container(width: 40.w, height: 40.w, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle), child: Icon(Icons.assignment, size: 20.sp, color: AppColors.primary)),
                          SizedBox(width: 12.w),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('任务 #${claim.taskId.substring(0, 8)}', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                            SizedBox(height: 4.h),
                            Text(claim.statusLabel, style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
                          ])),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(color: _statusColor(claim.status).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6.r)),
                            child: Text(claim.statusLabel, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: _statusColor(claim.status))),
                          ),
                        ])),
                      )),
                    );
                  },
                );
              }).toList(),
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
}
