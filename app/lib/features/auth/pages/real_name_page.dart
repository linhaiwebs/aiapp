import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';

class RealNamePage extends ConsumerStatefulWidget {
  const RealNamePage({super.key});

  @override
  ConsumerState<RealNamePage> createState() => _RealNamePageState();
}

class _RealNamePageState extends ConsumerState<RealNamePage> {
  final _nameController = TextEditingController();
  final _idCardController = TextEditingController();
  bool _isVerified = false;
  bool _isLoading = false;

  @override
  void dispose() { _nameController.dispose(); _idCardController.dispose(); super.dispose(); }

  Future<void> _handleVerify() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).verifyRealName(realName: _nameController.text, idCardNumber: _idCardController.text);
      setState(() => _isVerified = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('实名认证成功'), backgroundColor: AppColors.secondary));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('认证失败: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      appBar: AppBar(backgroundColor: AppColors.surfaceContainerLowest, title: Text('实名认证', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('为了保障平台数据安全，请先完成实名认证', style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant)),
          SizedBox(height: 24.h),
          TextField(controller: _nameController, decoration: InputDecoration(hintText: '请输入真实姓名', prefixIcon: const Icon(Icons.person, color: AppColors.outline))),
          SizedBox(height: 16.h),
          TextField(controller: _idCardController, decoration: InputDecoration(hintText: '请输入身份证号', prefixIcon: const Icon(Icons.badge, color: AppColors.outline))),
          SizedBox(height: 32.h),
          SizedBox(width: double.infinity, height: 48.h, child: ElevatedButton(onPressed: _isVerified ? null : (_isLoading ? null : _handleVerify), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r))), child: _isLoading ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary)) : Text(_isVerified ? '已认证' : '提交认证', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)))),
          if (_isVerified) ...[
            SizedBox(height: 24.h),
            Center(child: Icon(Icons.verified, size: 64.sp, color: AppColors.secondary)),
            SizedBox(height: 8.h),
            Center(child: Text('认证通过', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.secondary))),
          ],
        ]),
      ),
    );
  }
}
