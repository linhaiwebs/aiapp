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
      if (!mounted) return;
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
      String errMsg = '验证码发送失败，请稍后重试';
      try {
        final dioErr = e as dynamic;
        if (dioErr?.response?.data?['message'] != null) {
          errMsg = dioErr.response.data['message'].toString();
        } else if (dioErr?.message != null) {
          errMsg = dioErr.message.toString();
        }
      } catch (_) {}
      _showError(errMsg);
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 60.h),
              // App icon + name
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: 48.w,
                      height: 48.w,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      '端云智采',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              // Title
              Text(
                '欢迎回来',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 24.h),
              // Card-like form area
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone input
                    Text(
                      '手机号',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '请输入手机号',
                        prefixIcon: Icon(
                          Icons.phone_android,
                          color: AppColors.outline,
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // Password / SMS input
                    if (_isSmsMode) ...[
                      Text(
                        '验证码',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _smsCodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: '请输入验证码',
                          prefixIcon: const Icon(
                            Icons.sms_outlined,
                            color: AppColors.outline,
                          ),
                          counterText: '',
                          suffixIcon: Padding(
                            padding: EdgeInsets.only(right: 4.w),
                            child: TextButton(
                              onPressed:
                                  _countdown > 0 || _isSendingSms
                                      ? null
                                      : _sendSmsCode,
                              child: _isSendingSms
                                  ? SizedBox(
                                      width: 16.w,
                                      height: 16.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _countdown > 0
                                          ? '${_countdown}s'
                                          : '发送验证码',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: _countdown > 0
                                            ? AppColors.outline
                                            : AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '密码',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '请输入密码',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.outline,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.outline,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 24.h),
                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                '登录',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              // Bottom action links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _isSmsMode = !_isSmsMode),
                    child: Text(
                      _isSmsMode ? '密码登录' : '验证码登录',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text(
                      '注册账号',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              // Divider
              Row(children: [
                const Expanded(
                  child: Divider(color: AppColors.outlineVariant),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Text(
                    '其他方式登录',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.outline,
                    ),
                  ),
                ),
                const Expanded(
                  child: Divider(color: AppColors.outlineVariant),
                ),
              ]),
              SizedBox(height: 24.h),
              // Social buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(
                    Icons.chat_bubble,
                    '微信',
                    const Color(0xFF07C160),
                  ),
                  SizedBox(width: 40.w),
                  _socialButton(
                    Icons.people,
                    'QQ',
                    const Color(0xFF12B7F5),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => _showError('$label 登录暂未开放'),
      child: Column(children: [
        Container(
          width: 48.w,
          height: 48.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24.sp),
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ]),
    );
  }
}
