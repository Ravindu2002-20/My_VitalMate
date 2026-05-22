import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedHealthBackground extends StatefulWidget {
  final double opacity;

  const AnimatedHealthBackground({super.key, this.opacity = 0.55});

  @override
  State<AnimatedHealthBackground> createState() =>
      _AnimatedHealthBackgroundState();
}

class _AnimatedHealthBackgroundState extends State<AnimatedHealthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static final List<_CrossData> _crosses = [
    _CrossData(
      xFactor: 0.08,
      size: 70,
      filled: false,
      delay: 0.02,
      drift: 12,
      rotation: -0.25,
    ),
    _CrossData(
      xFactor: 0.86,
      size: 60,
      filled: false,
      delay: 0.16,
      drift: 10,
      rotation: 0.3,
    ),
    _CrossData(
      xFactor: 0.29,
      size: 45,
      filled: true,
      delay: 0.26,
      drift: 8,
      rotation: -0.18,
    ),
    _CrossData(
      xFactor: 0.95,
      size: 95,
      filled: true,
      delay: 0.38,
      drift: 14,
      rotation: 0.22,
    ),
    _CrossData(
      xFactor: 0.55,
      size: 100,
      filled: false,
      delay: 0.48,
      drift: 16,
      rotation: -0.28,
    ),
    _CrossData(
      xFactor: 0.68,
      size: 50,
      filled: true,
      delay: 0.58,
      drift: 9,
      rotation: 0.2,
    ),
    _CrossData(
      xFactor: 0.12,
      size: 65,
      filled: false,
      delay: 0.66,
      drift: 13,
      rotation: 0.24,
    ),
    _CrossData(
      xFactor: 0.98,
      size: 120,
      filled: true,
      delay: 0.74,
      drift: 18,
      rotation: -0.2,
    ),
    _CrossData(
      xFactor: 0.82,
      size: 75,
      filled: false,
      delay: 0.84,
      drift: 12,
      rotation: 0.26,
    ),
    _CrossData(
      xFactor: 0.34,
      size: 45,
      filled: true,
      delay: 0.91,
      drift: 8,
      rotation: -0.22,
    ),
    _CrossData(
      xFactor: 0.48,
      size: 110,
      filled: false,
      delay: 0.97,
      drift: 17,
      rotation: 0.18,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: _crosses.map((cross) {
                final progress = (_controller.value + cross.delay) % 1;
                final travel = constraints.maxHeight + (cross.size * 2);
                final top = -cross.size + (progress * travel);
                final drift = sin(progress * 2 * pi) * cross.drift;
                final left =
                    (constraints.maxWidth * cross.xFactor) -
                    (cross.size / 2) +
                    drift;

                return Positioned(
                  top: top,
                  left: left,
                  child: Transform.rotate(
                    angle: progress * 2 * pi * cross.rotation,
                    child: Opacity(
                      opacity: widget.opacity,
                      child: _PlusShape(
                        size: cross.size,
                        color: const Color(0xFFCFE7E5),
                        filled: cross.filled,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _CrossData {
  final double xFactor;
  final double size;
  final bool filled;
  final double delay;
  final double drift;
  final double rotation;

  _CrossData({
    required this.xFactor,
    required this.size,
    required this.filled,
    required this.delay,
    required this.drift,
    required this.rotation,
  });
}

class _PlusShape extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;

  const _PlusShape({
    required this.size,
    required this.color,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PlusPainter(color: color, filled: filled),
    );
  }
}

class _PlusPainter extends CustomPainter {
  final Color color;
  final bool filled;

  _PlusPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 4;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path
      ..moveTo(w * 0.35, 0)
      ..lineTo(w * 0.65, 0)
      ..lineTo(w * 0.65, h * 0.35)
      ..lineTo(w, h * 0.35)
      ..lineTo(w, h * 0.65)
      ..lineTo(w * 0.65, h * 0.65)
      ..lineTo(w * 0.65, h)
      ..lineTo(w * 0.35, h)
      ..lineTo(w * 0.35, h * 0.65)
      ..lineTo(0, h * 0.65)
      ..lineTo(0, h * 0.35)
      ..lineTo(w * 0.35, h * 0.35)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlusPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.filled != filled;
  }
}
