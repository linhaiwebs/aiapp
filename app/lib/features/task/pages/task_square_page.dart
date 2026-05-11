import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/services/task_service.dart';
import '../../../shared/widgets/skeleton.dart';

/// 任务大厅 — 未领取的可用任务列表

class TaskSquarePage extends ConsumerStatefulWidget {
  const TaskSquarePage({super.key});

  @override
  ConsumerState<TaskSquarePage> createState() => _TaskSquarePageState();
}

class _TaskSquarePageState extends ConsumerState<TaskSquarePage> {
  List<TaskModel> _tasks = [];
  String? _typeFilter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await ref.read(taskServiceProvider).findAll(type: _typeFilter);
      if (mounted) setState(() { _tasks = tasks; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
            SliverToBoxAdapter(child: _buildTypeFilterRow()),
            SliverToBoxAdapter(child: _buildTitleRow()),
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm.h)),
            if (_isLoading)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                sliver: const SliverToBoxAdapter(child: SkeletonTaskList()),
              )
            else if (_tasks.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48.sp, color: AppColors.outline),
                      SizedBox(height: AppSpacing.sm.h),
                      Text('暂无可用任务', style: TextStyle(fontSize: 14.sp, color: AppColors.outline, fontWeight: FontWeight.w500)),
                      SizedBox(height: 4.h),
                      Text('当前团队暂无待领取的任务', style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _buildTaskCard(_tasks[i]),
                    childCount: _tasks.length,
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
          GestureDetector(
            onTap: () => context.push('/my-tasks'),
            child: Container(
              width: 40.w, height: 40.w,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.outlineVariant, width: 0.5),
              ),
              child: Icon(Icons.assignment_outlined, size: 20.sp, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterRow() {
    final filters = [
      const _FilterItem(null, '全部', Icons.apps),
      const _FilterItem('audio', '音频', Icons.mic),
      const _FilterItem('image', '图像', Icons.image),
      const _FilterItem('video', '视频', Icons.videocam),
      const _FilterItem('text', '文本', Icons.text_fields),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, 0, AppSpacing.layoutMargin.w, AppSpacing.xs.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: filters.map((f) {
          final active = _typeFilter == f.type;
          return Padding(
            padding: EdgeInsets.only(right: AppSpacing.sm.w),
            child: GestureDetector(
              onTap: () {
                setState(() => _typeFilter = f.type);
                _loadTasks();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1) : null,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.icon, size: 14.sp, color: active ? AppColors.primary : AppColors.onSurfaceVariant),
                  SizedBox(width: 4.w),
                  Text(f.label, style: TextStyle(fontSize: 12.sp, color: active ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          );
        }).toList()),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.layoutMargin.w, 0, AppSpacing.layoutMargin.w, AppSpacing.xs.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('任务大厅', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          Text('共 ${_tasks.length} 个任务', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.outline)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final typeCfg = _typeConfig(task.type);
    final remaining = task.totalQuantity - task.claimedQuantity;
    final progress = task.totalQuantity > 0
        ? (task.claimedQuantity / task.totalQuantity).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.listGap.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16.h,
            right: -16.w,
            child: Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: typeCfg.color.withValues(alpha: 0.06),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            child: InkWell(
              onTap: () => context.push('/tasks/${task.id}'),
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.cardPadding.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: typeCfg.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm.r),
                          border: Border.all(color: typeCfg.color.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(typeCfg.icon, size: 12.sp, color: typeCfg.color),
                          SizedBox(width: 4.w),
                          Text(task.typeLabel, style: TextStyle(fontSize: 11.sp, color: typeCfg.color, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const Spacer(),
                      if (task.unitPrice > 0)
                        Text(task.priceLabel, style: TextStyle(fontSize: 14.sp, color: AppColors.secondary, fontWeight: FontWeight.w700)),
                    ]),
                    SizedBox(height: AppSpacing.sm.h),
                    Text(
                      task.title,
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSpacing.xs.h),
                    Row(children: [
                      Text('ID ${task.id.substring(0, 8)}', style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant)),
                      SizedBox(width: AppSpacing.sm.w),
                      Container(width: 3.w, height: 3.w, decoration: BoxDecoration(color: AppColors.outline, borderRadius: BorderRadius.circular(AppRadius.full))),
                      SizedBox(width: AppSpacing.sm.w),
                      Text('剩余 $remaining/${task.totalQuantity}', style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant)),
                      if (task.deadline != null) ...[
                        const Spacer(),
                        Icon(Icons.access_time, size: 11.sp, color: AppColors.outline),
                        SizedBox(width: 3.w),
                        Text('${task.deadline!.month}/${task.deadline!.day} 截止', style: TextStyle(fontSize: 11.sp, color: AppColors.outline)),
                      ],
                    ]),
                    SizedBox(height: AppSpacing.sm.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(progress >= 0.9 ? AppColors.orange : typeCfg.color),
                        minHeight: 4.h,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    GestureDetector(
                      onTap: () => context.push('/tasks/${task.id}'),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm.r),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Center(
                          child: Text('领取任务', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TaskTypeCfg _typeConfig(TaskType type) => switch (type) {
    TaskType.audio => const _TaskTypeCfg(Icons.mic, AppColors.orange),
    TaskType.image => const _TaskTypeCfg(Icons.image, AppColors.primary),
    TaskType.video => const _TaskTypeCfg(Icons.videocam, AppColors.tertiary),
    TaskType.text => const _TaskTypeCfg(Icons.text_fields, AppColors.secondary),
  };
}

class _FilterItem {
  final String? type;
  final String label;
  final IconData icon;
  const _FilterItem(this.type, this.label, this.icon);
}

class _TaskTypeCfg {
  final IconData icon;
  final Color color;
  const _TaskTypeCfg(this.icon, this.color);
}
