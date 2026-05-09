import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/task_claim_model.dart';
import '../../../core/models/team_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/services/team_service.dart';
import '../../../shared/widgets/skeleton.dart';

/// Obsidian Amber task square — 任务大厅
/// Screen: 端云智采 - 任务大厅 (7e1db1fed0f143bbb1772b9d8797b313)

class TaskSquarePage extends ConsumerStatefulWidget {
  const TaskSquarePage({super.key});

  @override
  ConsumerState<TaskSquarePage> createState() => _TaskSquarePageState();
}

class _TaskSquarePageState extends ConsumerState<TaskSquarePage> {
  // ── Filter / Sort state ──
  int _selectedFilter = 0;
  String? _selectedTeamId;
  int _selectedSort = 0;

  // ── Data ──
  List<TaskModel> _tasks = [];
  List<TaskModel> _allTasks = [];
  List<TeamModel> _myTeams = [];
  bool _isLoading = true;

  // ── Search ──
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final _filterChips = ['全部', '音频', '视频', '图像', '文本'];
  final _sortChips = ['最新发布', '金额最高', '剩余最多'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // Data Loading (preserved business logic)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ref.read(taskServiceProvider).findAll(),
        ref.read(teamServiceProvider).getMyTeams(),
      ]);
      if (!mounted) return;
      final tasks = results[0] as List<TaskModel>;
      final teams = results[1] as List<TeamModel>;
      final teamIds = teams.map((t) => t.id).toSet();
      final accessible = tasks.where((t) {
        if (t.teamId == null) return true;
        return teamIds.contains(t.teamId);
      }).toList();
      setState(() {
        _allTasks = accessible;
        _myTeams = teams;
      });
      _applyFilters();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Filter / Sort / Search
  // ═══════════════════════════════════════════════════════════════

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _applyFilters();
  }

  void _applyFilters() {
    var filtered = _allTasks.toList();

    // Search by title
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Type filter
    String? type;
    if (_selectedFilter == 1) {
      type = 'audio';
    } else if (_selectedFilter == 2) {
      type = 'video';
    } else if (_selectedFilter == 3) {
      type = 'image';
    } else if (_selectedFilter == 4) {
      type = 'text';
    }
    if (type != null) {
      filtered = filtered.where((t) => t.type.name == type).toList();
    }

    // Team filter
    if (_selectedTeamId != null) {
      filtered = filtered.where((t) => t.teamId == _selectedTeamId).toList();
    }

    // Sort
    switch (_selectedSort) {
      case 1:
        filtered.sort((a, b) => b.unitPrice.compareTo(a.unitPrice));
        break;
      case 2:
        filtered.sort((a, b) => b.remainingQuantity.compareTo(a.remainingQuantity));
        break;
      default:
        break;
    }
    setState(() {
      _tasks = filtered;
      _isLoading = false;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // Claim Task (preserved business logic)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _claimTask(TaskModel task) async {
    try {
      final service = ref.read(taskServiceProvider);
      final claim = await service.claim(task.id);
      if (mounted) {
        final msg = claim.status == ClaimStatus.pendingApproval
            ? '任务「${task.title}」已申请，待后台审批'
            : '任务「${task.title}」领取成功！';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.secondary,
        ));
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        final msg =
            e.toString().replaceAll('Exception: ', '').replaceAll('DioException ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('领取失败: $msg'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tasks/create'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full)),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm.h)),
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm.h)),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm.h)),
            SliverToBoxAdapter(child: _buildFilterRow()),
            if (_myTeams.isNotEmpty)
              SliverToBoxAdapter(child: _buildTeamFilterRow()),
            SliverToBoxAdapter(child: _buildSortRow()),
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
                      Text(
                        '暂无任务',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  // ═══════════════════════════════════════════════════════════════
  // Header — cloud_sync + 端云智采 + notifications
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.cloud_sync_outlined, size: 26.sp, color: AppColors.primary),
            SizedBox(width: AppSpacing.sm.w),
            Text(
              '端云智采',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ]),
          Container(
            width: 40.w,
            height: 40.w,
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

  // ═══════════════════════════════════════════════════════════════
  // Search Bar — recessed well (surfaceDim bg + inner shadow)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
      child: Container(
        height: 44.h,
        decoration: BoxDecoration(
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
          border: Border.all(color: AppColors.outlineVariant, width: 1),
        ),
        child: Stack(
          children: [
            // Inner shadow overlay (recessed effect)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(fontSize: 14.sp, color: AppColors.onSurface),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: '搜索任务...',
                hintStyle: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.outline,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(Icons.search, size: 18.sp, color: AppColors.outline),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        child: Icon(Icons.clear, size: 16.sp, color: AppColors.outline),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 12.h),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Category Filter Row — chips (surfaceVariant / active primary)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildFilterRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.layoutMargin.w,
        AppSpacing.xs.h,
        AppSpacing.layoutMargin.w,
        AppSpacing.xs.h,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filterChips.length, (i) {
            final active = _selectedFilter == i;
            return Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm.w),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedFilter = i);
                  _applyFilters();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.20)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: active
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.40),
                            width: 1,
                          )
                        : null,
                  ),
                  child: Text(
                    _filterChips[i],
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Team Filter Row — secondary-colored chips
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTeamFilterRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.layoutMargin.w,
        0,
        AppSpacing.layoutMargin.w,
        AppSpacing.xs.h,
      ),
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
          _applyFilters();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: active
                ? AppColors.secondary.withValues(alpha: 0.20)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: active
                ? Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.40),
                    width: 1,
                  )
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              teamId == null ? Icons.public : Icons.group,
              size: 13.sp,
              color: active ? AppColors.secondary : AppColors.onSurfaceVariant,
            ),
            SizedBox(width: AppSpacing.xs.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: active ? AppColors.secondary : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Sort Row — label-caps + count display
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSortRow() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.layoutMargin.w,
        0,
        AppSpacing.layoutMargin.w,
        AppSpacing.xs.h,
      ),
      child: Row(
        children: [
          // Sort chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_sortChips.length, (i) {
                  final active = _selectedSort == i;
                  return Padding(
                    padding: EdgeInsets.only(right: AppSpacing.md.w),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedSort = i);
                        _applyFilters();
                      },
                      child: Text(
                        _sortChips[i],
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: active ? AppColors.primary : AppColors.outline,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Count display
          Text(
            '共 ${_tasks.length} 个任务',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Task Card — Obsidian Amber tactile card
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTaskCard(TaskModel task) {
    final typeCfg = _typeConfig(task.type);

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.listGap.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
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
                // ── Top row: type chip + title + price ──
                _buildTaskTopRow(task, typeCfg),
                SizedBox(height: AppSpacing.md.h),
                // ── Middle row: remaining + deadline ──
                _buildTaskInfoRow(task),
                SizedBox(height: AppSpacing.md.h),
                // ── Progress bar ──
                _buildProgressBar(task),
                SizedBox(height: AppSpacing.md.h),
                // ── Bottom: claim button (primaryContainer) ──
                _buildClaimButton(task),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top row: type chip | title | price ──

  Widget _buildTaskTopRow(TaskModel task, _TypeConfig typeCfg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type chip
        _buildTypeChip(task, typeCfg),
        SizedBox(width: AppSpacing.sm.w),
        // Title (flexible)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm.w),
        // Price (data-mono, primary)
        Text(
          '¥${task.unitPrice.toStringAsFixed(task.unitPrice.truncateToDouble() == task.unitPrice ? 0 : 2)}',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // ── Type chip: low-alpha bg + matching icon + matching text ──

  Widget _buildTypeChip(TaskModel task, _TypeConfig typeCfg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: typeCfg.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: typeCfg.color.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(typeCfg.icon, size: 14.sp, color: typeCfg.color),
        SizedBox(width: 4.w),
        Text(
          task.typeLabel,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: typeCfg.color,
            letterSpacing: 0.6,
          ),
        ),
      ]),
    );
  }

  // ── Middle row: remaining + deadline ──

  Widget _buildTaskInfoRow(TaskModel task) {
    return Row(children: [
      _buildInfoChip(
        Icons.inventory_2_outlined,
        '剩余 ${task.remainingQuantity}${task.typeUnit}',
      ),
      SizedBox(width: AppSpacing.sm.w),
      _buildDeadlineChip(task),
    ]);
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13.sp, color: AppColors.onSurfaceVariant),
        SizedBox(width: AppSpacing.xs.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ]),
    );
  }

  Widget _buildDeadlineChip(TaskModel task) {
    final hasDeadline = task.deadline != null;
    final isUrgent = hasDeadline &&
        task.deadline!.difference(DateTime.now()).inHours < 24;

    final iconColor = isUrgent ? AppColors.error : AppColors.onSurfaceVariant;
    final textColor = isUrgent ? AppColors.error : AppColors.onSurfaceVariant;
    final label = hasDeadline ? '截止 ${_formatDate(task.deadline)}' : '无期限';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.error.withValues(alpha: 0.10)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.schedule, size: 13.sp, color: iconColor),
        SizedBox(width: AppSpacing.xs.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: textColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ]),
    );
  }

  // ── Progress bar: surfaceDim bg (recessed), primary fill with glow ──

  Widget _buildProgressBar(TaskModel task) {
    final total = task.totalQuantity;
    // Hide progress bar if there's nothing to show
    if (total <= 0) return const SizedBox.shrink();
    final progress = (task.claimedQuantity / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: SizedBox(
        height: 4.h,
        child: Stack(
          children: [
            // Background track (recessed surfaceDim)
            Container(color: AppColors.surfaceDim),
            // Fill with glow
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: Offset.zero,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Claim button: primaryContainer bg + onPrimaryContainer text + arrow ──

  Widget _buildClaimButton(TaskModel task) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
          child: InkWell(
            onTap: () => _claimTask(task),
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '领取任务',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.arrow_forward,
                    size: 16.sp,
                    color: AppColors.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════

  _TypeConfig _typeConfig(TaskType type) => switch (type) {
    TaskType.audio => const _TypeConfig(Icons.mic, AppColors.orange),
    TaskType.image => const _TypeConfig(Icons.image, AppColors.primary),
    TaskType.video => const _TypeConfig(Icons.videocam, AppColors.tertiary),
    TaskType.text => const _TypeConfig(Icons.text_fields, AppColors.secondary),
  };

  String _formatDate(DateTime? dt) {
    if (dt == null) return '无期限';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _TypeConfig {
  final IconData icon;
  final Color color;
  const _TypeConfig(this.icon, this.color);
}
