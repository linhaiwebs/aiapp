import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/services/task_service.dart';

class TaskSquarePage extends ConsumerStatefulWidget {
  const TaskSquarePage({super.key});

  @override
  ConsumerState<TaskSquarePage> createState() => _TaskSquarePageState();
}

class _TaskSquarePageState extends ConsumerState<TaskSquarePage> {
  int _selectedFilter = 0;
  String? _selectedSort;
  final _searchController = TextEditingController();
  List<TaskModel> _tasks = [];
  bool _isLoading = true;

  final _filterChips = ['全部', '音频', '视频', '图像', '文本'];
  final _sortChips = ['最新发布', '金额最高', '剩余最多'];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(taskServiceProvider);
      String? type;
      if (_selectedFilter == 1) type = 'audio';
      else if (_selectedFilter == 2) type = 'video';
      else if (_selectedFilter == 3) type = 'image';
      else if (_selectedFilter == 4) type = 'text';
      final tasks = await service.findAll(type: type);
      if (mounted) setState(() { _tasks = tasks; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16.h, left: 20.w, right: 20.w, bottom: 12.h),
              color: AppColors.background.withValues(alpha: 0.8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.cloud_sync_outlined, size: 28.sp, color: AppColors.primary),
                    SizedBox(width: 8.w),
                    Text('任务大厅', style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  ]),
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                    child: Icon(Icons.search, size: 20.sp, color: AppColors.onSurface),
                  ),
                ],
              ),
            ),
          ),
          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: List.generate(_filterChips.length, (i) {
                  final active = _selectedFilter == i;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: GestureDetector(
                      onTap: () { setState(() => _selectedFilter = i); _loadTasks(); },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(_filterChips[i], style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: active ? AppColors.primary : AppColors.onSurfaceVariant)),
                      ),
                    ),
                  );
                })),
              ),
            ),
          ),
          // Sort chips
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: List.generate(_sortChips.length, (i) {
                  return Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(20.r)),
                      child: Row(children: [
                        Text(_sortChips[i], style: TextStyle(fontSize: 12.sp, color: AppColors.onSurface, fontWeight: FontWeight.w500)),
                        SizedBox(width: 2.w),
                        Icon(Icons.keyboard_arrow_down, size: 14.sp, color: AppColors.onSurface),
                      ]),
                    ),
                  );
                })),
              ),
            ),
          ),
          // Task list
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_tasks.isEmpty)
            SliverFillRemaining(child: Center(child: Text('暂无任务', style: TextStyle(color: AppColors.outline, fontSize: 14.sp))))
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildTaskCard(_tasks[i]),
                  childCount: _tasks.length,
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: 100.h)),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final typeIcon = switch (task.type) {
      TaskType.audio => Icons.mic,
      TaskType.image => Icons.image,
      TaskType.video => Icons.videocam,
      TaskType.text => Icons.text_fields,
    };
    final typeBg = switch (task.type) {
      TaskType.audio => const Color(0xFFF97316).withValues(alpha: 0.1),
      TaskType.image => AppColors.primary.withValues(alpha: 0.1),
      TaskType.video => AppColors.tertiaryContainer.withValues(alpha: 0.1),
      TaskType.text => const Color(0xFF059669).withValues(alpha: 0.1),
    };
    final typeFg = switch (task.type) {
      TaskType.audio => const Color(0xFFF97316),
      TaskType.image => AppColors.primary,
      TaskType.video => AppColors.tertiaryContainer,
      TaskType.text => const Color(0xFF059669),
    };
    final remaining = task.remainingQuantity;
    final isUrgent = task.deadline != null && task.deadline!.difference(DateTime.now()).inHours < 24;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 40, offset: const Offset(0, 20)), BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: () => context.push('/tasks/${task.id}'),
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(width: 48.w, height: 48.w, decoration: BoxDecoration(color: typeBg, shape: BoxShape.circle), child: Icon(typeIcon, size: 24.sp, color: typeFg)),
                      SizedBox(width: 12.w),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(task.title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                        SizedBox(height: 2.h),
                        Text('ID: ${task.id.substring(0, 8).toUpperCase()}', style: TextStyle(fontSize: 12.sp, color: AppColors.outline, letterSpacing: 0.5)),
                      ]),
                    ]),
                    RichText(text: TextSpan(children: [
                      TextSpan(text: '¥${task.unitPrice.toStringAsFixed(task.unitPrice.truncateToDouble() == task.unitPrice ? 0 : 2)}', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      TextSpan(text: '/${task.typeUnit}', style: TextStyle(fontSize: 14.sp, color: AppColors.outline, fontWeight: FontWeight.w400)),
                    ])),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(children: [
                  _infoChip(Icons.inventory_2_outlined, '剩余: $remaining${task.typeUnit}'),
                  SizedBox(width: 12.w),
                  _infoChip(Icons.schedule, isUrgent ? '截止: 今天 23:59' : '截止: ${_fmtDate(task.deadline)}', isUrgent: isUrgent),
                ]),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 40.h,
                      child: ElevatedButton(
                        onPressed: () => _claimTask(task),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          elevation: 0,
                          shadowColor: AppColors.primary.withValues(alpha: 0.2),
                        ),
                        child: Text('领取任务', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, {bool isUrgent = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(6.r)),
      child: Row(children: [
        Icon(icon, size: 14.sp, color: isUrgent ? AppColors.error : AppColors.onSurfaceVariant),
        SizedBox(width: 4.w),
        Text(text, style: TextStyle(fontSize: 12.sp, color: isUrgent ? AppColors.error : AppColors.onSurfaceVariant, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _claimTask(TaskModel task) async {
    try {
      final service = ref.read(taskServiceProvider);
      final claim = await service.claim(task.id);
      if (mounted) {
        final msg = claim.status == ClaimStatus.pendingApproval
            ? '任务「${task.title}」已申请，待后台审批'
            : '任务「${task.title}」领取成功！';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.secondary),
        );
        _loadTasks(); // refresh list
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '').replaceAll('DioException ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('领取失败: $msg'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '无期限';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
