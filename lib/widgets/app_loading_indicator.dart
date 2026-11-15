import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Available visual animation styles for the app's loading circle.
enum LoadingAnimationStyle {
  /// Rotating gradient arc with glowing leading tip and optional pulsing leaf core.
  orchardGlow,

  /// Sleek minimalist continuous sweep gradient ring with fading tail.
  chasingSweep,

  /// Concentric dual-ring counter-rotating harmonic orbit.
  dualOrbit,

  /// Orbiting blossom petal dots pulsating in organic sequence.
  petalPulse,
}

/// A modern, customizable animated loading circle widget designed for Magray Orchards.
/// Replaces standard CircularProgressIndicator with orchard-themed animations.
class AppLoadingIndicator extends StatefulWidget {
  /// Global default style used when [style] is not explicitly provided.
  static LoadingAnimationStyle defaultStyle = LoadingAnimationStyle.orchardGlow;

  final double size;
  final Color? color;
  final double strokeWidth;
  final LoadingAnimationStyle? style;
  final bool? showCenterLeaf;

  const AppLoadingIndicator({
    super.key,
    this.size = 28.0,
    this.color,
    this.strokeWidth = 2.6,
    this.style,
    this.showCenterLeaf,
  });

  /// Compact spinner (18px) - ideal for inside buttons and inputs.
  const AppLoadingIndicator.small({
    super.key,
    this.color,
    this.strokeWidth = 2.0,
    this.style,
  })  : size = 18.0,
        showCenterLeaf = false;

  /// Medium spinner (32px) - ideal for section loaders and infinite scrolling.
  const AppLoadingIndicator.medium({
    super.key,
    this.color,
    this.strokeWidth = 2.8,
    this.style,
    this.showCenterLeaf = false,
  }) : size = 32.0;

  /// Large spinner (52px) - ideal for full-page loading with glowing leaf core.
  const AppLoadingIndicator.large({
    super.key,
    this.color,
    this.strokeWidth = 3.2,
    this.style,
    this.showCenterLeaf = true,
  }) : size = 52.0;

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = widget.color ?? theme.colorScheme.primary;
    final activeStyle = widget.style ?? AppLoadingIndicator.defaultStyle;
    final shouldShowLeaf = widget.showCenterLeaf ?? (widget.size >= 40.0);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _buildPainter(activeStyle, indicatorColor),
              ),
              if (shouldShowLeaf && activeStyle == LoadingAnimationStyle.orchardGlow)
                _buildCenterLeaf(indicatorColor),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCenterLeaf(Color indicatorColor) {
    // Gentle breathing scale between 0.88 and 1.08
    final pulse = 0.88 + 0.20 * math.sin(_controller.value * 2 * math.pi).abs();
    final iconSize = widget.size * 0.36;

    return Transform.scale(
      scale: pulse,
      child: Icon(
        Icons.eco_rounded,
        size: iconSize,
        color: indicatorColor.withValues(alpha: 0.85),
      ),
    );
  }

  CustomPainter _buildPainter(LoadingAnimationStyle style, Color color) {
    switch (style) {
      case LoadingAnimationStyle.orchardGlow:
        return _OrchardGlowPainter(
          progress: _controller.value,
          color: color,
          strokeWidth: widget.strokeWidth,
        );
      case LoadingAnimationStyle.chasingSweep:
        return _ChasingSweepPainter(
          progress: _controller.value,
          color: color,
          strokeWidth: widget.strokeWidth,
        );
      case LoadingAnimationStyle.dualOrbit:
        return _DualOrbitPainter(
          progress: _controller.value,
          color: color,
          strokeWidth: widget.strokeWidth,
        );
      case LoadingAnimationStyle.petalPulse:
        return _PetalPulsePainter(
          progress: _controller.value,
          color: color,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Orchard Glow Painter (Sweep Arc + Glowing Bead + Track)
// ─────────────────────────────────────────────────────────────────────────────
class _OrchardGlowPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _OrchardGlowPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth * 2) / 2;
    if (radius <= 0) return;

    // 1. Subtle background track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Continuous rotation angle + dynamic sweep expanding/contracting
    final rotationAngle = progress * 2 * math.pi;
    final sweepAngle = (1.1 + 0.6 * math.sin(progress * 2 * math.pi)) * math.pi;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepGradient = SweepGradient(
      startAngle: 0.0,
      endAngle: sweepAngle,
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.45),
        color,
      ],
      stops: const [0.0, 0.45, 1.0],
    );

    final arcPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, 0.0, sweepAngle, false, arcPaint);

    // 3. Glowing leading bead at the arc tip
    final headX = center.dx + radius * math.cos(sweepAngle);
    final headY = center.dy + radius * math.sin(sweepAngle);
    final beadOffset = Offset(headX, headY);

    // Subtle glow halo
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawCircle(beadOffset, strokeWidth * 1.4, glowPaint);

    // Bright inner core
    final beadCorePaint = Paint()..color = Colors.white;
    canvas.drawCircle(beadOffset, strokeWidth * 0.75, beadCorePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrchardGlowPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Chasing Sweep Painter (Continuous 360 Gradient Sweep)
// ─────────────────────────────────────────────────────────────────────────────
class _ChasingSweepPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _ChasingSweepPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth * 2) / 2;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    final angle = progress * 2 * math.pi;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepGradient = SweepGradient(
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.2),
        color,
      ],
      stops: const [0.0, 0.3, 1.0],
    );

    final arcPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(rect, 0.0, 1.8 * math.pi, false, arcPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChasingSweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Dual Orbit Painter (Concentric Counter-Rotating Rings)
// ─────────────────────────────────────────────────────────────────────────────
class _DualOrbitPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _DualOrbitPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (math.min(size.width, size.height) - strokeWidth * 2) / 2;
    if (outerRadius <= 0) return;
    final innerRadius = outerRadius * 0.62;

    // Outer arc - clockwise
    final outerAngle = progress * 2 * math.pi;
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      outerAngle,
      1.4 * math.pi,
      false,
      outerPaint,
    );

    // Inner arc - counter-clockwise faster
    final innerAngle = -progress * 3 * math.pi;
    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth * 0.85;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      innerAngle,
      1.1 * math.pi,
      false,
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DualOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Petal Pulse Painter (Orbiting Blossom Dots)
// ─────────────────────────────────────────────────────────────────────────────
class _PetalPulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  _PetalPulsePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minDim = math.min(size.width, size.height);
    final orbitRadius = minDim * 0.38;
    final baseDotRadius = minDim * 0.085;
    if (orbitRadius <= 0) return;

    const dotCount = 8;
    for (var i = 0; i < dotCount; i++) {
      final dotAngle = (i * 2 * math.pi / dotCount) - math.pi / 2;
      // Phase shifted wave for each petal dot
      final phase = (progress - (i / dotCount)) % 1.0;
      final scale = 0.35 + 0.65 * math.sin(phase * math.pi).clamp(0.0, 1.0);
      final alpha = (0.2 + 0.8 * scale).clamp(0.0, 1.0);

      final x = center.dx + orbitRadius * math.cos(dotAngle);
      final y = center.dy + orbitRadius * math.sin(dotAngle);

      final dotPaint = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), baseDotRadius * scale, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
