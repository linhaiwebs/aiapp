import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/team_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/team_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/skeleton.dart';

class TeamListPage extends ConsumerStatefulWidget {
  const TeamListPage({super.key});

  @override
  ConsumerState<TeamListPage> createState() => _TeamListPageState();
}

class _TeamListPageState extends ConsumerState<TeamListPage> {
  List<TeamModel> _myTeams = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isJoining = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ref.read(teamServiceProvider).getMyTeams(),
        ref.read(authServiceProvider).getMe(),
      ]);
      if (mounted) {
        setState(() {
          _myTeams = results[0] as List<TeamModel>;
          _currentUser = results[1] as UserModel;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _canCreate => _currentUser != null &&
      (_currentUser!.role == UserRole.leader || _currentUser!.role == UserRole.superAdmin);

  Future<void> _joinTeam() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入口令'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      await ref.read(teamServiceProvider).joinByCode(code);
      _codeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加入团队成功！'), backgroundColor: AppColors.secondary),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入失败: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _showJoinTeamSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h + 4.h, AppSpacing.lg.w, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl.h),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36.w, height: 4.h, decoration: BoxDecoration(color: AppColors.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.r)))),
          SizedBox(height: 20.h),
          Text('加入团队', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          SizedBox(height: AppSpacing.md.h),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '加入口令',
              hintText: '请输入团长提供的8位口令',
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isJoining ? null : () async {
                await _joinTeam();
                if (mounted && ctx.mounted) {
                  ctx.pop();
                }
              },
              child: _isJoining
                  ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                  : Text('确认加入', style: TextStyle(fontSize: 15.sp, color: AppColors.onPrimary)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showCreateTeamSheet() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h + 4.h, AppSpacing.lg.w, MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl.h),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36.w, height: 4.h, decoration: BoxDecoration(color: AppColors.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.r)))),
          SizedBox(height: 20.h),
          Text('创建团队', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          SizedBox(height: AppSpacing.md.h),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '团队名称',
              hintText: '给你的团队起个名字',
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: '团队描述（可选）',
              hintText: '简单描述团队的目标',
            ),
            maxLines: 2,
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                try {
                  await ref.read(teamServiceProvider).create({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                  });
                  if (ctx.mounted) {
                    ctx.pop();
                  }
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('团队创建成功！'), backgroundColor: AppColors.secondary),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('创建失败: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: Text('确认创建', style: TextStyle(fontSize: 15.sp, color: AppColors.onPrimary)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('团队', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.background,
      ),
      body: _isLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: SkeletonTeamList()))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.all(AppSpacing.md.w),
                children: [
                  _buildActionButtons(),
                  SizedBox(height: AppSpacing.lg.h),
                  _buildSectionTitle('我的团队 (${_myTeams.length})'),
                  SizedBox(height: AppSpacing.sm.h),
                  if (_myTeams.isEmpty)
                    _buildEmptyState()
                  else
                    ..._myTeams.map((team) => _buildTeamCard(team)),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (_canCreate) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _showCreateTeamSheet,
              icon: Icon(Icons.add, size: 18.sp),
              label: Text('创建团队', style: TextStyle(fontSize: 14.sp)),
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showJoinTeamSheet,
            icon: Icon(Icons.group_add, size: 18.sp),
            label: Text('加入团队', style: TextStyle(fontSize: 14.sp)),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Text('暂无团队', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)),
      ),
    );
  }

  Widget _buildTeamCard(TeamModel team) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: () => context.push('/teams/${team.id}'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md.w),
            child: Row(children: [
              Container(
                width: 44.w, height: 44.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.group, size: 22.sp, color: AppColors.primary),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Text(team.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              ),
              Text('${team.members.length} 人', style: TextStyle(fontSize: 13.sp, color: AppColors.onSurfaceVariant)),
              SizedBox(width: AppSpacing.xs.w),
              Icon(Icons.chevron_right, size: 20.sp, color: AppColors.outline),
            ]),
          ),
        ),
      ),
    );
  }
}
