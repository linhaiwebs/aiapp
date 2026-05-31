import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/models/user_model.dart';
import '../../profile/pages/about_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToPrivacy = false;
  int _countdown = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacyAgreement();
  }

  Future<void> _loadPrivacyAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _agreedToPrivacy = prefs.getBool('privacy_agreed') ?? false);
    }
  }

  Future<void> _sendSmsCode() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入手机号'), backgroundColor: AppColors.error));
      return;
    }
    try {
      final result = await ref.read(authServiceProvider).sendSmsCode(_phoneController.text);
      // Mock 模式下后端会返回验证码，方便测试
      final mockCode = result['code'] as String?;
      if (mockCode != null) {
        _smsCodeController.text = mockCode;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('验证码：$mockCode（测试模式）'),
            backgroundColor: AppColors.secondary,
            duration: const Duration(seconds: 8),
          ));
        }
      }
      setState(() => _countdown = 60);
      _startCountdown();
    } catch (e) {
      String errMsg = '验证码发送失败';
      try {
        final dioErr = e as dynamic;
        if (dioErr?.response?.data?['message'] != null) {
          errMsg = dioErr.response.data['message'].toString();
        } else if (dioErr?.message != null) {
          errMsg = dioErr.message.toString();
        }
      } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: AppColors.error));
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_countdown > 0 && mounted) { setState(() => _countdown--); _startCountdown(); }
    });
  }

  Future<void> _savePrivacyAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_agreed', true);
  }

  void _showPolicy(String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
          child: Column(
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    content,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.onSurfaceVariant,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _privacyCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 20.w,
          height: 20.w,
          child: Checkbox(
            value: _agreedToPrivacy,
            onChanged: (v) => setState(() => _agreedToPrivacy = v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12.sp, color: AppColors.onSurfaceVariant),
              children: [
                const TextSpan(text: '我已阅读并同意'),
                TextSpan(
                  text: '《用户协议》',
                  style: const TextStyle(color: AppColors.primary),
                  recognizer: TapGestureRecognizer()..onTap = () => _showPolicy('用户协议', AboutPage.userAgreement),
                ),
                const TextSpan(text: '和'),
                TextSpan(
                  text: '《隐私政策》',
                  style: const TextStyle(color: AppColors.primary),
                  recognizer: TapGestureRecognizer()..onTap = () => _showPolicy('隐私政策', AboutPage.privacyPolicy),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleRegister() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty || _smsCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写完整信息'), backgroundColor: AppColors.error));
      return;
    }
    if (!_agreedToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先阅读并同意用户协议和隐私政策'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.register(
        phone: _phoneController.text,
        password: _passwordController.text,
        smsCode: _smsCodeController.text,
      );
      if (!mounted) return;
      // Auto-login after register if tokens are returned
      final authStorage = ref.read(authStorageProvider);
      if (result['accessToken'] != null) {
        await authStorage.saveToken(result['accessToken'] as String);
        await authStorage.saveRefreshToken(result['refreshToken'] as String);
        if (result['user'] != null) {
          final user = UserModel.fromJson(result['user'] as Map<String, dynamic>);
          await authStorage.saveUser(user);
        }
        await _savePrivacyAgreement();
        if (!mounted) return;
        context.go('/home');
      } else {
        // Backend doesn't return tokens on register — go to login
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请登录'), backgroundColor: AppColors.secondary),
        );
        context.go('/login');
      }
    } catch (e) {
      String errMsg = '注册失败';
      try {
        final dioErr = e as dynamic;
        if (dioErr?.response?.data?['message'] != null) {
          errMsg = dioErr.response.data['message'].toString();
        }
      } catch (_) {}
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose(); _smsCodeController.dispose(); _passwordController.dispose(); _nicknameController.dispose();
    super.dispose();
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
              SizedBox(height: 16.h),
              // Back button
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: AppColors.onSurface,
                  size: 24.sp,
                ),
                onPressed: () => context.go('/login'),
              ),
              SizedBox(height: 16.h),
              // Title
              Text(
                '创建账号',
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
                    // SMS code input
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
                      decoration: InputDecoration(
                        hintText: '请输入验证码',
                        prefixIcon: const Icon(
                          Icons.sms_outlined,
                          color: AppColors.outline,
                        ),
                        suffixIcon: Padding(
                          padding: EdgeInsets.only(right: 4.w),
                          child: TextButton(
                            onPressed:
                                _countdown > 0 ? null : _sendSmsCode,
                            child: Text(
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
                    SizedBox(height: 20.h),
                    // Password input
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
                        hintText: '请设置密码（6位以上）',
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
                    SizedBox(height: 20.h),
                    // Nickname input (optional)
                    Text(
                      '昵称（选填）',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(
                        hintText: '请输入昵称',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: AppColors.outline,
                        ),
                      ),
                    ),
                    if (!_agreedToPrivacy) ...[
                      SizedBox(height: 16.h),
                      _privacyCheckbox(),
                    ],
                    SizedBox(height: 24.h),
                    // Register button
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
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
                                '注册',
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
              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '已有账号？',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      '立即登录',
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
            ],
          ),
        ),
      ),
    );
  }
}
