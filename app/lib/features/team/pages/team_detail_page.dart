import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../core/models/team_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/team_service.dart';
import '../../../core/services/auth_service.dart';

class TeamDetailPage extends ConsumerStatefulWidget {
  final String teamId;
  const TeamDetailPage({super.key, required this.teamId});

  @override
  ConsumerState<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends ConsumerState<TeamDetailPage> {
  TeamModel? _team;
  List<TeamMemberModel> _members = [];
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ref.read(teamServiceProvider).findOne(widget.teamId),
        ref.read(teamServiceProvider).getMembers(widget.teamId),
        ref.read(authServiceProvider).getMe(),
      ]);
      if (mounted) {
        setState(() {
          _team = results[0] as TeamModel;
          _members = results[1] as List<TeamMemberModel>;
          _currentUser = results[2] as UserModel;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isLeader => _currentUser != null && _team != null &&
      _members.any((m) => m.userId == _currentUser!.id && m.role == 'leader');
  bool get _isMember => _currentUser != null &&
      _members.any((m) => m.userId == _currentUser!.id && m.isApproved);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_team?.name ?? '团队详情',
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        actions: [
          if (_isLeader)
            IconButton(
              onPressed: _showEditTeamDialog,
              icon: Icon(Icons.edit_outlined, size: 20.sp),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(16), child: SkeletonTeamList(count: 6)))
          : _buildMemberList(),
    );
  }

  Widget _buildMemberList() {
    final approved = _members.where((m) => m.isApproved).toList();
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.all(AppSpacing.md.w),
        children: [
          _buildTeamInfoCard(),
          SizedBox(height: AppSpacing.lg.h),
          _buildActionButtons(),
          SizedBox(height: AppSpacing.lg.h),
          _buildSectionHeader('团队成员 (${approved.length})',
              onAdd: _isLeader ? _showAddMemberSheet : null),
          SizedBox(height: AppSpacing.sm.h),
          if (approved.isEmpty)
            _buildEmptyMembers()
          else
            ...approved.map(_buildMemberTile),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  Widget _buildTeamInfoCard() {
    final hasJoinCode = _isLeader && _team?.joinCode != null && _team!.joinCode.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48.w, height: 48.w,
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(Icons.group, size: 24.sp, color: Colors.white),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_team?.name ?? '',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white)),
              if (_team?.description != null && _team!.description!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text(_team!.description!,
                      style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.8))),
                ),
            ]),
          ),
        ]),
        SizedBox(height: AppSpacing.md.h),
        Row(children: [
          Icon(Icons.people_outline, size: 16.sp, color: Colors.white.withValues(alpha: 0.8)),
          SizedBox(width: AppSpacing.xs.w),
          Text('${_members.where((m) => m.isApproved).length} 人',
              style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.w500)),
        ]),
        if (hasJoinCode) ...[
          SizedBox(height: AppSpacing.sm.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              Icon(Icons.vpn_key_outlined, size: 16.sp, color: Colors.white.withValues(alpha: 0.8)),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Text('加入口令: ${_team?.joinCode ?? '-'}',
                    style: TextStyle(fontSize: 14.sp, color: Colors.white, fontWeight: FontWeight.w500)),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _team?.joinCode ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('口令已复制'), backgroundColor: AppColors.secondary),
                  );
                },
                child: Icon(Icons.copy, size: 18.sp, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildActionButtons() {
    if (_isLeader) {
      return ElevatedButton.icon(
        onPressed: _showAddMemberSheet,
        icon: Icon(Icons.person_add, size: 18.sp),
        label: Text('邀请成员', style: TextStyle(fontSize: 14.sp)),
        style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 48.h)),
      );
    }

    if (_isMember) {
      return OutlinedButton.icon(
        onPressed: _confirmLeaveTeam,
        icon: Icon(Icons.exit_to_app, size: 18.sp),
        label: Text('退出团队', style: TextStyle(fontSize: 14.sp)),
        style: OutlinedButton.styleFrom(
          minimumSize: Size(double.infinity, 48.h),
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onAdd}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 16.sp, color: AppColors.primary),
                SizedBox(width: AppSpacing.xs.w),
                Text('添加', style: TextStyle(fontSize: 13.sp, color: AppColors.primary, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyMembers() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
        child: Text('暂无成员', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)),
      ),
    );
  }

  Widget _buildMemberTile(TeamMemberModel member) {
    final isMe = member.userId == _currentUser?.id;
    final isLeader = member.role == 'leader';
    final joinDate = _formatDate(member.createdAt);

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: isMe
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Container(
          width: 40.w, height: 40.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLeader
                  ? [AppColors.orange, AppColors.orange.withValues(alpha: 0.7)]
                  : [AppColors.primary.withValues(alpha: 0.6), AppColors.primary.withValues(alpha: 0.3)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Center(
            child: Text(member.displayLabel.substring(0, 1).toUpperCase(),
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
        SizedBox(width: AppSpacing.sm.w),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(member.displayLabel,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500, color: AppColors.onSurface),
                    overflow: TextOverflow.ellipsis),
              ),
              if (isMe) ...[
                SizedBox(width: AppSpacing.xs.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w, vertical: 2.h),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text('我', style: TextStyle(fontSize: 10.sp, color: AppColors.primary)),
                ),
              ],
            ]),
            SizedBox(height: AppSpacing.xs.h),
            Row(children: [
              _buildRoleChip(member.role == 'leader', isLeader ? '负责人' : '成员'),
              SizedBox(width: AppSpacing.sm.w),
              Text(joinDate, style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
            ]),
          ]),
        ),
        if (_isLeader && !isMe)
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'remove') _confirmRemoveMember(member);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'remove', child: Text('移出团队', style: TextStyle(color: AppColors.error))),
            ],
            icon: Icon(Icons.more_vert, size: 18.sp, color: AppColors.onSurfaceVariant),
          ),
      ]),
    );
  }

  Widget _buildRoleChip(bool isLeader, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: isLeader ? AppColors.orange.withValues(alpha: 0.1) : AppColors.onSurfaceVariant.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isLeader ? AppColors.orange.withValues(alpha: 0.3) : AppColors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11.sp, color: isLeader ? AppColors.orange : AppColors.onSurfaceVariant)),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  void _confirmRemoveMember(TeamMemberModel member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认移出'),
        content: Text('确定将 ${member.displayLabel} 移出团队吗？'),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              ctx.pop();
              try {
                await ref.read(teamServiceProvider).removeMember(widget.teamId, member.id);
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('操作失败: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('移出', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveTeam() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出该团队吗？'),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              ctx.pop();
              final memberId = _members
                  .cast<TeamMemberModel?>()
                  .firstWhere((m) => m!.userId == _currentUser!.id && m.isApproved,
                      orElse: () => null)
                  ?.id;
              if (memberId == null) return;
              try {
                await ref.read(teamServiceProvider).removeMember(widget.teamId, memberId);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已退出团队'), backgroundColor: AppColors.secondary),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('退出失败: $e'), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text('退出', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showEditTeamDialog() {
    final nameController = TextEditingController(text: _team?.name);
    final descController = TextEditingController(text: _team?.description);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 20.h, AppSpacing.lg.w,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl.h),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 36.w, height: 4.h,
                  decoration: BoxDecoration(
                      color: AppColors.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.r)))),
          SizedBox(height: 20.h),
          Text('编辑团队',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          SizedBox(height: AppSpacing.md.h),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: '团队名称')),
          SizedBox(height: AppSpacing.sm.h),
          TextField(controller: descController, decoration: const InputDecoration(labelText: '团队描述'), maxLines: 2),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(teamServiceProvider).update(widget.teamId, {
                    'name': nameController.text,
                    'description': descController.text,
                  });
                  if (ctx.mounted) ctx.pop();
                  _loadData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('更新失败: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: Text('保存', style: TextStyle(fontSize: 15.sp, color: AppColors.onPrimary)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showAddMemberSheet() {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 20.h, AppSpacing.lg.w,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl.h),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Container(
                  width: 36.w, height: 4.h,
                  decoration: BoxDecoration(
                      color: AppColors.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.r)))),
          SizedBox(height: 20.h),
          Text('邀请成员',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          SizedBox(height: AppSpacing.md.h),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '手机号/邮箱', hintText: '输入被邀请人的手机号或邮箱'),
          ),
          SizedBox(height: AppSpacing.sm.h),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '姓名（可选）', hintText: '被邀请人姓名'),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (phoneController.text.trim().isEmpty) return;
                try {
                  await ref.read(teamServiceProvider).inviteMember(widget.teamId, {
                    'contact': phoneController.text.trim(),
                    'userName': nameController.text.trim(),
                  });
                  if (ctx.mounted) ctx.pop();
                  _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('邀请已发送'), backgroundColor: AppColors.secondary));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('邀请失败: $e'), backgroundColor: AppColors.error));
                  }
                }
              },
              child: Text('发送邀请', style: TextStyle(fontSize: 15.sp, color: AppColors.onPrimary)),
            ),
          ),
        ]),
      ),
    );
  }
}
