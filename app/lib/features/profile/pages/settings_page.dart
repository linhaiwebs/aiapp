import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _wifiOnly = false;
  bool _notification = true;
  String _uploadQuality = 'high';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wifiOnly = prefs.getBool('wifi_only_upload') ?? false;
      _notification = prefs.getBool('notification_enabled') ?? true;
      _uploadQuality = prefs.getString('upload_quality') ?? 'high';
    });
  }

  Future<void> _setWifiOnly(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifi_only_upload', v);
    setState(() => _wifiOnly = v);
  }

  Future<void> _setNotification(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled', v);
    setState(() => _notification = v);
  }

  Future<void> _setUploadQuality(String v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('upload_quality', v);
    setState(() => _uploadQuality = v);
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep auth tokens, clear other caches
    await prefs.remove('user_data');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('缓存已清除'),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('应用设置'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.layoutMargin.w),
        children: [
          _section('数据上传'),
          _card([
            SwitchListTile(
              title: const Text('仅在WiFi下上传'),
              subtitle: const Text('节省移动数据流量'),
              value: _wifiOnly,
              onChanged: _setWifiOnly,
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding.w),
            ),
          ]),
          SizedBox(height: AppSpacing.md.h),
          _section('上传清晰度'),
          _card([
            RadioListTile<String>(
              title: const Text('高质量'),
              subtitle: const Text('文件较大，质量最佳'),
              value: 'high',
              groupValue: _uploadQuality,
              onChanged: (v) => _setUploadQuality(v!),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding.w),
            ),
            _divider(),
            RadioListTile<String>(
              title: const Text('标准'),
              subtitle: const Text('平衡质量与大小'),
              value: 'medium',
              groupValue: _uploadQuality,
              onChanged: (v) => _setUploadQuality(v!),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding.w),
            ),
            _divider(),
            RadioListTile<String>(
              title: const Text('节省流量'),
              subtitle: const Text('文件较小，速度最快'),
              value: 'low',
              groupValue: _uploadQuality,
              onChanged: (v) => _setUploadQuality(v!),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding.w),
            ),
          ]),
          SizedBox(height: AppSpacing.md.h),
          _section('通知'),
          _card([
            SwitchListTile(
              title: const Text('消息通知'),
              subtitle: const Text('接收任务更新和系统消息'),
              value: _notification,
              onChanged: _setNotification,
              activeThumbColor: AppColors.primary,
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding.w),
            ),
          ]),
          SizedBox(height: AppSpacing.md.h),
          _section('存储'),
          _card([
            ListTile(
              title: const Text('清除缓存'),
              subtitle: const Text('清除本地缓存数据'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
              onTap: () => _clearCache(),
              contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding.w),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w, bottom: AppSpacing.sm.h),
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

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return Padding(
      padding: EdgeInsets.only(left: 56.w),
      child: const Divider(color: AppColors.separator, height: 1, thickness: 1),
    );
  }
}
