import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

class SkeletonCard extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;
  const SkeletonCard({super.key, this.height = 100, this.width = double.infinity, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainer,
      highlightColor: AppColors.surfaceContainerHigh,
      child: Container(
        width: width.w,
        height: height.h,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(borderRadius.r),
        ),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainer,
      highlightColor: AppColors.surfaceContainerHigh,
      child: Container(
        width: size.w,
        height: size.w,
        decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
      ),
    );
  }
}

class SkeletonCardRow extends StatelessWidget {
  final int count;
  const SkeletonCardRow({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) => Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: const SkeletonCard(height: 130),
      )),
    );
  }
}

class SkeletonTaskList extends StatelessWidget {
  final int count;
  const SkeletonTaskList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainer,
      highlightColor: AppColors.surfaceContainerHigh,
      child: Column(
        children: List.generate(count, (i) => Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(width: 44.w, height: 44.w, decoration: const BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle)),
            SizedBox(width: 12.w),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 150.w, height: 16.h, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.sm))),
                SizedBox(height: 8.h),
                Container(width: 100.w, height: 12.h, decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.sm))),
              ],
            )),
            Container(width: 60.w, height: 28.h, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.sm))),
          ]),
        )),
      ),
    );
  }
}

class SkeletonTeamList extends StatelessWidget {
  final int count;
  const SkeletonTeamList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceContainer,
      highlightColor: AppColors.surfaceContainerHigh,
      child: Column(
        children: List.generate(count, (i) => Container(
          margin: EdgeInsets.only(bottom: 12.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(width: 44.w, height: 44.w, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.md))),
            SizedBox(width: 12.w),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120.w, height: 16.h, decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(AppRadius.sm))),
                SizedBox(height: 8.h),
                Container(width: 180.w, height: 12.h, decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(AppRadius.sm))),
              ],
            )),
            Icon(Icons.chevron_right, size: 18.sp, color: AppColors.surfaceContainerHigh),
          ]),
        )),
      ),
    );
  }
}

class SkeletonHomeBanner extends StatelessWidget {
  const SkeletonHomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 8.h),
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceContainer,
        highlightColor: AppColors.surfaceContainerHigh,
        child: Container(
          height: 140.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}
