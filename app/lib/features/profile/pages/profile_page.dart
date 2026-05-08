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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    // Try loading cached user first
    final authStorage = ref.read(authStorageProvider);
    final cached = await authStorage.getUser();
    if (cached != null && mounted) {
      setState(() { _user = cached; _isLoading = false; });
    }
    // Then refresh from API
    try {
      final user = await ref.read(authServiceProvider).getMe();
      if (mounted) {
        await authStorage.saveUser(user);
        setState(() { _user = user; _isLoading = false; });
      }
    } catch (_) {
      if (mounted && _user == null) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _user?.balance ?? 0;
    final frozenBalance = _user?.frozenBalance ?? 0;
    final totalEarnings = _user?.totalEarnings ?? 0;
    final qualityScore = _user?.qualityScore ?? 100;
    final isVerified = _user?.isRealNameVerified ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: RefreshIndicator(
        onRefresh: _loadUser,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // Top bar
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8.h, left: 20.w, right: 20.w, bottom: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  border: Border(bottom: BorderSide(color: const Color(0xFFF3F4F6), width: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40.w, height: 40.w,
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), shape: BoxShape.circle),
                      child: Icon(Icons.menu, size: 20.sp, color: Colors.grey),
                    ),
                    Text('端云智采', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: AppColors.onBackground)),
                    Container(
                      width: 40.w, height: 40.w,
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF3F4F6))),
                      child: Icon(Icons.cloud_sync_outlined, size: 20.sp, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _user != null ? '您好，${_user!.displayName}' : '您好',
                                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w600, color: AppColors.onBackground, letterSpacing: -0.5),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                '${_user?.roleLabel ?? "采集员"} · ${isVerified ? "已实名" : "未实名"}',
                                style: TextStyle(fontSize: 14.sp, color: const Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        if (!isVerified)
                          TextButton(
                            onPressed: () => context.push('/real-name'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                            ),
                            child: Text('去认证', style: TextStyle(fontSize: 13.sp, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // Wallet card
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 30, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('总余额', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500, letterSpacing: 1)),
                              Icon(Icons.account_balance_wallet, size: 20.sp, color: AppColors.primary),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildPriceDisplay(balance),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Text('冻结: ¥${frozenBalance.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF9CA3AF))),
                              SizedBox(width: 16.w),
                              Text('累计: ¥${totalEarnings.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF9CA3AF))),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          Row(children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                ),
                                child: Text('充值', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  backgroundColor: Colors.white,
                                ),
                                child: Text('提现', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Quality score
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(20.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: const Color(0xFFF3F4F6)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 30, offset: const Offset(0, 8))],
                            ),
                            child: Column(
                              children: [
                                Align(alignment: Alignment.centerLeft, child: Text('质量分', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500, letterSpacing: 1))),
                                SizedBox(height: 16.h),
                                SizedBox(
                                  width: 100.w, height: 100.w,
                                  child: Stack(
                                    children: [
                                      CircularProgressIndicator(
                                        value: qualityScore / 100,
                                        strokeWidth: 10.w,
                                        backgroundColor: const Color(0xFFF3F4F6),
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          qualityScore >= 80 ? AppColors.secondary : qualityScore >= 60 ? AppColors.orange : AppColors.error,
                                        ),
                                      ),
                                      Center(
                                        child: RichText(text: TextSpan(children: [
                                          TextSpan(text: qualityScore.toStringAsFixed(0), style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w600, color: AppColors.onBackground)),
                                          TextSpan(text: '分', style: TextStyle(fontSize: 14.sp, color: const Color(0xFF6B7280))),
                                        ])),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(20.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: const Color(0xFFF3F4F6)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 30, offset: const Offset(0, 8))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text('实名认证', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500, letterSpacing: 1)),
                                  Icon(isVerified ? Icons.verified : Icons.warning_amber, size: 20.sp, color: isVerified ? AppColors.secondary : AppColors.orange),
                                ]),
                                SizedBox(height: 24.h),
                                Text(isVerified ? '已认证' : '未认证', style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w600, color: isVerified ? AppColors.secondary : AppColors.orange, letterSpacing: -2)),
                                SizedBox(height: 12.h),
                                if (!isVerified)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => context.push('/real-name'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                                        padding: EdgeInsets.symmetric(vertical: 8.h),
                                      ),
                                      child: Text('去认证', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // Settings list
                    Text('偏好与支持', style: TextStyle(fontSize: 12.sp, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500, letterSpacing: 1.5)),
                    SizedBox(height: 8.h),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 30, offset: const Offset(0, 8))],
                      ),
                      child: Column(children: [
                        _settingsItem(Icons.dns_outlined, '服务器设置', onTap: () => context.push('/api-settings')),
                        _settingsItem(Icons.security, '账号安全', onTap: () {}),
                        _settingsItem(Icons.notifications_active, '通知设置', onTap: () {}),
                        _settingsItem(Icons.help_outline, '帮助中心', onTap: () {}),
                        _settingsItem(Icons.info_outline, '关于端云智采', showBorder: false, onTap: () {}),
                      ]),
                    ),
                    SizedBox(height: 16.h),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          final storage = ref.read(authStorageProvider);
                          await storage.clearAll();
                          if (context.mounted) context.go('/login');
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: Text('退出登录', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.error)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 100.h)),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceDisplay(double value) {
    final intPart = value.truncate().toString();
    final decPart = (value - value.truncate()).abs().toStringAsFixed(2).substring(1);
    return RichText(text: TextSpan(children: [
      TextSpan(text: '¥$intPart', style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.w600, color: AppColors.onBackground, letterSpacing: -2)),
      TextSpan(text: decPart, style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.w600, color: const Color(0xFF9CA3AF), letterSpacing: -2)),
    ]));
  }

  Widget _settingsItem(IconData icon, String title, {bool showBorder = true, VoidCallback? onTap}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(
                    width: 40.w, height: 40.w,
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), shape: BoxShape.circle, border: Border.all(color: const Color(0xFFF3F4F6))),
                    child: Icon(icon, size: 20.sp, color: const Color(0xFF6B7280)),
                  ),
                  SizedBox(width: 16.w),
                  Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400, color: AppColors.onBackground)),
                ]),
                Icon(Icons.chevron_right, size: 20.sp, color: const Color(0xFFD1D5DB)),
              ],
            ),
          ),
        ),
        if (showBorder) Padding(padding: EdgeInsets.only(left: 72.w), child: Divider(color: const Color(0xFFF9FAFB), height: 1)),
      ],
    );
  }
}
