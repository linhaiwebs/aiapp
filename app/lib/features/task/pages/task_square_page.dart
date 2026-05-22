import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/services/file_service.dart';
import '../../../shared/widgets/skeleton.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// 任务大厅 — 未领取的可用任务列表

class TaskSquarePage extends ConsumerStatefulWidget {
  const TaskSquarePage({super.key});

  @override
  ConsumerState<TaskSquarePage> createState() => _TaskSquarePageState();
}

class _TaskSquarePageState extends ConsumerState<TaskSquarePage> {
  List<TaskModel> _tasks = [];
  Set<String> _claimedTaskIds = {};
  String? _typeFilter;
  bool _isLoading = true;
  String? _claimingTaskId;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      // Read initial type filter from route extra
      final extra = GoRouterState.of(context).extra;
      if (extra is Map && extra['type'] is String && _typeFilter == null) {
        _typeFilter = extra['type'] as String;
      }
      final results = await Future.wait([
        ref.read(taskServiceProvider).findAll(type: _typeFilter),
        ref.read(taskServiceProvider).getMyClaims(),
      ]);
      final tasks = results[0] as List<TaskModel>;
      final claims = results[1] as List;
      final claimedIds = claims.map((c) => (c as dynamic).taskId as String).toSet();
      if (mounted) setState(() { _tasks = tasks; _claimedTaskIds = claimedIds; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _claimTask(TaskModel task) async {
    if (_claimingTaskId != null) return;

    // 采样审核：先弹采样录制
    if (task.requireSample) {
      final sampleFileId = await _showSampleRecording(task);
      if (sampleFileId == null) return; // 用户取消

      setState(() => _claimingTaskId = task.id);
      try {
        // 先领取（状态为 SAMPLE_REVIEW）
        final claimRes = await ref.read(taskServiceProvider).claim(task.id);
        final claimId = (claimRes as dynamic)['id'] as String;
        // 提交采样文件
        await ref.read(taskServiceProvider).submitSample(claimId, sampleFileId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('您的采样已经上传，请耐心等待管理员审核'), backgroundColor: AppColors.secondary),
          );
          context.go('/home');
        }
      } catch (e) {
        _showClaimError(e);
      } finally {
        if (mounted) setState(() => _claimingTaskId = null);
      }
      return;
    }

    // 正常领取流程
    setState(() => _claimingTaskId = task.id);
    try {
      await ref.read(taskServiceProvider).claim(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务领取成功'), backgroundColor: AppColors.secondary),
        );
        context.go('/home');
      }
    } catch (e) {
      _showClaimError(e);
    } finally {
      if (mounted) setState(() => _claimingTaskId = null);
    }
  }

  void _showClaimError(dynamic e) {
    if (!mounted) return;
    String msg = e.toString();
    try {
      final dioErr = e as dynamic;
      final serverMsg = dioErr.response?.data?.message;
      if (serverMsg is String && serverMsg.isNotEmpty) msg = serverMsg;
    } catch (_) {}
    String userMsg = '领取失败，请稍后重试';
    if (msg.contains('已申请') || msg.contains('已领取')) {
      userMsg = '您已领取过该任务，可在"我的任务"中查看';
    } else if (msg.contains('不可申请')) {
      userMsg = '任务当前不可申请';
    } else if (msg.contains('截止时间')) { userMsg = '任务已过截止时间'; }
    else if (msg.contains('质量分不足')) { userMsg = '质量分不足，无法申请此任务'; }
    else if (msg.contains('仅团队成员可领取')) { userMsg = '仅团队成员可领取此任务'; }
    else if (msg.contains('已被领完')) { userMsg = '任务已被领完'; }
    else if (msg.contains('封禁')) { userMsg = '账号已被封禁，无法申请任务'; }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMsg), backgroundColor: AppColors.error));
  }

  /// 采样录制弹窗，返回 fileId 或 null（取消）
  Future<String?> _showSampleRecording(TaskModel task) async {
    final recorder = AudioRecorder();
    bool hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      final granted = await Permission.microphone.request();
      if (!granted.isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('需要麦克风权限'), backgroundColor: AppColors.error));
        return null;
      }
    }

    // 取任务说明的前3段作为样音朗读文本
    final instructions = task.instructions ?? task.description ?? '';
    final sampleLines = instructions.split('\n').where((l) => l.trim().isNotEmpty).take(3).toList();
    final sampleText = sampleLines.isNotEmpty ? sampleLines.join('\n') : '请朗读一段语音';

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SampleRecordDialog(task: task, recorder: recorder, ref: ref),
    );
    recorder.dispose();
    return result;
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
    final isClaiming = _claimingTaskId == task.id;
    final isClaimed = _claimedTaskIds.contains(task.id);

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
              onTap: isClaimed ? null : () => _claimTask(task),
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
                      onTap: isClaimed ? null : () => _claimTask(task),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                        decoration: BoxDecoration(
                          color: isClaimed
                              ? AppColors.secondary.withValues(alpha: 0.08)
                              : isClaiming
                                  ? AppColors.primary.withValues(alpha: 0.06)
                                  : AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm.r),
                          border: Border.all(
                            color: isClaimed
                                ? AppColors.secondary.withValues(alpha: 0.3)
                                : AppColors.primary.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: isClaimed
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 16.sp, color: AppColors.secondary),
                                    SizedBox(width: 6.w),
                                    Text('已领取', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.secondary)),
                                  ],
                                )
                              : isClaiming
                                  ? SizedBox(
                                      width: 20.w,
                                      height: 20.w,
                                      child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    )
                                  : Text('领取任务', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
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

// ─── Sample Recording Dialog ───────────────────────────────────

class _SampleRecordDialog extends StatefulWidget {
  final TaskModel task;
  final AudioRecorder recorder;
  final WidgetRef ref;
  const _SampleRecordDialog({required this.task, required this.recorder, required this.ref});

  @override State<_SampleRecordDialog> createState() => _SampleRecordDialogState();
}

class _SampleRecordDialogState extends State<_SampleRecordDialog> {
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _uploadedFileId;

  final instructions = '';

  @override void initState() { super.initState(); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _start() async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/sample_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await widget.recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, numChannels: 1), path: path);
    setState(() { _isRecording = true; _seconds = 0; });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => _seconds++); });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await widget.recorder.stop();
    if (path == null || !mounted) { setState(() => _isRecording = false); return; }
    setState(() => _isRecording = false);
    try {
      final result = await widget.ref.read(fileServiceProvider).simpleUpload(path, taskId: widget.task.id, taskType: widget.task.type.name);
      if (mounted) setState(() => _uploadedFileId = result['id'] as String);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('上传失败: $e'), backgroundColor: AppColors.error));
    }
  }

  @override Widget build(BuildContext context) {
    final inst = widget.task.instructions ?? widget.task.description ?? '';
    final lines = inst.split('\n').where((l) => l.trim().isNotEmpty).take(3).toList();
    final sampleText = lines.isNotEmpty ? lines.join('\n') : '请朗读一段语音';

    return AlertDialog(
      title: Text('录制样音 - ${widget.task.title}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('请朗读以下文本作为采样', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
            child: Text(sampleText, style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFFE5E2E1))),
          ),
          const SizedBox(height: 16),
          if (_isRecording)
            Center(child: Text('录音中: ${_seconds}s', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.error)))
          else if (_uploadedFileId != null)
            const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, color: AppColors.secondary), SizedBox(width: 8), Text('采样已上传', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w600))]))
          else
            const Center(child: Text('点击下方按钮开始录制', style: TextStyle(fontSize: 14, color: Colors.grey))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () { _timer?.cancel(); Navigator.pop(context); }, child: const Text('取消')),
        if (!_isRecording && _uploadedFileId == null)
          ElevatedButton.icon(onPressed: _start, icon: const Icon(Icons.mic), label: const Text('开始录制'))
        else if (_isRecording)
          ElevatedButton.icon(onPressed: _stop, icon: const Icon(Icons.stop), label: const Text('停止录制'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white))
        else if (_uploadedFileId != null)
          ElevatedButton(onPressed: () { _timer?.cancel(); Navigator.pop(context, _uploadedFileId); }, child: const Text('提交采样')),
      ],
    );
  }
}
