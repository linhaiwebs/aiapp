import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/services/task_service.dart';

/// Obsidian Amber task detail — 任务详情
/// Screen: 端云智采 - 任务详情 (46542dd8dc1640f6b7ff459a0b469941)

class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  TaskModel? _task;
  bool _isLoading = true;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  // ═══════════════════════════════════════════════════════════════
  // Business Logic (PRESERVED)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadTask() async {
    try {
      final task = await ref.read(taskServiceProvider).findOne(widget.taskId);
      if (mounted) setState(() { _task = task; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    try {
      await ref.read(taskServiceProvider).claim(widget.taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('申请已提交，等待审核员审批'), backgroundColor: AppColors.secondary),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        // 解析服务器返回的具体错误信息
        String userMsg = '领取失败，请稍后重试';
        if (msg.contains('已申请') || msg.contains('已领取')) {
          userMsg = '您已领取过该任务，可在"我的任务"中查看';
        } else if (msg.contains('不可申请')) {
          userMsg = '任务当前不可申请';
        } else if (msg.contains('截止时间')) {
          userMsg = '任务已过截止时间';
        } else if (msg.contains('质量分不足')) {
          userMsg = '质量分不足，无法申请此任务';
        } else if (msg.contains('仅团队成员可领取')) {
          userMsg = '仅团队成员可领取此任务';
        } else if (msg.contains('已被领完')) {
          userMsg = '任务已被领完';
        } else if (msg.contains('封禁')) {
          userMsg = '账号已被封禁，无法申请任务';
        } else if (msg.contains('Exception') || msg.contains('Error')) {
          // 提取服务器返回的异常消息
          final start = msg.indexOf(': ');
          if (start > 0) {
            userMsg = msg.substring(start + 2);
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMsg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  // ── Task type icon getter (PRESERVED) ──
  IconData _taskTypeIcon(TaskType type) => switch (type) {
    TaskType.audio => Icons.mic,
    TaskType.image => Icons.image,
    TaskType.video => Icons.videocam,
    TaskType.text => Icons.article,
  };

  // ── Status color (PRESERVED) ──
  Color _statusColor(TaskStatus status) => switch (status) {
    TaskStatus.published => AppColors.primary,
    TaskStatus.inProgress => AppColors.secondary,
    TaskStatus.completed => AppColors.secondary,
    TaskStatus.closed => AppColors.error,
    TaskStatus.archived => AppColors.onSurfaceVariant,
    TaskStatus.draft => AppColors.orange,
  };

  // ── Difficulty color (PRESERVED) ──
  Color _difficultyColor(TaskDifficulty difficulty) => switch (difficulty) {
    TaskDifficulty.easy => AppColors.secondary,
    TaskDifficulty.medium => AppColors.orange,
    TaskDifficulty.hard => AppColors.error,
  };

  // ═══════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _task == null
              ? Center(
                  child: Text(
                    '任务不存在',
                    style: TextStyle(color: AppColors.outline, fontSize: 14.sp),
                  ),
                )
              : Stack(
                  children: [
                    // ── Scrollable content ──
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          top: kToolbarHeight + MediaQuery.of(context).padding.top + 8.h,
                          bottom: 120.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroCard(),
                            SizedBox(height: AppSpacing.md.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                              child: _buildInfoGrid(),
                            ),
                            if (_hasAdditionalInfo) ...[
                              SizedBox(height: AppSpacing.md.h),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                                child: _buildAdditionalInfo(),
                              ),
                            ],
                            if (_task!.instructions != null && _task!.instructions!.isNotEmpty) ...[
                              SizedBox(height: AppSpacing.md.h),
                              _buildRequirements(),
                            ],
                            if (_task!.description != null && _task!.description!.isNotEmpty) ...[
                              SizedBox(height: AppSpacing.md.h),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
                                child: _buildDescriptionCard(),
                              ),
                            ],
                            if (_task!.type == TaskType.audio) ...[
                              SizedBox(height: AppSpacing.md.h),
                              _buildTypeConfigSection(),
                            ],
                            SizedBox(height: AppSpacing.md.h),
                            _buildQualityStandards(),
                            if (_hasAssistFeatures) ...[
                              SizedBox(height: AppSpacing.md.h),
                              _buildAssistFeatures(),
                            ],
                            SizedBox(height: AppSpacing.md.h),
                            _buildSampleImageCard(),
                          ],
                        ),
                      ),
                    ),
                    // ── Bottom action bar (glass panel) ──
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomBar(),
                    ),
                  ],
                ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AppBar — Glass panel with backdrop blur
  // ═══════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, size: 22.sp, color: AppColors.onSurface),
        onPressed: () => context.pop(),
      ),
      title: Text(
        '任务详情',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert, size: 22.sp, color: AppColors.onSurface),
          onPressed: () {},
        ),
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.80),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.separator.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              boxShadow: AppShadows.topBar,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Hero Card — gradient top edge, neomorph raised, rounded-28px
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroCard() {
    final task = _task!;
    final now = DateTime.now();
    final isUrgent = task.deadline != null &&
        task.deadline!.isAfter(now) &&
        task.deadline!.difference(now).inHours < 24;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Gradient top edge ──
            Container(
              height: 4.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.card.r),
                ),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                ),
              ),
            ),
            // ── Card content ──
            Padding(
              padding: EdgeInsets.all(AppSpacing.cardPadding.w),
              child: Column(
                children: [
                  // Task type icon in colored circle
                  Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.30),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      _taskTypeIcon(task.type),
                      size: 32.sp,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md.h),

                  // Title h2
                  Text(
                    task.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm.h),

                  // Status chips row
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    alignment: WrapAlignment.center,
                    children: [
                      _chip(task.typeLabel, AppColors.primary),
                      _chip(task.statusLabel, _statusColor(task.status)),
                      _chip(
                        task.difficulty.name == 'easy'
                            ? '简单'
                            : task.difficulty.name == 'medium'
                                ? '中等'
                                : '困难',
                        _difficultyColor(task.difficulty),
                      ),
                      if (task.region != null && task.region!.isNotEmpty)
                        _chip(task.region!, AppColors.onSurfaceVariant),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md.h),

                  // Price & deadline info row (data-mono style)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Unit price
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: '¥${task.unitPrice.toStringAsFixed(task.unitPrice.truncateToDouble() == task.unitPrice ? 0 : 2)}',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' /${task.typeUnit}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.outline,
                            ),
                          ),
                        ]),
                      ),
                      if (task.deadline != null) ...[
                        SizedBox(width: AppSpacing.md.w),
                        Container(
                          width: 1,
                          height: 16.h,
                          color: AppColors.outlineVariant.withValues(alpha: 0.5),
                        ),
                        SizedBox(width: AppSpacing.md.w),
                        Icon(
                          Icons.schedule,
                          size: 14.sp,
                          color: isUrgent ? AppColors.orange : AppColors.outline,
                        ),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: Text(
                            task.deadline!.toLocal().toString().split('.').first,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: isUrgent ? AppColors.orange : AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUrgent) ...[
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm.r),
                            ),
                            child: Text(
                              '即将截止',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  // ═══════════════════════════════════════════════════════════════
  // Info Grid — 3 columns, neomorph-inner, surfaceContainerLowest
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInfoGrid() {
    final task = _task!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.30),
          width: 1,
        ),
        // Neomorph-inner: dark inner shadow effect
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          _gridItem(
            Icons.monetization_on_outlined,
            '¥${task.unitPrice.toStringAsFixed(task.unitPrice.truncateToDouble() == task.unitPrice ? 0 : 2)}',
            '单价',
            AppColors.primary,
          ),
          _gridItem(
            Icons.inventory_2_outlined,
            '${task.remainingQuantity}',
            '剩余',
            AppColors.onSurface,
          ),
          _gridItem(
            Icons.schedule_outlined,
            '${task.recycleHours}h',
            '回收周期',
            AppColors.onSurface,
          ),
        ],
      ),
    );
  }

  Widget _gridItem(IconData icon, String value, String label, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22.sp, color: valueColor),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Additional Info — project, category, language, total, difficulty
  // ═══════════════════════════════════════════════════════════════

  bool get _hasAdditionalInfo {
    final task = _task!;
    return task.projectId != null ||
        task.categoryId != null ||
        (task.region != null && task.region!.isNotEmpty) ||
        (task.language != null && task.language!.isNotEmpty);
  }

  Widget _buildAdditionalInfo() {
    final task = _task!;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.cardPadding.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: AppSpacing.cardPadding.w,
        runSpacing: AppSpacing.sm.h,
        children: [
          if (task.projectId != null) _labelValue('项目', task.projectId!),
          if (task.categoryId != null) _labelValue('分类', task.categoryId!),
          if (task.region != null && task.region!.isNotEmpty)
            _labelValue('地区', task.region!),
          if (task.language != null && task.language!.isNotEmpty)
            _labelValue('语言', task.language!),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Description Card
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.cardPadding.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _innerSectionTitle('任务描述'),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            _task!.description!,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Requirements — numbered steps in surfaceContainerLowest blocks
  // ═══════════════════════════════════════════════════════════════

  Widget _buildRequirements() {
    final instructions = _task!.instructions!;
    // Split by newlines for numbered steps; fallback to single block
    final lines = instructions
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('采集要求', Icons.assignment_outlined),
        SizedBox(height: AppSpacing.sm.h),
        ...List.generate(lines.length, (i) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.layoutMargin.w,
              right: AppSpacing.layoutMargin.w,
              bottom: AppSpacing.sm.h,
            ),
            child: _requirementStep(i + 1, lines[i]),
          );
        }),
      ],
    );
  }

  Widget _requirementStep(int index, String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
            ),
            child: Center(
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.onSurface,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Type-specific Config (Audio)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTypeConfigSection() {
    final task = _task!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('音频配置', Icons.settings_voice_outlined),
        SizedBox(height: AppSpacing.sm.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.cardPadding.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Wrap(
              spacing: AppSpacing.cardPadding.w,
              runSpacing: AppSpacing.sm.h,
              children: [
                if (task.audioFormat != null)
                  _infoItem('格式', task.audioFormat!.name.toUpperCase()),
                if (task.audioChannel != null)
                  _infoItem('声道', task.audioChannel == AudioChannel.mono ? '单声道' : '双声道'),
                if (task.sampleRate != null)
                  _infoItem('采样率', '${task.sampleRate!.label} Hz'),
                if (task.noiseLimit != null)
                  _infoItem('噪音上限', '${task.noiseLimit}'),
                if (task.maxSpeechLength != null)
                  _infoItem('最大语音长度', '${task.maxSpeechLength}s'),
                if (task.silencePadding != null)
                  _infoItem('静音预留', '${task.silencePadding}ms'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Quality Standards — key-value rows
  // ═══════════════════════════════════════════════════════════════

  Widget _buildQualityStandards() {
    final task = _task!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('质量标准', Icons.verified_outlined),
        SizedBox(height: AppSpacing.sm.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.cardPadding.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                if (task.qcMethod != null)
                  _qualityRow(
                    '质检方式',
                    task.qcMethod == QcMethod.spotCheck ? '一轮抽样' : '人工抽样',
                    Icons.fact_check_outlined,
                  ),
                _qualityRow(
                  '验收轮数',
                  '${task.reviewRounds}轮',
                  Icons.replay_outlined,
                ),
                _qualityRow(
                  '回收时间',
                  '${task.recycleHours}小时',
                  Icons.timer_outlined,
                ),
                _qualityRow(
                  '通过率要求',
                  '${(task.passRateRequirement * 100).toStringAsFixed(0)}%',
                  Icons.trending_up,
                ),
                _qualityRow(
                  '最低质量分',
                  '${task.minQualityScore.toStringAsFixed(0)}分',
                  Icons.grade_outlined,
                ),
                _qualityRow(
                  '多次领取',
                  task.allowMultipleClaims ? '允许' : '不允许',
                  Icons.repeat_outlined,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _qualityRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.onSurfaceVariant),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Assist Features
  // ═══════════════════════════════════════════════════════════════

  bool get _hasAssistFeatures {
    final task = _task!;
    return task.silenceDetection ||
        task.gainDetection ||
        task.signalDetection;
  }

  Widget _buildAssistFeatures() {
    final task = _task!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('辅助功能', Icons.auto_awesome_outlined),
        SizedBox(height: AppSpacing.sm.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.cardPadding.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                if (task.silenceDetection) _assistTag('静音检测'),
                if (task.gainDetection) _assistTag('增幅检测'),
                if (task.signalDetection) _assistTag('信号检测'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _assistTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14.sp, color: AppColors.primary),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Sample Image Card — rounded container with approved badge overlay
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSampleImageCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('合格示例', Icons.image_outlined),
        SizedBox(height: AppSpacing.sm.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.layoutMargin.w),
          child: Container(
            width: double.infinity,
            height: 200.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                // Placeholder image area
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 48.sp,
                        color: AppColors.outline.withValues(alpha: 0.25),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      Text(
                        '暂无示例图片',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AppColors.outline.withValues(alpha: 0.40),
                        ),
                      ),
                    ],
                  ),
                ),
                // Approved badge overlay
                Positioned(
                  top: 12.h,
                  right: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.50),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14.sp, color: AppColors.secondary),
                        SizedBox(width: 4.w),
                        Text(
                          '合格示例',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Bottom Action Bar — glass panel, full-width primary button
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomBar() {
    final task = _task!;
    final canApply = task.status == TaskStatus.published || task.status == TaskStatus.inProgress;

    return SafeArea(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.layoutMargin.w),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.80),
              border: Border(
                top: BorderSide(
                  color: AppColors.separator.withValues(alpha: 0.20),
                  width: 1,
                ),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: (_isApplying || !canApply) ? null : _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  disabledBackgroundColor: AppColors.surfaceContainerHigh,
                  disabledForegroundColor: AppColors.outline,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                  ),
                  textStyle: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: _isApplying
                    ? SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : Text(
                        canApply ? '开始任务' : task.statusLabel,
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Shared Helpers
  // ═══════════════════════════════════════════════════════════════

  /// Section header with icon + label-caps text
  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.layoutMargin.w,
        0,
        AppSpacing.layoutMargin.w,
        0,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.primary),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Inner section title for cards (no icon)
  Widget _innerSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }

  /// Status / type chip: low-alpha bg + border, matching text
  Widget _chip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// Info item for type config grids
  Widget _infoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, color: AppColors.outline),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  /// Label-value pair for additional info section
  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.outline,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
