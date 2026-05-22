import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedMedicalBackground extends StatefulWidget {
  final double opacity;

  const AnimatedMedicalBackground({
    super.key,
    this.opacity = 0.28,
  });

  @override
  State<AnimatedMedicalBackground> createState() =>
      _AnimatedMedicalBackgroundState();
}

class _AnimatedMedicalBackgroundState
    extends State<AnimatedMedicalBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static final List<_MedicalItemData> _items = [
    _MedicalItemData(
      xFactor: 0.08,
      size: 90,
      delay: 0.02,
      drift: 12,
      rotation: -0.12,
      type: MedicalShapeType.stethoscope,
    ),
    _MedicalItemData(
      xFactor: 0.82,
      size: 70,
      delay: 0.14,
      drift: 10,
      rotation: 0.15,
      type: MedicalShapeType.medikit,
    ),
    _MedicalItemData(
      xFactor: 0.26,
      size: 60,
      delay: 0.24,
      drift: 9,
      rotation: -0.10,
      type: MedicalShapeType.stethoscope,
    ),
    _MedicalItemData(
      xFactor: 0.95,
      size: 110,
      delay: 0.36,
      drift: 15,
      rotation: 0.12,
      type: MedicalShapeType.medikit,
    ),
    _MedicalItemData(
      xFactor: 0.52,
      size: 120,
      delay: 0.48,
      drift: 17,
      rotation: -0.18,
      type: MedicalShapeType.stethoscope,
    ),
    _MedicalItemData(
      xFactor: 0.66,
      size: 65,
      delay: 0.58,
      drift: 8,
      rotation: 0.10,
      type: MedicalShapeType.medikit,
    ),
    _MedicalItemData(
      xFactor: 0.12,
      size: 85,
      delay: 0.70,
      drift: 13,
      rotation: -0.14,
      type: MedicalShapeType.stethoscope,
    ),
    _MedicalItemData(
      xFactor: 0.92,
      size: 125,
      delay: 0.82,
      drift: 18,
      rotation: 0.16,
      type: MedicalShapeType.medikit,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
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
            return Container(
              color: const Color.fromARGB(255, 246, 255, 252),
              child: Stack(
              clipBehavior: Clip.hardEdge,
              children: _items.map((item) {
                final progress =
                    (_controller.value + item.delay) % 1;

                final travel =
                    constraints.maxHeight +
                    (item.size * 2);

                final top =
                    -item.size +
                    (progress * travel);

                final drift =
                    sin(progress * 2 * pi) *
                    item.drift;

                final left =
                    (constraints.maxWidth *
                            item.xFactor) -
                        (item.size / 2) +
                    drift;

                // Smooth fade animation
                final fade =
                    sin(progress * pi).clamp(0.0, 1.0);

                // Slightly darker large items
                final color =
                    item.size > 100
                        ? const Color(0xFF4FA897)
                        : const Color(0xFF7BC7B5);

                return Positioned(
                  top: top,
                  left: left,
                  child: Transform.rotate(
                    angle:
                        progress *
                        2 *
                        pi *
                        item.rotation,
                    child: Opacity(
                      opacity:
                          widget.opacity * fade,
                      child: _MedicalShape(
                        size: item.size,
                        type: item.type,
                        color: color,
                      ),
                    ),
                  ),
                );
              }).toList(),
              )
            );
          },
        );
      },
    );
  }
}

enum MedicalShapeType {
  stethoscope,
  medikit,
}

class _MedicalItemData {
  final double xFactor;
  final double size;
  final double delay;
  final double drift;
  final double rotation;
  final MedicalShapeType type;

  _MedicalItemData({
    required this.xFactor,
    required this.size,
    required this.delay,
    required this.drift,
    required this.rotation,
    required this.type,
  });
}

class _MedicalShape extends StatelessWidget {
  final double size;
  final Color color;
  final MedicalShapeType type;

  const _MedicalShape({
    required this.size,
    required this.color,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MedicalPainter(
        color: color,
        type: type,
      ),
    );
  }
}

class _MedicalPainter extends CustomPainter {
  final Color color;
  final MedicalShapeType type;

  _MedicalPainter({
    required this.color,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case MedicalShapeType.stethoscope:
        _drawStethoscope(canvas, size);
        break;

      case MedicalShapeType.medikit:
        _drawMedikit(canvas, size);
        break;
    }
  }

  void _drawStethoscope(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final path = Path();

    // Left tube
    path.moveTo(w * 0.3, h * 0.15);
    path.quadraticBezierTo(
      w * 0.22,
      h * 0.45,
      w * 0.4,
      h * 0.6,
    );

    // Right tube
    path.moveTo(w * 0.7, h * 0.15);
    path.quadraticBezierTo(
      w * 0.78,
      h * 0.45,
      w * 0.6,
      h * 0.6,
    );

    // Bottom tube
    path.moveTo(w * 0.4, h * 0.6);
    path.quadraticBezierTo(
      w * 0.5,
      h * 0.84,
      w * 0.6,
      h * 0.6,
    );

    canvas.drawPath(path, paint);

    // Chest piece
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.84),
      w * 0.08,
      paint,
    );

    // Ear tips
    canvas.drawCircle(
      Offset(w * 0.3, h * 0.12),
      w * 0.04,
      paint,
    );

    canvas.drawCircle(
      Offset(w * 0.7, h * 0.12),
      w * 0.04,
      paint,
    );
  }

  void _drawMedikit(
    Canvas canvas,
    Size size,
  ) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        w * 0.15,
        h * 0.28,
        w * 0.7,
        h * 0.52,
      ),
      const Radius.circular(14),
    );

    canvas.drawRRect(body, fillPaint);
    canvas.drawRRect(body, strokePaint);

    // Handle
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        w * 0.36,
        h * 0.12,
        w * 0.28,
        h * 0.14,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(handle, strokePaint);

    // Medical cross
    canvas.drawLine(
      Offset(w * 0.5, h * 0.38),
      Offset(w * 0.5, h * 0.68),
      strokePaint,
    );

    canvas.drawLine(
      Offset(w * 0.35, h * 0.53),
      Offset(w * 0.65, h * 0.53),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MedicalPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.type != type;
  }
}