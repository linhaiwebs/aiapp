import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/project_model.dart';
import '../../../core/services/task_service.dart';
import '../../../core/services/project_service.dart';

class TaskCreatePage extends ConsumerStatefulWidget {
  final String? teamId;
  const TaskCreatePage({super.key, this.teamId});

  @override
  ConsumerState<TaskCreatePage> createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends ConsumerState<TaskCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _unitPriceCtrl = TextEditingController(text: '1.0');
  final _totalQtyCtrl = TextEditingController(text: '100');
  final _textPerUserCtrl = TextEditingController();

  TaskType _selectedType = TaskType.audio;
  TaskDifficulty _selectedDifficulty = TaskDifficulty.easy;
  String? _selectedProjectId;
  DateTime? _deadline;

  List<ProjectModel> _projects = [];
  bool _loadingProjects = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _unitPriceCtrl.dispose();
    _totalQtyCtrl.dispose();
    _textPerUserCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await ref.read(projectServiceProvider).findAll();
      if (mounted) {
        setState(() {
          _projects = projects.where((p) {
            if (!p.isActive) return false;
            if (widget.teamId != null) return p.teamId == widget.teamId;
            return true;
          }).toList();
          _loadingProjects = false;
          if (widget.teamId != null && _projects.isNotEmpty && _selectedProjectId == null) {
            _selectedProjectId = _projects.first.id;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.onPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'type': _selectedType.name,
        'difficulty': _selectedDifficulty.name,
        'unitPrice': double.tryParse(_unitPriceCtrl.text) ?? 1.0,
        'totalQuantity': int.tryParse(_totalQtyCtrl.text) ?? 100,
        'status': 'published',
      };

      if (_descCtrl.text.trim().isNotEmpty) {
        data['description'] = _descCtrl.text.trim();
      }
      if (_selectedProjectId != null) {
        data['projectId'] = _selectedProjectId;
      }
      if (widget.teamId != null) {
        data['teamId'] = widget.teamId;
      }
      if (_deadline != null) {
        data['deadline'] = _deadline!.toIso8601String();
      }

      // Text-specific: per-user count
      if (_selectedType == TaskType.text) {
        final perUser = int.tryParse(_textPerUserCtrl.text);
        if (perUser != null && perUser > 0) {
          data['textPerUserCount'] = perUser;
        }
      }

      await ref.read(taskServiceProvider).create(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务创建成功'), backgroundColor: AppColors.secondary),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '').replaceAll('DioException ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $msg'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('创建任务', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.surfaceContainerLowest,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.w),
          children: [
            // Type selector
            Text('采集类型', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 0.6)),
            SizedBox(height: 8.h),
            Row(children: TaskType.values.map((t) {
              final active = _selectedType == t;
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = t),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: active ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_typeIcon(t), size: 16.sp, color: active ? AppColors.primary : AppColors.onSurfaceVariant),
                      SizedBox(width: 4.w),
                      Text(_typeLabel(t), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: active ? AppColors.primary : AppColors.onSurfaceVariant)),
                    ]),
                  ),
                ),
              );
            }).toList()),
            SizedBox(height: 20.h),

            // Title
            TextFormField(
              controller: _titleCtrl,
              style: TextStyle(fontSize: 15.sp, color: AppColors.onSurface),
              decoration: const InputDecoration(labelText: '任务标题', hintText: '请输入任务名称'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入任务标题' : null,
            ),
            SizedBox(height: 16.h),

            // Description
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              style: TextStyle(fontSize: 15.sp, color: AppColors.onSurface),
              decoration: const InputDecoration(labelText: '任务描述', hintText: '对任务内容和要求的简要描述'),
            ),
            SizedBox(height: 16.h),

            // Project
            Text('归属项目', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 0.6)),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.outlineVariant, width: 1),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedProjectId,
                  isExpanded: true,
                  dropdownColor: AppColors.surfaceContainer,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.outline),
                  style: TextStyle(fontSize: 14.sp, color: AppColors.onSurface),
                  hint: Text(_loadingProjects ? '加载中...' : '选择项目（可选）', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('无（独立任务）', style: TextStyle(color: AppColors.onSurfaceVariant)),
                    ),
                    ..._projects.map((p) => DropdownMenuItem<String?>(
                          value: p.id,
                          child: Text(p.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedProjectId = v),
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Difficulty
            Text('难度等级', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 0.6)),
            SizedBox(height: 8.h),
            Row(children: TaskDifficulty.values.map((d) {
              final active = _selectedDifficulty == d;
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDifficulty = d),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: active ? _difficultyColor(d).withValues(alpha: 0.1) : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: active ? Border.all(color: _difficultyColor(d).withValues(alpha: 0.4)) : null,
                    ),
                    child: Text(_difficultyLabel(d), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: active ? _difficultyColor(d) : AppColors.onSurfaceVariant)),
                  ),
                ),
              );
            }).toList()),
            SizedBox(height: 20.h),

            // Unit price + total quantity row
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _unitPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(fontSize: 15.sp, color: AppColors.onSurface),
                  decoration: const InputDecoration(labelText: '单价 (元)', hintText: '如 1.0'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入单价';
                    if (double.tryParse(v) == null) return '无效数字';
                    return null;
                  },
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextFormField(
                  controller: _totalQtyCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 15.sp, color: AppColors.onSurface),
                  decoration: const InputDecoration(labelText: '总数量', hintText: '如 100'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入总数量';
                    if (int.tryParse(v) == null) return '无效数字';
                    return null;
                  },
                ),
              ),
            ]),
            SizedBox(height: 16.h),

            // Text-specific: per-user count (only for text type)
            if (_selectedType == TaskType.text)
              Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: TextFormField(
                  controller: _textPerUserCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 15.sp, color: AppColors.onSurface),
                  decoration: const InputDecoration(
                    labelText: '每人条数',
                    hintText: '平均每人分配X条，0=自动',
                  ),
                ),
              ),

            // Deadline
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.outlineVariant, width: 1),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today, size: 18.sp, color: AppColors.outline),
                  SizedBox(width: 12.w),
                  Text(
                    _deadline != null
                        ? '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'
                        : '截止日期（可选）',
                    style: TextStyle(fontSize: 14.sp, color: _deadline != null ? AppColors.onSurface : AppColors.outline),
                  ),
                ]),
              ),
            ),
            SizedBox(height: 32.h),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                    : Text('创建任务', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
              ),
            ),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(TaskType t) => switch (t) {
        TaskType.audio => Icons.mic,
        TaskType.image => Icons.image,
        TaskType.video => Icons.videocam,
        TaskType.text => Icons.text_fields,
      };

  String _typeLabel(TaskType t) => switch (t) {
        TaskType.audio => '音频',
        TaskType.image => '图像',
        TaskType.video => '视频',
        TaskType.text => '文本',
      };

  Color _difficultyColor(TaskDifficulty d) => switch (d) {
        TaskDifficulty.easy => AppColors.secondary,
        TaskDifficulty.medium => AppColors.orange,
        TaskDifficulty.hard => AppColors.error,
      };

  String _difficultyLabel(TaskDifficulty d) => switch (d) {
        TaskDifficulty.easy => '简单',
        TaskDifficulty.medium => '中等',
        TaskDifficulty.hard => '困难',
      };
}
