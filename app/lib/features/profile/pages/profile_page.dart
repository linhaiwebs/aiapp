import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_model.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authStorage = ref.read(authStorageProvider);
    final cached = await authStorage.getUser();
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
      });
    }
    try {
      final user = await ref.read(authServiceProvider).getMe();
      if (mounted) {
        await authStorage.saveUser(user);
        setState(() {
          _user = user;
        });
      }
    } catch (_) {
      // Use cached data if network fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _user?.balance ?? 0;
    final frozenBalance = _user?.frozenBalance ?? 0;
    final totalEarnings = _user?.totalEarnings ?? 0;
    final isVerified = _user?.isRealNameVerified ?? false;
    final nickname = _user?.nickname ?? '用户';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadUser,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── Header: surface → primary/5% gradient ──
            SliverToBoxAdapter(
              child: _buildHeader(
                context,
                nickname,
                balance,
                totalEarnings,
                isVerified,
              ),
            ),

            // ── Content ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.layoutMargin.w,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.md.h),

                    // Wallet card
                    _buildWalletCard(balance, frozenBalance, totalEarnings),
                    SizedBox(height: AppSpacing.lg.h),

                    // ── 账户 ──
                    _sectionTitle('账户'),
                    SizedBox(height: AppSpacing.sm.h),
                    _buildMenuCard([
                      _MenuItem(
                        icon: Icons.person_outline,
                        title: '个人信息',
                        subtitle: '查看和编辑个人资料',
                        onTap: () {},
                      ),
                      _MenuItem(
                        icon: Icons.verified_user_outlined,
                        title: '实名认证',
                        subtitle: isVerified ? '已认证' : '未认证',
                        trailing: isVerified
                            ? Icon(Icons.check_circle,
                                size: 18.sp, color: AppColors.secondary)
                            : Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.orange
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Text(
                                  '未认证',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                        onTap: isVerified
                            ? null
                            : () => context.push('/real-name'),
                      ),
                      _MenuItem(
                        icon: Icons.security_outlined,
                        title: '账户安全',
                        subtitle: '修改密码，保护账号',
                        showDivider: false,
                        onTap: () => context.push('/account-security'),
                      ),
                    ]),

                    SizedBox(height: AppSpacing.md.h),

                    // ── 数据 ──
                    _sectionTitle('数据'),
                    SizedBox(height: AppSpacing.sm.h),
                    _buildMenuCard([
                      _MenuItem(
                        icon: Icons.history_outlined,
                        title: '任务记录',
                        subtitle: '查看已领取和已完成的任务',
                        showDivider: false,
                        onTap: () => context.push('/my-tasks'),
                      ),
                    ]),

                    SizedBox(height: AppSpacing.md.h),

                    // ── 设置 ──
                    _sectionTitle('设置'),
                    SizedBox(height: AppSpacing.sm.h),
                    _buildMenuCard([
                      _MenuItem(
                        icon: Icons.settings_outlined,
                        title: '设置',
                        subtitle: '应用设置与偏好',
                        onTap: () => context.push('/settings'),
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        title: '关于',
                        subtitle: '端云智采 v1.0.0',
                        showDivider: false,
                        onTap: () => context.push('/about'),
                      ),
                    ]),

                    SizedBox(height: AppSpacing.md.h),

                    // ── Logout ──
                    _buildLogoutButton(),

                    SizedBox(height: 100.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    String nickname,
    double balance,
    double totalEarnings,
    bool isVerified,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20.w,
        MediaQuery.of(context).padding.top + 20.h,
        20.w,
        28.h,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.surface,
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            children: [
              // Avatar circle
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    nickname.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _user != null ? _user!.displayName : '用户',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _user?.phone.replaceRange(3, 7, '****') ?? '',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        _roleBadge(_user?.role),
                        SizedBox(width: 8.w),
                        if (isVerified) _verifiedBadge(),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => context.push('/settings'),
                icon: Icon(
                  Icons.settings_outlined,
                  size: 22.sp,
                  color: AppColors.onSurfaceVariant,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          // Stats row (inline in header)
          Row(
            children: [
              _headerStat('余额', '¥${balance.toStringAsFixed(0)}'),
              _headerStatDivider(),
              _headerStat('已完成', '0个'),
              _headerStatDivider(),
              _headerStat('总收入', '¥${totalEarnings.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStatDivider() {
    return Container(
      width: 1,
      height: 28.h,
      color: AppColors.outlineVariant,
    );
  }

  // ──────────────────────────────────────────────
  // Wallet card
  // ──────────────────────────────────────────────

  Widget _buildWalletCard(double balance, double frozen, double total) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wallet icon + title
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                '我的钱包',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),

          // Balance
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 6.w),
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Text(
                  '余额',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),

          // Frozen + total earnings
          Row(
            children: [
              _walletSub('冻结', frozen),
              SizedBox(width: AppSpacing.lg.w),
              _walletSub('累计收益', total),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  child: Text(
                    '充值',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.dataGutter.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.outlineVariant, width: 1),
                    foregroundColor: AppColors.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  child: Text(
                    '提现',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _walletSub(String label, double amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style:
              TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant),
        ),
        SizedBox(width: 4.w),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // Header badges (preserved)
  // ──────────────────────────────────────────────

  Widget _roleBadge(UserRole? role) {
    final r = role ?? UserRole.member;
    final label = r.label;
    final color = switch (r) {
      UserRole.leader => AppColors.orange,
      UserRole.superAdmin => AppColors.error,
      _ => AppColors.secondary,
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _verifiedBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12.sp, color: AppColors.secondary),
          SizedBox(width: 4.w),
          Text(
            '已实名',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Menu section helpers
  // ──────────────────────────────────────────────

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildMenuCard(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(children: items),
    );
  }

  // ──────────────────────────────────────────────
  // Logout button
  // ──────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final storage = ref.read(authStorageProvider);
          await storage.clearAll();
          if (!mounted) return;
          context.go('/login');
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: EdgeInsets.symmetric(vertical: 14.h),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              '退出登录',
              style:
                  TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Menu item widget
// ═══════════════════════════════════════════════

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBgColor = isDestructive
        ? AppColors.error.withValues(alpha: 0.08)
        : AppColors.primary.withValues(alpha: 0.08);
    final iconColor =
        isDestructive ? AppColors.error : AppColors.primary;
    final titleColor = isDestructive
        ? AppColors.error
        : onTap == null
            ? AppColors.onSurfaceVariant
            : AppColors.onSurface;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding.w,
              vertical: AppSpacing.cardPadding.h,
            ),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, size: 20.sp, color: iconColor),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: titleColor,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null && !isDestructive)
                  Icon(Icons.chevron_right,
                      size: 20.sp, color: AppColors.outline),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: 78.w),
            child: const Divider(
              color: AppColors.separator,
              height: 1,
              thickness: 1,
            ),
          ),
      ],
    );
  }
}
