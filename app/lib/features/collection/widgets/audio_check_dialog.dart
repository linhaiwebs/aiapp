import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_theme.dart';

class AudioCheckResult {
  final bool signalOk, gainOk, silenceOk;
  final double maxDb, avgDb;
  const AudioCheckResult({required this.signalOk, required this.gainOk, required this.silenceOk, required this.maxDb, required this.avgDb});
  bool get allPassed => signalOk && gainOk && silenceOk;
}

Future<AudioCheckResult?> showAudioCheckDialog({
  required BuildContext context,
  required bool checkSignal,
  required bool checkGain,
  required bool checkSilence,
  required int noiseLimitDb,
}) {
  return showGeneralDialog<AudioCheckResult>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: _AudioCheckContent(
            checkSignal: checkSignal,
            checkGain: checkGain,
            checkSilence: checkSilence,
            noiseLimitDb: noiseLimitDb,
          ),
        ),
      );
    },
  );
}

class _AudioCheckContent extends StatefulWidget {
  final bool checkSignal, checkGain, checkSilence;
  final int noiseLimitDb;
  const _AudioCheckContent({required this.checkSignal, required this.checkGain, required this.checkSilence, required this.noiseLimitDb});

  @override State<_AudioCheckContent> createState() => _AudioCheckContentState();
}

class _AudioCheckContentState extends State<_AudioCheckContent> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _rotationAnim;
  String _status = '准备检测...';
  double _progress = 0;
  bool _checking = true, _passed = false;
  bool? _signalOk, _gainOk, _silenceOk;
  double _maxDb = -96, _avgDb = -96;
  final AudioRecorder _checkRecorder = AudioRecorder();
  final List<double> _samples = [];

  @override void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _rotationAnim = Tween<double>(begin: 0, end: 1).animate(_animCtrl);
    _animCtrl.repeat();
    _runCheck();
  }

  @override void dispose() {
    _animCtrl.dispose();
    _checkRecorder.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    try {
      final hasPermission = await _checkRecorder.hasPermission();
      if (!hasPermission) { if (mounted) _setFailed('无麦克风权限'); return; }

      setState(() => _status = '正在检测...');

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/check_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _checkRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1), path: path);

      final sub = _checkRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        _samples.add(amp.current);
        if (mounted) setState(() => _progress = (_progress + 0.05).clamp(0.0, 0.95));
      });

      await Future.delayed(const Duration(seconds: 2));
      await sub.cancel();
      final recordedPath = await _checkRecorder.stop();
      // Clean up temp file
      if (recordedPath != null) {
        try { await (await getTemporaryDirectory()).list().firstWhere((f) => f.path == recordedPath).then((f) => f.delete()); } catch (_) {}
      }

      setState(() => _progress = 1);
      _analyzeResults();
    } catch (e) {
      _setFailed('检测失败: $e');
    }
  }

  void _analyzeResults() {
    if (_samples.isEmpty) { _setFailed('未检测到音频信号'); return; }
    _maxDb = _samples.reduce((a, b) => a > b ? a : b);
    _avgDb = _samples.reduce((a, b) => a + b) / _samples.length;

    _signalOk = widget.checkSignal ? _maxDb > -50 : null;
    _gainOk = widget.checkGain ? (_maxDb > -30 && _maxDb < -2) : null;
    _silenceOk = widget.checkSilence ? _avgDb < -(widget.noiseLimitDb / 2).clamp(10, 40).toDouble() : null;

    _animCtrl.stop();
    setState(() {
      _checking = false;
      _passed = (_signalOk ?? true) && (_gainOk ?? true) && (_silenceOk ?? true);
    });

    if (_passed) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.pop(context, AudioCheckResult(signalOk: _signalOk ?? true, gainOk: _gainOk ?? true, silenceOk: _silenceOk ?? true, maxDb: _maxDb, avgDb: _avgDb));
      });
    }
  }

  void _setFailed(String msg) { _animCtrl.stop(); setState(() { _checking = false; _passed = false; _status = msg; }); }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300.w,
      padding: EdgeInsets.all(28.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular progress
          SizedBox(
            width: 140.w, height: 140.w,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dashed background ring
                CustomPaint(size: Size(140.w, 140.w), painter: _DashedRingPainter(progress: _checking ? null : 1, color: _checking ? AppColors.primary : _passed ? AppColors.secondary : AppColors.error, animCtrl: _checking ? _animCtrl : null)),
                // Center icon/text
                _checking
                    ? RotationTransition(
                        turns: _rotationAnim,
                        child: Icon(Icons.autorenew, size: 32.sp, color: AppColors.primary),
                      )
                    : _passed
                        ? Icon(Icons.check_circle, size: 44.sp, color: AppColors.secondary)
                        : Icon(Icons.warning_rounded, size: 44.sp, color: AppColors.error),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Text(_checking ? _status : _passed ? '检测通过' : '检测未通过', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: _checking ? AppColors.onSurface : _passed ? AppColors.secondary : AppColors.error)),
          SizedBox(height: 16.h),
          if (!_checking) ...[
            if (widget.checkSignal) _row('信号检测', _signalOk!),
            if (widget.checkGain) _row('增幅检测', _gainOk!),
            if (widget.checkSilence) _row('静音检测', _silenceOk!),
            SizedBox(height: 8.h),
            Text('峰值 ${_maxDb.toStringAsFixed(1)} dB · 均值 ${_avgDb.toStringAsFixed(1)} dB', style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant)),
          ],
          SizedBox(height: 20.h),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (!_checking && !_passed)
              SizedBox(
                height: 38.h,
                child: ElevatedButton(
                  onPressed: () { setState(() { _checking = true; _samples.clear(); _progress = 0; }); _animCtrl.repeat(); _runCheck(); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('重新检测'),
                ),
              ),
            if (!_checking) SizedBox(width: 12.w),
            if (!_checking)
              SizedBox(
                height: 38.h,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.onSurfaceVariant, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('取消'),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _row(String label, bool ok) => Padding(
    padding: EdgeInsets.symmetric(vertical: 5.h),
    child: Row(children: [
      Icon(ok ? Icons.check_circle : Icons.cancel, size: 18.sp, color: ok ? AppColors.secondary : AppColors.error),
      SizedBox(width: 8.w),
      Text(label, style: TextStyle(fontSize: 14.sp, color: AppColors.onSurface)),
      const Spacer(),
      Text(ok ? '通过' : '未通过', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: ok ? AppColors.secondary : AppColors.error)),
    ]),
  );
}

/// Dashed ring painter — shows progress as filled dash segments
class _DashedRingPainter extends CustomPainter {
  final double? progress; final Color color; final AnimationController? animCtrl;
  _DashedRingPainter({this.progress, required this.color, this.animCtrl});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    final bgPaint = Paint()..color = color.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;

    const segs = 36;
    final segAngle = 2 * 3.14159 / segs;
    final dashAngle = segAngle * 0.65;

    for (int i = 0; i < segs; i++) {
      final start = i * segAngle;
      if (progress == null) {
        // Animated indeterminate
        final t = (DateTime.now().millisecondsSinceEpoch / 1000.0) % 2;
        final offset = (t * segs / 2).round();
        final active = ((i + offset) % segs) < segs ~/ 2;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, dashAngle, false, active ? paint : bgPaint);
      } else {
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, dashAngle, false, (i / segs) <= progress! ? paint : bgPaint);
      }
    }
  }

  @override bool shouldRepaint(covariant _DashedRingPainter old) => true;
}
