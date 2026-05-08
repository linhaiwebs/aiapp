import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/text_collection_model.dart';
import '../../../core/services/text_collection_service.dart';

class TextCollectionPage extends ConsumerStatefulWidget {
  final String taskId;
  const TextCollectionPage({super.key, required this.taskId});

  @override
  ConsumerState<TextCollectionPage> createState() => _TextCollectionPageState();
}

class _TextCollectionPageState extends ConsumerState<TextCollectionPage> {
  List<TextCollectionModel> _texts = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final [texts, stats] = await Future.wait([
        ref.read(textCollectionServiceProvider).findAll(taskId: widget.taskId),
        ref.read(textCollectionServiceProvider).getStats(widget.taskId),
      ]);
      if (mounted) {
        setState(() {
          _texts = texts as List<TextCollectionModel>;
          _stats = stats as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      appBar: AppBar(
        title: const Text('文本采集', style: TextStyle(color: AppColors.onPrimary)),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: AppColors.onPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                if (_stats != null) _buildStatsBar(),
                Expanded(
                  child: _texts.isEmpty
                      ? Center(child: Text('暂无文本数据', style: TextStyle(fontSize: 14.sp, color: AppColors.onSurfaceVariant)))
                      : ListView.builder(
                          padding: EdgeInsets.all(16.w),
                          itemCount: _texts.length,
                          itemBuilder: (context, index) => _buildTextCard(_texts[index], index),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: EdgeInsets.all(12.w),
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('总计', _stats?['total'] ?? 0, AppColors.primary),
          _statItem('待分配', _stats?['pending'] ?? 0, Colors.grey),
          _statItem('已分配', _stats?['assigned'] ?? 0, Colors.blue),
          _statItem('已完成', _stats?['completed'] ?? 0, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: color)),
        SizedBox(height: 4.h),
        Text(label, style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildTextCard(TextCollectionModel text, int index) {
    final statusColor = switch (text.status) {
      TextStatus.pending => Colors.grey,
      TextStatus.assigned => Colors.blue,
      TextStatus.collecting => Colors.orange,
      TextStatus.completed => AppColors.secondary,
      TextStatus.qcFailed => AppColors.error,
    };

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 28.w, height: 28.w,
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6.r)),
            alignment: Alignment.center,
            child: Text('${index + 1}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: statusColor)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text.content, style: TextStyle(fontSize: 14.sp, color: AppColors.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4.r)),
                      child: Text(text.statusLabel, style: TextStyle(fontSize: 10.sp, color: statusColor)),
                    ),
                    SizedBox(width: 8.w),
                    Text(text.formatLabel, style: TextStyle(fontSize: 10.sp, color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
