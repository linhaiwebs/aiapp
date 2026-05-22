import 'dart:math';
import 'package:flutter/material.dart';

/// Green gradient with animated floating dots background
class GreenDotBackground extends StatefulWidget {
  const GreenDotBackground({super.key});

  @override State<GreenDotBackground> createState() => _GreenDotBackgroundState();
}

class _GreenDotBackgroundState extends State<GreenDotBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _ctrl, builder: (_, __) {
      return CustomPaint(painter: _GreenDotsPainter(time: _ctrl.value), size: Size.infinite);
    });
  }
}

class _GreenDotsPainter extends CustomPainter {
  final double time;
  _GreenDotsPainter({required this.time});
  final _rng = Random(7);

  @override void paint(Canvas canvas, Size size) {
    // Green gradient background
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [const Color(0xFF1B5E20).withValues(alpha: 0.9), const Color(0xFF0D1B0E).withValues(alpha: 0.95), const Color(0xFF050A05)],
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = gradient.createShader(Offset.zero & size));

    // Animated floating dots
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.55;

    for (int i = 0; i < 80; i++) {
      final angle = (i * 0.45 + time * 0.8) % (3.14159 * 2);
      final dist = (maxRadius * (0.15 + 0.7 * (sin(i * 1.7 + time * 1.2) * 0.5 + 0.5)));
      final x = center.dx + cos(angle) * dist;
      final y = center.dy + sin(angle + (i % 3) * 0.5) * dist * 0.7;
      final dotR = 2.5 + 6 * (sin(i * 0.8 + time * 1.5) * 0.5 + 0.5);
      final alpha = 0.08 + 0.2 * (sin(i * 1.3 + time * 2) * 0.5 + 0.5);

      final paint = Paint()
        ..color = const Color(0xFF66BB6A).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), dotR, paint);
    }
  }

  @override bool shouldRepaint(covariant _GreenDotsPainter old) => old.time != time;
}
