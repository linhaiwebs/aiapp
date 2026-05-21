import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';

class AudioCheckResult {
  final bool signalOk, gainOk, silenceOk;
  final double maxDb, avgDb;
  const AudioCheckResult({required this.signalOk, required this.gainOk, required this.silenceOk, required this.maxDb, required this.avgDb});
  bool get allPassed => signalOk && gainOk && silenceOk;
}

/// Audio check that uses amplitude data passed in from the external recorder.
/// Caller must start recording, subscribe to amplitude, and call this dialog.
Future<AudioCheckResult?> showAudioCheckDialog({
  required BuildContext context,
  required bool checkSignal,
  required bool checkGain,
  required bool checkSilence,
  required int noiseLimitDb,
  required Stream<Amplitude> amplitudeStream,
  required Future<void> Function() stopCheck,
}) {
  final samples = <double>[];
  late StreamSubscription<Amplitude> sub;
  bool stopped = false;

  return showDialog<AudioCheckResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Start collecting on first build
          if (!stopped) {
            sub = amplitudeStream.listen((amp) {
              samples.add(amp.current);
              if (ctx.mounted) setDialogState(() {});
            });
            Future.delayed(const Duration(seconds: 2), () async {
              if (stopped) return;
              stopped = true;
              await sub.cancel();
              await stopCheck();
              if (!ctx.mounted) return;

              if (samples.isEmpty) {
                Navigator.pop(ctx);
                return;
              }
              final maxDb = samples.reduce((a, b) => a > b ? a : b);
              final avgDb = samples.reduce((a, b) => a + b) / samples.length;
              final signalOk = checkSignal ? maxDb > -50 : null;
              final gainOk = checkGain ? (maxDb > -30 && maxDb < -2) : null;
              final silenceOk = checkSilence ? avgDb < -(noiseLimitDb / 2).clamp(10, 40).toDouble() : null;
              final allPassed = (signalOk ?? true) && (gainOk ?? true) && (silenceOk ?? true);

              if (allPassed) {
                await Future.delayed(const Duration(milliseconds: 800));
                if (ctx.mounted) Navigator.pop(ctx, AudioCheckResult(signalOk: signalOk ?? true, gainOk: gainOk ?? true, silenceOk: silenceOk ?? true, maxDb: maxDb, avgDb: avgDb));
              } else {
                setDialogState(() {});
              }
            });
          }

          final progress = (samples.length / 40).clamp(0.0, 1.0);
          final checking = samples.length < 30;
          final maxDb = samples.isEmpty ? -96.0 : samples.reduce((a, b) => a > b ? a : b);
          final avgDb = samples.isEmpty ? -96.0 : samples.reduce((a, b) => a + b) / samples.length;
          final signalOk = checkSignal ? maxDb > -50 : null;
          final gainOk = checkGain ? (maxDb > -30 && maxDb < -2) : null;
          final silenceOk = checkSilence ? avgDb < -(noiseLimitDb / 2).clamp(10, 40).toDouble() : null;
          final allPassed = (signalOk ?? true) && (gainOk ?? true) && (silenceOk ?? true);

          return PopScope(
            canPop: !checking,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: SizedBox(
                width: 280.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    // Circular progress
                    SizedBox(
                      width: 120.w, height: 120.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(value: checking ? null : 1, strokeWidth: 4, color: checking ? AppColors.primary : allPassed ? AppColors.secondary : AppColors.error, backgroundColor: AppColors.outlineVariant.withValues(alpha: 0.2)),
                          if (checking)
                            Text('${(samples.length / 20 * 100).toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFFE5E2E1)))
                          else
                            Icon(allPassed ? Icons.check_circle : Icons.warning_rounded, size: 40.sp, color: allPassed ? AppColors.secondary : AppColors.error),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(checking ? '正在检测...' : allPassed ? '检测通过' : '检测未通过',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: checking ? AppColors.onSurface : allPassed ? AppColors.secondary : AppColors.error)),
                    const SizedBox(height: 12),
                    if (!checking) ...[
                      if (checkSignal) _row('信号检测', signalOk!),
                      if (checkGain) _row('增幅检测', gainOk!),
                      if (checkSilence) _row('静音检测', silenceOk!),
                      const SizedBox(height: 4),
                      Text('${maxDb.toStringAsFixed(1)} dB / ${avgDb.toStringAsFixed(1)} dB', style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!checking && !allPassed)
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('重新检测')),
                        if (!checking)
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _row(String label, bool ok) => Padding(
  padding: EdgeInsets.symmetric(vertical: 3.h),
  child: Row(children: [
    Icon(ok ? Icons.check_circle : Icons.cancel, size: 16.sp, color: ok ? AppColors.secondary : AppColors.error),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 13.sp, color: const Color(0xFFE5E2E1))),
    const Spacer(),
    Text(ok ? '通过' : '未通过', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: ok ? AppColors.secondary : AppColors.error)),
  ]),
);
