import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/drive_dna/domain/drive_dna_models.dart';

class DriveDnaSignature extends StatelessWidget {
  const DriveDnaSignature({
    required this.dimensions,
    required this.centerLabel,
    required this.centerValue,
    super.key,
  });

  final List<DriveDnaDimension> dimensions;
  final String centerLabel;
  final String centerValue;

  @override
  Widget build(BuildContext context) {
    final summary = dimensions
        .map((dimension) {
          final label = driveDnaDimensionLabel(dimension.type);
          final value = dimension.value;
          final delta = dimension.recentDelta;
          if (value == null) return '$label: insufficient data';
          final direction = delta == null
              ? ''
              : ', ${driveDnaTrendLabel(delta)}';
          return '$label: ${value.round()} out of 100$direction';
        })
        .join('. ');

    return Semantics(
      label: 'Drive DNA signature. $centerLabel: $centerValue. $summary.',
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: TweenAnimationBuilder<double>(
            key: const ValueKey('drive-dna-signature-animation'),
            tween: Tween(begin: 0, end: 1),
            duration: TraelyxMotion.effectiveDuration(
              context,
              TraelyxMotion.emphasized,
            ),
            curve: TraelyxMotion.emphasizedCurve,
            builder: (context, progress, child) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    key: const ValueKey('drive-dna-signature-painter'),
                    painter: _DriveDnaSignaturePainter(
                      dimensions: dimensions,
                      progress: progress,
                      colors: context.traelyxColors,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.traelyxColors.canvas,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.traelyxColors.outlineStrong,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 94,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                centerValue,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: TraelyxSpacing.xxs),
                              Text(
                                centerLabel.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DriveDnaSignaturePainter extends CustomPainter {
  const _DriveDnaSignaturePainter({
    required this.dimensions,
    required this.progress,
    required this.colors,
  });

  final List<DriveDnaDimension> dimensions;
  final double progress;
  final TraelyxSemanticColors colors;

  static const _startAngles = [-2.72, -2.35, -2.92, -2.5, -2.18];
  static const _trackSweeps = [5.0, 4.62, 5.18, 4.82, 5.08];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = math.min(size.width, size.height) / 2 - 10;
    final spacing = math.max(15.0, outerRadius * 0.105);
    final strokeWidth = math.max(7.0, outerRadius * 0.052);
    final palette = [
      colors.accent,
      colors.positive,
      colors.information,
      colors.caution,
      colors.textPrimary,
    ];

    for (var index = 0; index < dimensions.length; index++) {
      final radius = outerRadius - index * spacing;
      if (radius <= 58) break;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final start = _startAngles[index];
      final trackSweep = _trackSweeps[index];
      final trackPaint = Paint()
        ..color = colors.outline.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, trackSweep, false, trackPaint);

      final dimension = dimensions[index];
      final value = dimension.value;
      if (value == null) {
        final tickPaint = Paint()
          ..color = colors.textSecondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        for (var tick = 1; tick <= 3; tick++) {
          final angle = start + trackSweep * (0.18 + tick * 0.16);
          final inner = Offset(
            center.dx + math.cos(angle) * (radius - strokeWidth),
            center.dy + math.sin(angle) * (radius - strokeWidth),
          );
          final outer = Offset(
            center.dx + math.cos(angle) * (radius + strokeWidth),
            center.dy + math.sin(angle) * (radius + strokeWidth),
          );
          canvas.drawLine(inner, outer, tickPaint);
        }
        continue;
      }

      final normalized = (value / 100).clamp(0.0, 1.0);
      final activeSweep = trackSweep * normalized * progress;
      final activePaint = Paint()
        ..color = palette[index]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, activeSweep, false, activePaint);

      if (progress > 0.98) {
        final endAngle = start + trackSweep * normalized;
        final endpoint = Offset(
          center.dx + math.cos(endAngle) * radius,
          center.dy + math.sin(endAngle) * radius,
        );
        canvas.drawCircle(
          endpoint,
          strokeWidth * 0.42,
          activePaint..style = PaintingStyle.fill,
        );

        final delta = dimension.recentDelta;
        if (delta != null) {
          final previous = ((value - delta) / 100).clamp(0.0, 1.0);
          final previousAngle = start + trackSweep * previous;
          final marker = Offset(
            center.dx + math.cos(previousAngle) * radius,
            center.dy + math.sin(previousAngle) * radius,
          );
          canvas.drawCircle(
            marker,
            strokeWidth * 0.54,
            Paint()
              ..color = colors.canvas
              ..style = PaintingStyle.fill,
          );
          canvas.drawCircle(
            marker,
            strokeWidth * 0.38,
            Paint()
              ..color = colors.textPrimary
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DriveDnaSignaturePainter oldDelegate) =>
      oldDelegate.dimensions != dimensions ||
      oldDelegate.progress != progress ||
      oldDelegate.colors != colors;
}

String driveDnaDimensionLabel(DriveDnaDimensionType type) => switch (type) {
  DriveDnaDimensionType.smoothness => 'Smoothness',
  DriveDnaDimensionType.brakingControl => 'Braking control',
  DriveDnaDimensionType.accelerationControl => 'Acceleration control',
  DriveDnaDimensionType.corneringControl => 'Cornering control',
  DriveDnaDimensionType.consistency => 'Consistency',
};

String driveDnaTrendLabel(double delta) {
  final rounded = delta.round();
  if (rounded > 0) return 'recent direction plus $rounded points';
  if (rounded < 0) return 'recent direction minus ${rounded.abs()} points';
  return 'recent direction steady';
}
