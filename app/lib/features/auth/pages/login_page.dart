import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/models/user_model.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _smsCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSmsMode = false;
  bool _isSendingSms = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _smsCodeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) { _showError('请输入手机号'); return; }

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      Map<String, dynamic> result;

      if (_isSmsMode) {
        final smsCode = _smsCodeController.text.trim();
        if (smsCode.isEmpty) { _showError('请输入验证码'); setState(() => _isLoading = false); return; }
        result = await authService.smsLogin(phone: phone, smsCode: smsCode);
      } else {
        final password = _passwordController.text;
        if (password.isEmpty) { _showError('请输入密码'); setState(() => _isLoading = false); return; }
        result = await authService.login(phone: phone, password: password);
      }

      if (!mounted) return;
      final authStorage = ref.read(authStorageProvider);
      await authStorage.saveToken(result['accessToken'] as String);
      await authStorage.saveRefreshToken(result['refreshToken'] as String);
      if (result['user'] != null) {
        final user = UserModel.fromJson(result['user'] as Map<String, dynamic>);
        await authStorage.saveUser(user);
      }
      context.go('/home');
    } catch (e) {
      // Extract actual error message from DioException
      String errMsg = _isSmsMode ? '验证码错误或已过期' : '登录失败，请检查手机号和密码';
      try {
        final dioErr = e as dynamic;
        if (dioErr?.response?.data?['message'] != null) {
          errMsg = dioErr.response.data['message'].toString();
        }
      } catch (_) {}
      _showError(errMsg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendSmsCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 11) {
      _showError('请输入正确的手机号');
      return;
    }
    setState(() => _isSendingSms = true);
    try {
      final result = await ref.read(authServiceProvider).sendSmsCode(phone);
      if (!mounted) return;

      // Mock 模式下后端会返回验证码，方便测试
      final mockCode = result['code'] as String?;
      final message = mockCode != null
          ? '验证码已发送：$mockCode（测试模式）'
          : '验证码已发送';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.secondary,
          duration: Duration(seconds: mockCode != null ? 8 : 3),
        ),
      );

      // Mock 模式自动填入验证码
      if (mockCode != null) {
        _smsCodeController.text = mockCode;
      }

      setState(() => _countdown = 60);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_countdown <= 1) { t.cancel(); setState(() => _countdown = 0); }
        else { setState(() => _countdown--); }
      });
    } catch (e) {
      _showError('验证码发送失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSendingSms = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 80.h),
              Center(
                child: Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(Icons.cloud_sync_outlined, size: 40.sp, color: AppColors.primary),
                ),
              ),
              SizedBox(height: 24.h),
              Center(
                child: Text('端云智采', style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.5)),
              ),
              SizedBox(height: 8.h),
              Center(
                child: Text('专业高效的数据采集平台', style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant)),
              ),
              SizedBox(height: 32.h),
              // Login mode toggle
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _modeChip('密码登录', !_isSmsMode, () => setState(() => _isSmsMode = false)),
                      _modeChip('验证码登录', _isSmsMode, () => setState(() => _isSmsMode = true)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              Text('手机号', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              SizedBox(height: 8.h),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '请输入手机号',
                  prefixIcon: const Icon(Icons.phone_android, color: AppColors.outline),
                ),
              ),
              SizedBox(height: 20.h),
              if (_isSmsMode) ...[
                Text('验证码', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                SizedBox(height: 8.h),
                TextField(
                  controller: _smsCodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '请输入验证码',
                    prefixIcon: const Icon(Icons.sms_outlined, color: AppColors.outline),
                    counterText: '',
                    suffixIcon: Padding(
                      padding: EdgeInsets.only(right: 4.w),
                      child: TextButton(
                        onPressed: _countdown > 0 || _isSendingSms ? null : _sendSmsCode,
                        child: _isSendingSms
                            ? SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2))
                            : Text(
                                _countdown > 0 ? '${_countdown}s' : '获取验证码',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: _countdown > 0 ? AppColors.outline : AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Text('密码', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                SizedBox(height: 8.h),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '请输入密码',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.outline),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _isLoading
                      ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                      : Text('登录', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('还没有账号？', style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text('立即注册', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              Row(children: [
                Expanded(child: Divider(color: AppColors.outlineVariant)),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16.w), child: Text('其他登录方式', style: TextStyle(fontSize: 12.sp, color: AppColors.outline))),
                Expanded(child: Divider(color: AppColors.outlineVariant)),
              ]),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(Icons.chat_bubble, '微信', const Color(0xFF07C160)),
                  SizedBox(width: 40.w),
                  _socialButton(Icons.people, 'QQ', const Color(0xFF12B7F5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _showError('$label 登录暂未开放'),
      child: Column(children: [
        Container(width: 48.w, height: 48.w, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24.sp)),
        SizedBox(height: 6.h),
        Text(label, style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant)),
      ]),
    );
  }
}
