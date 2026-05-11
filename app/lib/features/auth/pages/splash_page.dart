import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/services/update_service.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // 检查版本更新
    final updateInfo = await ref.read(updateServiceProvider).checkUpdate();

    if (!mounted) return;

    final authStorage = ref.read(authStorageProvider);
    final token = await authStorage.getToken();

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('onboarding_shown') ?? false;

    if (!mounted) return;

    // 强制更新 → 停留在 splash 并弹窗
    if (updateInfo != null && updateInfo.forceUpdate) {
      if (mounted) {
        UpdateService.showUpdateDialog(context, updateInfo);
      }
      return;
    }

    if (!shown) {
      context.go('/onboarding');
    } else if (token != null && token != 'undefined') {
      context.go('/home');
    } else {
      context.go('/login');
    }

    // 可选更新 → 延迟弹窗
    if (updateInfo != null && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) UpdateService.showUpdateDialog(context, updateInfo);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: Center(
                child: Image.asset('assets/logo.png', width: 56.w, height: 56.w),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              '端云智采',
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '专业高效的数据采集平台',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
