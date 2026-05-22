import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Full-width real-time audio wave visualization during recording
class AudioWaveWidget extends StatefulWidget {
  final Stream<double>? amplitudeStream;
  final bool isRecording;
  const AudioWaveWidget({super.key, this.amplitudeStream, this.isRecording = false});

  @override State<AudioWaveWidget> createState() => _AudioWaveWidgetState();
}

class _AudioWaveWidgetState extends State<AudioWaveWidget> with SingleTickerProviderStateMixin {
  double _currentDb = -96;
  double _smoothDb = -96;
  late AnimationController _idleCtrl;

  @override void initState() {
    super.initState();
    _idleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    widget.amplitudeStream?.listen((db) {
      if (mounted) setState(() => _currentDb = db);
    });
  }

  @override void dispose() { _idleCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    _smoothDb = _smoothDb * 0.7 + _currentDb * 0.3; // Smooth transitions
    final normalized = widget.isRecording ? ((_smoothDb + 60) / 60).clamp(0.05, 1.0) : (_idleCtrl.value * 0.3).clamp(0.02, 0.3);

    return SizedBox(height: 52.h, child: CustomPaint(
      size: Size.infinite,
      painter: _BarWavePainter(normalized: normalized, isRecording: widget.isRecording, time: _idleCtrl.value),
    ));
  }
}

class _BarWavePainter extends CustomPainter {
  final double normalized; final bool isRecording; final double time;
  _BarWavePainter({required this.normalized, required this.isRecording, required this.time});

  @override void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    const barCount = 64;
    final barW = (w / barCount) * 0.65;
    final gap = (w / barCount) * 0.35;
    final maxBarH = h * 0.85;
    final rng = Random(42);

    for (int i = 0; i < barCount; i++) {
      double barH;
      if (isRecording) {
        final seed = sin(i * 0.4 + time * 8) * 0.3;
        barH = (normalized * (0.4 + rng.nextDouble() * 0.6) + seed * 0.15).clamp(0.04, 1.0) * maxBarH;
      } else {
        barH = (sin(i * 0.3 + time * 4) * 0.15 + 0.15).clamp(0.02, 0.3) * maxBarH;
      }

      final x = i * (barW + gap) + gap / 2;
      final alpha = (0.12 + barH / maxBarH * 0.3).clamp(0.08, 0.45);
      final color = isRecording
          ? Color.lerp(const Color(0xFF4CAF50), const Color(0xFF81C784), barH / maxBarH)!
          : const Color(0xFF4CAF50).withValues(alpha: alpha);

      final paint = Paint()..color = color..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h - barH, barW, barH), const Radius.circular(2)),
        paint,
      );
    }
  }

  @override bool shouldRepaint(covariant _BarWavePainter old) =>
      old.normalized != normalized || old.isRecording != isRecording || old.time != time;
}
