import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.layoutMargin.w),
        children: [
          // App info header
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.outlineVariant, width: 1),
            ),
            child: Column(
              children: [
                Image.asset('assets/logo.png', width: 64.w, height: 64.w),
                SizedBox(height: 12.h),
                Text(
                  '端云智采',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'v0.1.0 (Build 1)',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  '专业高效的数据采集众包平台',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.lg.h),

          _section('政策与协议'),
          SizedBox(height: AppSpacing.sm.h),
          _card([
             _tile(context, '用户协议', userAgreement),
            _divider(),
             _tile(context, '隐私政策', privacyPolicy),
            _divider(),
             _tile(context, '服务条款', termsOfService),
          ]),

          SizedBox(height: AppSpacing.lg.h),
          Text(
            'Copyright 2026 XCAI. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 40.h),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, String title, String content) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
      onTap: () => _showPolicy(context, title, content),
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding.w),
    );
  }

  void _showPolicy(BuildContext context, String title, String content) {
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

  static const userAgreement = '''
用户协议

最后更新日期：2026年1月

1. 总则
1.1 欢迎使用端云智采（以下简称"本平台"）提供的数据采集众包服务。
1.2 本协议是您与本平台之间关于使用本平台服务所订立的协议。
1.3 请您在使用本平台服务前仔细阅读本协议的全部内容。您点击"同意"或开始使用本平台服务，即表示您已阅读、理解并同意接受本协议的所有条款。

2. 账号注册与管理
2.1 您应当使用真实手机号码注册账号，并确保所提供的信息真实、准确、完整。
2.2 您应当妥善保管账号和密码，对账号下发生的所有活动承担责任。
2.3 未经本平台书面同意，您不得将账号转让、出借或授权他人使用。

3. 服务内容
3.1 本平台提供数据采集、质检、管理和导出等众包服务。
3.2 您通过本平台完成任务后，可获得相应的报酬。
3.3 本平台有权根据业务需要调整服务内容和收费标准。

4. 用户行为规范
4.1 您承诺遵守中华人民共和国相关法律法规。
4.2 您不得利用本平台从事任何违法违规活动。
4.3 您提交的数据应当真实有效，不得伪造、篡改。

5. 知识产权
5.1 您通过本平台提交的数据，相关知识产权按照项目约定执行。
5.2 本平台的软件、商标、界面设计等知识产权归本平台所有。

6. 免责声明
6.1 因不可抗力或计算机病毒、黑客攻击等原因导致的服务中断，本平台不承担责任。
6.2 本平台对您因使用服务而获得的任何间接损失不承担责任。

7. 协议变更
7.1 本平台有权随时修改本协议内容，修改后的协议将在平台公布后生效。
7.2 如您不同意修改后的协议，应当停止使用本平台服务。

8. 法律适用与争议解决
8.1 本协议适用中华人民共和国法律。
8.2 因本协议产生的争议，双方应友好协商解决；协商不成的，提交有管辖权的人民法院诉讼解决。
''';

  static const privacyPolicy = '''
隐私政策

最后更新日期：2026年1月

1. 信息收集
1.1 您在注册账号时，我们需要收集您的手机号码。
1.2 您在进行实名认证时，我们需要收集您的真实姓名和身份证号码。
1.3 您在使用数据采集功能时，我们可能收集您提交的语音、图像、文本、视频等数据。
1.4 您在使用定位相关功能时，我们可能需要收集您的地理位置信息。

2. 信息使用
2.1 我们收集的信息仅用于以下目的：
  - 为您提供平台服务
  - 验证您的身份
  - 处理您的报酬结算
  - 改进我们的服务质量
  - 遵守法律法规要求
2.2 我们不会将您的个人信息用于本政策未载明的其他用途。

3. 信息安全
3.1 我们采用业界通行的安全技术和措施保护您的个人信息。
3.2 您的密码经过加密存储，我们无法获知您的明文密码。
3.3 您的敏感信息在传输过程中使用加密技术。

4. 信息共享
4.1 我们不会将您的个人信息出售给任何第三方。
4.2 在以下情况下，我们可能会共享您的信息：
  - 获得您的明确同意
  - 法律法规要求
  - 完成您所请求的服务（如支付结算）

5. 数据存储
5.1 您的个人信息存储在中国境内的服务器上。
5.2 我们仅在为您提供服务所必需的期间保留您的个人信息。

6. 您的权利
6.1 您有权访问、更正、删除您的个人信息。
6.2 您有权撤回对某些数据收集的同意。
6.3 您有权注销您的账号。

7. Cookie 和同类技术
7.1 我们可能使用 Cookie 和类似技术来改善用户体验。
7.2 您可以通过浏览器设置拒绝 Cookie。

8. 未成年人保护
8.1 本平台主要面向成年人提供专业服务。
8.2 未满18周岁的未成年人应当在监护人指导下使用本平台。

9. 政策更新
9.1 我们可能会不时更新本隐私政策。
9.2 重大变更将通过平台公告或短信通知您。

10. 联系我们
如果您对本隐私政策有任何疑问，请联系：support@xcai.cn
''';

  static const termsOfService = '''
服务条款

最后更新日期：2026年1月

1. 服务描述
端云智采是一个数据采集众包平台，连接数据需求方与采集员，提供语音、图像、文本、视频等多种类型数据的采集、标注、质检服务。

2. 服务使用条件
2.1 您必须年满18周岁，具备完全民事行为能力。
2.2 您必须通过实名认证才能接收和提交任务。
2.3 您应当保证所使用设备的正常运行和网络畅通。

3. 任务规则
3.1 采集员领取任务后，应当在规定时间内完成并提交。
3.2 提交的数据应当符合任务要求，不得提交无效或虚假数据。
3.3 超时未完成的任务将被系统自动回收。
3.4 质量不合格的提交可能被驳回，采集员有权进行修改后重新提交。

4. 报酬结算
4.1 采集员的报酬按照完成并通过质检的任务数量计算。
4.2 报酬结算周期和方式按照项目约定执行。
4.3 平台有权对欺诈、作弊等违规行为拒绝支付报酬。

5. 违规处理
5.1 以下行为视为违规：
  - 提交虚假或伪造数据
  - 使用自动化工具代替人工采集
  - 盗用他人账号或身份
  - 恶意扰乱平台秩序
5.2 违规行为将导致账号封禁、报酬冻结等处罚。

6. 服务变更与终止
6.1 平台有权根据运营需要调整服务内容。
6.2 重大变更将提前通知用户。
6.3 用户可随时停止使用本平台服务。

7. 责任限制
7.1 平台不对因网络故障、系统维护等原因导致的短暂服务中断承担责任。
7.2 平台对用户因使用服务而产生的间接损失不承担责任。

8. 其他
8.1 本条款的最终解释权归平台所有。
8.2 如本条款的任何部分被认定为无效，其余部分仍具有完全效力。
''';
}
