import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/services/task_service.dart';

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
          SnackBar(content: const Text('申请已提交，等待审核员审批'), backgroundColor: AppColors.secondary),
        );
        context.go('/my-tasks');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('申请失败: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: AppColors.background, title: Text('任务详情', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _task == null
              ? Center(child: Text('任务不存在', style: TextStyle(color: AppColors.outline)))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Header
                    Text(_task!.title, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                    SizedBox(height: 12.h),
                    // Chips
                    Wrap(spacing: 8.w, runSpacing: 8.h, children: [
                      _chip(_task!.typeLabel, AppColors.primary),
                      _chip(_task!.difficulty.name == 'easy' ? '简单' : _task!.difficulty.name == 'medium' ? '中等' : '困难', AppColors.orange),
                      if (_task!.region != null) _chip(_task!.region!, AppColors.onSurfaceVariant),
                    ]),
                    SizedBox(height: 20.h),
                    // Price & remaining
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12.r)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        RichText(text: TextSpan(children: [
                          TextSpan(text: '¥${_task!.unitPrice.toStringAsFixed(_task!.unitPrice.truncateToDouble() == _task!.unitPrice ? 0 : 2)}', style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          TextSpan(text: '/${_task!.typeUnit}', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)),
                        ])),
                        Text('剩余 ${_task!.remainingQuantity} ${_task!.typeUnit}', style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant)),
                      ]),
                    ),
                    SizedBox(height: 24.h),
                    if (_task!.description != null) ...[
                      _sectionTitle('任务描述'),
                      SizedBox(height: 8.h),
                      Text(_task!.description!, style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant, height: 1.7)),
                      SizedBox(height: 16.h),
                    ],
                    if (_task!.instructions != null) ...[
                      _sectionTitle('采集要求'),
                      SizedBox(height: 8.h),
                      Text(_task!.instructions!, style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant, height: 1.7)),
                      SizedBox(height: 16.h),
                    ],
                    // Audio config section
                    if (_task!.type == TaskType.audio) ...[
                      _sectionTitle('音频配置'),
                      SizedBox(height: 8.h),
                      _buildInfoGrid([
                        if (_task!.audioFormat != null) _infoItem('格式', _task!.audioFormat!.name.toUpperCase()),
                        if (_task!.audioChannel != null) _infoItem('声道', _task!.audioChannel == AudioChannel.mono ? '单声道' : '双声道'),
                        if (_task!.sampleRate != null) _infoItem('采样率', '${_task!.sampleRate!.label} Hz'),
                        if (_task!.noiseLimit != null) _infoItem('噪音上限', '${_task!.noiseLimit}'),
                        if (_task!.maxSpeechLength != null) _infoItem('最大语音长度', '${_task!.maxSpeechLength}s'),
                        if (_task!.silencePadding != null) _infoItem('静音预留', '${_task!.silencePadding}ms'),
                      ]),
                      SizedBox(height: 16.h),
                    ],
                    // QC config section
                    _sectionTitle('质检配置'),
                    SizedBox(height: 8.h),
                    _buildInfoGrid([
                      if (_task!.qcMethod != null) _infoItem('质检方式', _task!.qcMethod == QcMethod.spotCheck ? '一轮抽样' : '人工抽样'),
                      _infoItem('验收轮数', '${_task!.reviewRounds}轮'),
                      _infoItem('回收时间', '${_task!.recycleHours}小时'),
                      _infoItem('多次领取', _task!.allowMultipleClaims ? '允许' : '不允许'),
                    ]),
                    SizedBox(height: 16.h),
                    // Machine assist section
                    if (_task!.assistRecognition || _task!.silenceDetection || _task!.voiceprintDetection || _task!.gainDetection || _task!.signalDetection) ...[
                      _sectionTitle('辅助功能'),
                      SizedBox(height: 8.h),
                      Wrap(spacing: 8.w, runSpacing: 8.h, children: [
                        if (_task!.assistRecognition) _assistTag('辅助识别'),
                        if (_task!.silenceDetection) _assistTag('静音检测'),
                        if (_task!.voiceprintDetection) _assistTag('声纹检测'),
                        if (_task!.gainDetection) _assistTag('增幅检测'),
                        if (_task!.signalDetection) _assistTag('信号检测'),
                      ]),
                      SizedBox(height: 16.h),
                    ],
                    if (_task!.deadline != null) ...[
                      _sectionTitle('截止时间'),
                      SizedBox(height: 8.h),
                      Text(_task!.deadline!.toLocal().toString().split('.').first, style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant)),
                    ],
                  ]),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: SizedBox(
            width: double.infinity, height: 48.h,
            child: ElevatedButton(
              onPressed: _isApplying ? null : _apply,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))),
              child: _isApplying
                  ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                  : Text('申请任务', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6.r)),
      child: Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: color)),
    );
  }

  Widget _assistTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6.r)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle, size: 14.sp, color: AppColors.primary),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontSize: 12.sp, color: AppColors.primary)),
      ]),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface));
  }

  Widget _buildInfoGrid(List<Widget> items) {
    return Wrap(spacing: 16.w, runSpacing: 8.h, children: items);
  }

  Widget _infoItem(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11.sp, color: AppColors.outline)),
      SizedBox(height: 2.h),
      Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.onSurface)),
    ]);
  }
}
