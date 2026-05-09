import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';

class RealNamePage extends ConsumerStatefulWidget {
  const RealNamePage({super.key});

  @override
  ConsumerState<RealNamePage> createState() => _RealNamePageState();
}

class _RealNamePageState extends ConsumerState<RealNamePage> {
  final _nameCtrl = TextEditingController();
  final _idCardCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _frontImage;
  File? _backImage;

  bool _frontOcring = false;
  bool _backOcring = false;
  bool _submitting = false;
  bool _isVerified = false;
  String? _ocrName;
  String? _ocrIdNumber;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCardCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureFront() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);

    setState(() {
      _frontImage = file;
      _frontOcring = true;
    });

    try {
      final result = await ref.read(authServiceProvider).ocrIdCardFront(base64);
      final name = result['name'] as String? ?? '';
      final idNumber = result['idNumber'] as String? ?? '';
      setState(() {
        _ocrName = name;
        _ocrIdNumber = idNumber;
        if (name.isNotEmpty) _nameCtrl.text = name;
        if (idNumber.isNotEmpty) _idCardCtrl.text = idNumber;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('身份证正面识别失败，请手动填写'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _frontOcring = false);
    }
  }

  Future<void> _captureBack() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);

    setState(() {
      _backImage = file;
      _backOcring = true;
    });

    try {
      await ref.read(authServiceProvider).ocrIdCardBack(base64);
    } catch (_) {
      // Back OCR failure is non-critical
    } finally {
      if (mounted) setState(() => _backOcring = false);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final idCard = _idCardCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入姓名'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (idCard.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入身份证号'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authServiceProvider).verifyRealName(
        realName: name,
        idCardNumber: idCard,
      );
      setState(() => _isVerified = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('实名认证成功'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '').replaceAll('DioException ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('认证失败: $msg'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('实名认证', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请拍摄身份证并确认信息，完成实名认证',
              style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant),
            ),
            SizedBox(height: 24.h),

            // ID card front capture
            _buildCardSection(
              title: '身份证正面（人像面）',
              image: _frontImage,
              loading: _frontOcring,
              onCapture: _captureFront,
            ),
            if (_frontOcring)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Row(children: [
                  SizedBox(width: 16.w, height: 16.w, child: const CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8.w),
                  Text('正在识别...', style: TextStyle(fontSize: 13.sp, color: AppColors.primary)),
                ]),
              ),
            if (_ocrName != null || _ocrIdNumber != null)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Row(children: [
                  Icon(Icons.check_circle, size: 16.sp, color: AppColors.secondary),
                  SizedBox(width: 4.w),
                  Text('识别完成', style: TextStyle(fontSize: 13.sp, color: AppColors.secondary)),
                ]),
              ),
            SizedBox(height: 24.h),

            // ID card back capture
            _buildCardSection(
              title: '身份证反面（国徽面）',
              image: _backImage,
              loading: _backOcring,
              onCapture: _captureBack,
            ),
            SizedBox(height: 24.h),

            // Name field
            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(fontSize: 15.sp, color: AppColors.onSurface),
              decoration: const InputDecoration(
                labelText: '姓名',
                hintText: '与身份证一致的真实姓名',
                prefixIcon: Icon(Icons.person, color: AppColors.outline),
              ),
            ),
            SizedBox(height: 16.h),

            // ID card number field
            TextFormField(
              controller: _idCardCtrl,
              style: TextStyle(fontSize: 15.sp, color: AppColors.onSurface),
              decoration: const InputDecoration(
                labelText: '身份证号',
                hintText: '18位身份证号码',
                prefixIcon: Icon(Icons.badge, color: AppColors.outline),
              ),
            ),
            SizedBox(height: 32.h),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48.h,
              child: ElevatedButton(
                onPressed: _isVerified || _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm.r)),
                ),
                child: _submitting
                    ? SizedBox(width: 20.w, height: 20.w, child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                    : Text(_isVerified ? '已认证' : '提交认证', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
              ),
            ),

            if (_isVerified) ...[
              SizedBox(height: 24.h),
              Center(child: Icon(Icons.verified, size: 64.sp, color: AppColors.secondary)),
              SizedBox(height: 8.h),
              Center(child: Text('认证通过', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: AppColors.secondary))),
            ],
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required File? image,
    required bool loading,
    required VoidCallback onCapture,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: AppColors.onSurfaceVariant, letterSpacing: 0.6)),
        SizedBox(height: 8.h),
        GestureDetector(
          onTap: loading ? null : (image != null ? onCapture : onCapture),
          child: Container(
            width: double.infinity,
            height: 180.h,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.outlineVariant, width: 1),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Image.file(image, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 32.sp, color: AppColors.outline),
                      SizedBox(height: 8.h),
                      Text('点击拍照', style: TextStyle(fontSize: 14.sp, color: AppColors.outline)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
