import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:record/record.dart';
import '../../../core/theme/app_theme.dart';

/// Pre-recording audio check result
class AudioCheckResult {
  final bool signalOk, gainOk, silenceOk;
  final double maxDb, avgDb;

  const AudioCheckResult({
    required this.signalOk, required this.gainOk, required this.silenceOk,
    required this.maxDb, required this.avgDb,
  });

  bool get allPassed => signalOk && gainOk && silenceOk;
}

Future<AudioCheckResult?> showAudioCheckDialog({
  required BuildContext context,
  required bool checkSignal,
  required bool checkGain,
  required bool checkSilence,
  required int noiseLimitDb,
}) {
  return showDialog<AudioCheckResult>(
    context: context, barrierDismissible: false,
    builder: (ctx) => _AudioCheckDialog(checkSignal: checkSignal, checkGain: checkGain, checkSilence: checkSilence, noiseLimitDb: noiseLimitDb),
  );
}

class _AudioCheckDialog extends StatefulWidget {
  final bool checkSignal, checkGain, checkSilence;
  final int noiseLimitDb;
  const _AudioCheckDialog({required this.checkSignal, required this.checkGain, required this.checkSilence, required this.noiseLimitDb});

  @override State<_AudioCheckDialog> createState() => _AudioCheckDialogState();
}

class _AudioCheckDialogState extends State<_AudioCheckDialog> with SingleTickerProviderStateMixin {
  final AudioRecorder _checkRecorder = AudioRecorder();
  String _status = '准备检测...';
  double _progress = 0;
  bool _checking = true, _passed = false;
  bool? _signalOk, _gainOk, _silenceOk;
  double _maxDb = -96, _avgDb = -96;
  Timer? _timer;
  double _animValue = 0;
  final List<double> _samples = [];

  @override void initState() { super.initState(); _startAnimation(); _runCheck(); }
  @override void dispose() { _timer?.cancel(); _checkRecorder.dispose(); super.dispose(); }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() => _animValue = (_animValue + 0.1) % (3.14159 * 2));
    });
  }

  Future<void> _runCheck() async {
    try {
      final hasPermission = await _checkRecorder.hasPermission();
      if (!hasPermission) { if (mounted) _setFailed('无麦克风权限'); return; }

      setState(() => _status = '正在检测...');
      await _checkRecorder.start(const RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 1, sampleRate: 16000), path: '');

      final sub = _checkRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        _samples.add(amp.current.abs());
        if (mounted) setState(() => _progress = (_progress + 0.05).clamp(0.0, 0.95));
      });

      await Future.delayed(const Duration(seconds: 2));
      await sub.cancel();
      await _checkRecorder.stop();

      setState(() => _progress = 1);
      _analyzeResults();
    } catch (e) {
      _setFailed('检测失败: $e');
    }
  }

  void _analyzeResults() {
    if (_samples.isEmpty) { _setFailed('未检测到音频信号'); return; }

    // Values are dBFS from onAmplitudeChanged: 0=max, -96=silence
    _maxDb = _samples.reduce((a, b) => a > b ? a : b);
    _avgDb = _samples.reduce((a, b) => a + b) / _samples.length;

    _signalOk = widget.checkSignal ? _maxDb > -50 : null;
    _gainOk = widget.checkGain ? (_maxDb > -30 && _maxDb < -2) : null;
    _silenceOk = widget.checkSilence ? _avgDb < -(widget.noiseLimitDb / 2) : null;

    setState(() {
      _checking = false;
      _passed = (_signalOk ?? true) && (_gainOk ?? true) && (_silenceOk ?? true);
    });

    if (_passed && mounted) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) Navigator.pop(context, AudioCheckResult(signalOk: _signalOk ?? true, gainOk: _gainOk ?? true, silenceOk: _silenceOk ?? true, maxDb: _maxDb, avgDb: _avgDb));
      });
    }
  }

  void _setFailed(String msg) { setState(() { _checking = false; _passed = false; _status = msg; }); }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_checking,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 260.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              SizedBox(
                width: 140.w, height: 140.w,
                child: CustomPaint(
                  painter: _DashedCirclePainter(progress: _checking ? null : 1, color: _checking ? AppColors.primary : _passed ? AppColors.secondary : AppColors.error, animValue: _animValue),
                  child: Center(
                    child: _checking
                        ? Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.mic, size: 36.sp, color: AppColors.primary), const SizedBox(height: 4), Text(_status, style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant))])
                        : _passed ? Icon(Icons.check_circle, size: 48.sp, color: AppColors.secondary) : Icon(Icons.warning_rounded, size: 48.sp, color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (!_checking) ...[
                if (widget.checkSignal) _row('信号检测', _signalOk!),
                if (widget.checkGain) _row('增幅检测', _gainOk!),
                if (widget.checkSilence) _row('静音检测', _silenceOk!),
                const SizedBox(height: 8),
                Text('最大: ${_maxDb.toStringAsFixed(1)} dB  平均: ${_avgDb.toStringAsFixed(1)} dB', style: TextStyle(fontSize: 11.sp, color: AppColors.onSurfaceVariant)),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (!_checking && !_passed) TextButton(onPressed: () { setState(() { _checking = true; _samples.clear(); }); _startAnimation(); _runCheck(); }, child: const Text('重新检测')),
                if (!_checking) TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, bool ok) => Padding(
    padding: EdgeInsets.symmetric(vertical: 4.h),
    child: Row(children: [
      Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined, size: 16.sp, color: ok ? AppColors.secondary : AppColors.error),
      const SizedBox(width: 8),
      Text(label, style: TextStyle(fontSize: 13.sp, color: AppColors.onSurface)),
      const Spacer(),
      Text(ok ? '通过' : '未通过', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: ok ? AppColors.secondary : AppColors.error)),
    ]),
  );
}

class _DashedCirclePainter extends CustomPainter {
  final double? progress; final Color color; final double animValue;
  _DashedCirclePainter({this.progress, required this.color, required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
    final bgPaint = Paint()..color = color.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 3;
    const totalDashes = 40;
    final sweepAngle = (3.14159 * 2) / totalDashes;
    final dashLength = sweepAngle * 0.6;
    for (int i = 0; i < totalDashes; i++) {
      final startAngle = i * sweepAngle;
      if (progress == null) {
        final highlighted = ((i + animValue * 3).round() % totalDashes) < 10;
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, dashLength, false, highlighted ? paint : bgPaint);
      } else {
        canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, dashLength, false, (i / totalDashes) <= progress! ? paint : bgPaint);
      }
    }
  }

  @override bool shouldRepaint(covariant _DashedCirclePainter old) => true;
}
