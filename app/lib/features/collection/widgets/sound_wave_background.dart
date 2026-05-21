import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Full-screen animated sound wave background
class SoundWaveBackground extends StatefulWidget {
  final bool isRecording;
  final Color waveColor;
  const SoundWaveBackground({super.key, this.isRecording = false, this.waveColor = const Color(0xFF667eea)});

  @override State<SoundWaveBackground> createState() => _SoundWaveBackgroundState();
}

class _SoundWaveBackgroundState extends State<SoundWaveBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _random = Random(42);

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _ctrl.repeat();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(
          time: _ctrl.value,
          isActive: widget.isRecording,
          color: widget.waveColor,
          random: _random,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double time;
  final bool isActive;
  final Color color;
  final Random random;

  _WavePainter({required this.time, required this.isActive, required this.color, required this.random});

  @override void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final barCount = 60;

    for (int i = 0; i < barCount; i++) {
      final x = i * w / barCount;
      final seed = i * 0.3 + time * 3;
      double barHeight;

      if (isActive) {
        // Active recording - dynamic bars
        barHeight = (sin(seed) * 0.4 + 0.5) * (40 + random.nextDouble() * 60) * 2;
      } else {
        // Idle - subtle wave
        barHeight = (sin(seed) * 0.3 + 0.3) * 20 * 2;
      }

      final alpha = (0.04 + (barHeight / 200) * 0.08).clamp(0.02, 0.12);
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      final barW = (w / barCount) * 0.7;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + (w / barCount - barW) / 2, h / 2 - barHeight / 2, barW, barHeight),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override bool shouldRepaint(covariant _WavePainter old) =>
      old.time != time || old.isActive != isActive;
}
