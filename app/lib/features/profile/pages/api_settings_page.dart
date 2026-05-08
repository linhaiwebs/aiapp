import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_constants.dart';

class ApiSettingsPage extends ConsumerStatefulWidget {
  const ApiSettingsPage({super.key});

  @override
  ConsumerState<ApiSettingsPage> createState() => _ApiSettingsPageState();
}

class _ApiSettingsPageState extends ConsumerState<ApiSettingsPage> {
  late TextEditingController _urlController;
  String _currentUrl = '';
  bool _isTesting = false;
  bool? _connectionOk; // null=未测试, true=连通, false=不通
  int? _testStatusCode;

  // 预设地址列表
  final List<_PresetUrl> _presets = [];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final client = ref.read(dioProvider);
    final url = await client.getCurrentBaseUrl();
    if (mounted) {
      setState(() {
        _currentUrl = url;
        _urlController.text = url;
      });
      _buildPresets(url);
    }
  }

  void _buildPresets(String currentUrl) {
    _presets.clear();
    // 生产环境
    _presets.add(_PresetUrl(
      label: '正式服务器',
      url: 'https://cai.lhwebs.com/api',
      desc: '线上环境 cai.lhwebs.com',
    ));
    // 常见预设
    _presets.add(_PresetUrl(
      label: 'Android 模拟器默认',
      url: 'http://10.0.2.2:$kDefaultApiPort/api',
      desc: '10.0.2.2 映射到宿主机 localhost',
    ));
    _presets.add(_PresetUrl(
      label: 'iOS 模拟器默认',
      url: 'http://localhost:$kDefaultApiPort/api',
      desc: 'localhost 直接访问宿主机',
    ));
    _presets.add(_PresetUrl(
      label: '本机测试 (127.0.0.1)',
      url: 'http://127.0.0.1:$kDefaultApiPort/api',
      desc: '直接使用 127.0.0.1',
    ));
    // 如果当前 URL 不在预设中，添加"当前自定义"
    final presetUrls = _presets.map((p) => p.url).toSet();
    if (!presetUrls.contains(currentUrl)) {
      _presets.insert(0, _PresetUrl(
        label: '当前自定义',
        url: currentUrl,
        desc: '之前设置的地址',
      ));
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection(String url) async {
    setState(() { _isTesting = true; _connectionOk = null; _testStatusCode = null; });
    final client = ref.read(dioProvider);
    final code = await client.testConnection(url);
    if (mounted) {
      setState(() {
        _isTesting = false;
        _testStatusCode = code;
        _connectionOk = code != null; // 有任何响应即连通
      });
    }
  }

  Future<void> _applyUrl(String url) async {
    final client = ref.read(dioProvider);
    await client.setBaseUrl(url);
    if (mounted) {
      setState(() {
        _currentUrl = url;
        _urlController.text = url;
        _connectionOk = null;
        _testStatusCode = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已切换到 $url'),
        backgroundColor: AppColors.secondary,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _resetUrl() async {
    final client = ref.read(dioProvider);
    await client.resetBaseUrl();
    final url = await client.getCurrentBaseUrl();
    if (mounted) {
      setState(() {
        _currentUrl = url;
        _urlController.text = url;
        _connectionOk = null;
        _testStatusCode = null;
      });
      _buildPresets(url);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已重置为 $url'),
        backgroundColor: AppColors.secondary,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text('服务器设置', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前状态
            _buildCurrentStatus(),
            SizedBox(height: 20.h),

            // 手动输入
            Text('自定义地址', style: TextStyle(fontSize: 13.sp, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500, letterSpacing: 1)),
            SizedBox(height: 8.h),
            _buildUrlInput(),
            SizedBox(height: 20.h),

            // 预设地址
            Text('预设地址', style: TextStyle(fontSize: 13.sp, color: const Color(0xFF6B7280), fontWeight: FontWeight.w500, letterSpacing: 1)),
            SizedBox(height: 8.h),
            ..._presets.map((p) => _buildPresetItem(p)),
            SizedBox(height: 20.h),

            // 重置按钮
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetUrl,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  backgroundColor: Colors.white,
                ),
                child: Text('恢复默认', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
              ),
            ),
            SizedBox(height: 12.h),

            // 使用提示
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline, size: 16.sp, color: AppColors.primary),
                    SizedBox(width: 6.w),
                    Text('提示', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ]),
                  SizedBox(height: 8.h),
                  Text(
                    '• Android 模拟器用 10.0.2.2 代替 localhost\n'
                    '• iOS 模拟器可直接用 localhost\n'
                    '• 真机需填写电脑的局域网 IP（如 192.168.1.x）\n'
                    '• 确保手机和电脑在同一 WiFi 网络下\n'
                    '• 后端服务默认端口: $kDefaultApiPort',
                    style: TextStyle(fontSize: 12.sp, color: const Color(0xFF6B7280), height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatus() {
    final isConnected = _connectionOk == true;
    final isFailed = _connectionOk == false;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w, height: 40.w,
            decoration: BoxDecoration(
              color: (isConnected ? AppColors.secondary : isFailed ? AppColors.error : const Color(0xFFF9FAFB)).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.cloud_done : isFailed ? Icons.cloud_off : Icons.cloud_outlined,
              size: 20.sp,
              color: isConnected ? AppColors.secondary : isFailed ? AppColors.error : const Color(0xFF9CA3AF),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? '已连接' : isFailed ? '连接失败' : '未测试',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.onBackground),
                ),
                SizedBox(height: 2.h),
                Text(
                  _currentUrl,
                  style: TextStyle(fontSize: 11.sp, color: const Color(0xFF9CA3AF)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'http://192.168.1.x:$kDefaultApiPort/api',
              hintStyle: TextStyle(fontSize: 14.sp, color: const Color(0xFFD1D5DB)),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.link, size: 20.sp, color: const Color(0xFF9CA3AF)),
            ),
            keyboardType: TextInputType.url,
            onChanged: (_) => setState(() { _connectionOk = null; _testStatusCode = null; }),
          ),
          Padding(
            padding: EdgeInsets.all(8.w),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isTesting ? null : () => _testConnection(_urlController.text.trim()),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    child: _isTesting
                        ? SizedBox(width: 16.w, height: 16.w, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primary)))
                        : Text('测试连接', style: TextStyle(fontSize: 13.sp, color: AppColors.primary)),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _applyUrl(_urlController.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    child: Text('应用', style: TextStyle(fontSize: 13.sp)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetItem(_PresetUrl preset) {
    final isActive = _currentUrl == preset.url;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        onTap: () => _applyUrl(preset.url),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: isActive ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFF3F4F6)),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20.sp,
                color: isActive ? AppColors.primary : const Color(0xFFD1D5DB),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.label, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: AppColors.onBackground)),
                    SizedBox(height: 2.h),
                    Text(preset.url, style: TextStyle(fontSize: 11.sp, color: const Color(0xFF9CA3AF))),
                    if (preset.desc.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(preset.desc, style: TextStyle(fontSize: 11.sp, color: const Color(0xFFD1D5DB))),
                    ],
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text('当前', style: TextStyle(fontSize: 10.sp, color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetUrl {
  final String label;
  final String url;
  final String desc;
  _PresetUrl({required this.label, required this.url, this.desc = ''});
}
