import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/team_model.dart';
import '../../../core/services/team_service.dart';

class TeamListPage extends ConsumerStatefulWidget {
  const TeamListPage({super.key});

  @override
  ConsumerState<TeamListPage> createState() => _TeamListPageState();
}

class _TeamListPageState extends ConsumerState<TeamListPage> {
  List<TeamModel> _myTeams = [];
  bool _isLoading = true;
  bool _isJoining = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMyTeams();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMyTeams() async {
    try {
      final teams = await ref.read(teamServiceProvider).getMyTeams();
      if (mounted) setState(() { _myTeams = teams; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinTeam() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('请输入口令'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      await ref.read(teamServiceProvider).joinByCode(code);
      _codeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('加入团队成功！'), backgroundColor: AppColors.secondary),
        );
        _loadMyTeams();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadMyTeams,
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  // Join by code section
                  _buildJoinCard(),
                  SizedBox(height: 24.h),
                  // My teams section
                  _buildSectionTitle('我的团队'),
                  SizedBox(height: 12.h),
                  if (_myTeams.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: Text('暂未加入任何团队', style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant)),
                      ),
                    )
                  else
                    ..._myTeams.map((team) => _buildTeamCard(team)),
                ],
              ),
            ),
    );
  }

  Widget _buildJoinCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_add, color: Colors.white, size: 24.sp),
              SizedBox(width: 8.w),
              Text('加入团队', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          SizedBox(height: 8.h),
          Text('输入团长提供的8位口令即可加入团队', style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.85))),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: TextField(
                    controller: _codeController,
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 4),
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: '请输入8位口令',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), letterSpacing: 2),
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              SizedBox(
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinTeam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                  ),
                  child: _isJoining
                      ? SizedBox(width: 18.w, height: 18.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : Text('加入', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface));
  }

  Widget _buildTeamCard(TeamModel team) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, size: 20.sp, color: AppColors.primary),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(team.name, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: team.isActive ? AppColors.secondary.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(team.isActive ? '启用' : '禁用', style: TextStyle(fontSize: 11.sp, color: team.isActive ? AppColors.secondary : Colors.grey)),
              ),
            ],
          ),
          if (team.description != null && team.description!.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(team.description!, style: TextStyle(fontSize: 13.sp, color: AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          SizedBox(height: 8.h),
          Row(
            children: [
              Text('负责人: ${team.leaderName ?? '-'}', style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
              const Spacer(),
              Text('成员: ${team.members.length}人', style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
