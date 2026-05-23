import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Real human voice waveform visualization
class AudioWaveWidget extends StatefulWidget {
  final Stream<double>? amplitudeStream;
  final bool isRecording;
  const AudioWaveWidget({super.key, this.amplitudeStream, this.isRecording = false});

  @override State<AudioWaveWidget> createState() => _AudioWaveWidgetState();
}

class _AudioWaveWidgetState extends State<AudioWaveWidget> with SingleTickerProviderStateMixin {
  double _currentDb = -96;
  double _smoothDb = -96;
  late AnimationController _ctrl;
  final _barHeights = List<double>.filled(80, 2.0);

  @override void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))..repeat();
    widget.amplitudeStream?.listen((db) {
      if (mounted) setState(() => _currentDb = db);
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    _smoothDb = _smoothDb * 0.65 + _currentDb * 0.35;
    final energy = widget.isRecording ? ((_smoothDb + 60) / 60).clamp(0.03, 1.0) : 0.06;

    // Update bar heights toward target based on voice energy
    final rng = Random(DateTime.now().microsecondsSinceEpoch % 10000);
    for (int i = 0; i < _barHeights.length; i++) {
      // Create natural voice envelope: loud in the middle, taper at edges
      final posInWave = (i / _barHeights.length - 0.5).abs() * 2; // 0 at center, 1 at edges
      final envelope = (1.0 - posInWave * 0.7); // 1.0 center → 0.3 edges
      // Each bar gets energy + slight voice-like variation
      final microVariance = (sin(i * 0.7 + _ctrl.value * 15) * 0.12 + sin(i * 1.9 + _ctrl.value * 23) * 0.08);
      final targetHeight = (energy * envelope + microVariance).clamp(0.02, 1.0) * 44.0.h;
      // Smooth transition toward target (80% old, 20% new)
      _barHeights[i] = _barHeights[i] * 0.78 + targetHeight * 0.22;
    }

    return SizedBox(height: 52.h, child: CustomPaint(
      size: Size.infinite,
      painter: _VoiceWavePainter(barHeights: _barHeights, energy: energy, isRecording: widget.isRecording),
    ));
  }
}

class _VoiceWavePainter extends CustomPainter {
  final List<double> barHeights;
  final double energy;
  final bool isRecording;
  _VoiceWavePainter({required this.barHeights, required this.energy, required this.isRecording});

  @override void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final barW = (w / barHeights.length) * 0.6;
    final gap = (w / barHeights.length) * 0.4;

    for (int i = 0; i < barHeights.length; i++) {
      final barH = barHeights[i].clamp(2.0, h * 0.95);
      final x = i * (barW + gap) + gap / 2;
      // Color intensity follows bar height — hotter when energetic
      final intensity = (barH / (h * 0.95)).clamp(0.06, 1.0);
      final alpha = (0.08 + intensity * 0.4).clamp(0.06, 0.55);

      Color color;
      if (isRecording) {
        if (intensity > 0.6) {
          color = Color.lerp(const Color(0xFF66BB6A), const Color(0xFFA5D6A7), (intensity - 0.6) / 0.4)!;
        } else if (intensity > 0.3) {
          color = Color.lerp(const Color(0xFF388E3C), const Color(0xFF66BB6A), (intensity - 0.3) / 0.3)!;
        } else {
          color = const Color(0xFF2E7D32).withValues(alpha: alpha);
        }
      } else {
        color = const Color(0xFF4CAF50).withValues(alpha: 0.08);
      }

      final paint = Paint()..color = color..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, h - barH, barW, barH), Radius.circular(barW * 0.4)),
        paint,
      );

      // Mirror the wave (bottom half)
      final mirrorH = barH * 0.5;
      final mirrorAlpha = alpha * 0.4;
      final mirrorPaint = Paint()..color = color.withValues(alpha: mirrorAlpha)..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barW, mirrorH), Radius.circular(barW * 0.4)),
        mirrorPaint,
      );
    }
  }

  @override bool shouldRepaint(covariant _VoiceWavePainter old) => true;
}
