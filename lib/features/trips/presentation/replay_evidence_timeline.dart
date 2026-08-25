import 'package:flutter/material.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';

class ReplayEvidenceTimeline extends StatelessWidget {
  const ReplayEvidenceTimeline({
    required this.timeline,
    required this.snapshot,
    super.key,
  });

  final ReplayTimeline timeline;
  final ReplayTimelineSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final routeSpanCount = timeline.routeSpans.length;
    final eventCount = timeline.events.length;
    return Semantics(
      container: true,
      image: true,
      label:
          'Replay evidence timeline. $routeSpanCount verified route ${routeSpanCount == 1 ? 'span' : 'spans'} and $eventCount persisted ${eventCount == 1 ? 'event' : 'events'}. Cursor at ${formatReplayOffset(snapshot.position)} of ${formatReplayOffset(timeline.duration)}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 76,
              child: CustomPaint(
                key: const ValueKey('replay-evidence-graph'),
                painter: ReplayEvidencePainter(
                  timeline: timeline,
                  snapshot: snapshot,
                  colors: context.traelyxColors,
                ),
              ),
            ),
            const SizedBox(height: TraelyxSpacing.xs),
            Wrap(
              spacing: TraelyxSpacing.lg,
              runSpacing: TraelyxSpacing.xs,
              children: [
                _EvidenceLegend(
                  icon: Icons.route_outlined,
                  label: routeSpanCount == 0
                      ? 'Route unavailable'
                      : '$routeSpanCount route ${routeSpanCount == 1 ? 'span' : 'spans'}',
                ),
                _EvidenceLegend(
                  icon: Icons.bolt_outlined,
                  label: eventCount == 0
                      ? 'Events unavailable'
                      : '$eventCount persisted ${eventCount == 1 ? 'event' : 'events'}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceLegend extends StatelessWidget {
  const _EvidenceLegend({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: context.traelyxColors.textSecondary),
        const SizedBox(width: TraelyxSpacing.xxs),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class ReplayEvidencePainter extends CustomPainter {
  ReplayEvidencePainter({
    required this.timeline,
    required this.snapshot,
    required this.colors,
  });

  final ReplayTimeline timeline;
  final ReplayTimelineSnapshot snapshot;
  final TraelyxSemanticColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 8.0;
    final left = horizontalPadding;
    final right = size.width - horizontalPadding;
    const routeY = 23.0;
    const eventY = 53.0;
    final baseline = Paint()
      ..color = colors.outline
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, routeY), Offset(right, routeY), baseline);
    canvas.drawLine(Offset(left, eventY), Offset(right, eventY), baseline);

    final routePaint = Paint()
      ..color = colors.accent
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (final span in timeline.routeSpans) {
      canvas.drawLine(
        Offset(_x(span.start, left, right), routeY),
        Offset(_x(span.end, left, right), routeY),
        routePaint,
      );
    }

    final eventPaint = Paint()..color = colors.caution;
    for (final event in timeline.events) {
      final start = _x(event.start, left, right);
      final end = _x(event.end, left, right);
      if (end - start < 3) {
        final marker = Path()
          ..moveTo(start, eventY - 7)
          ..lineTo(start + 7, eventY)
          ..lineTo(start, eventY + 7)
          ..lineTo(start - 7, eventY)
          ..close();
        canvas.drawPath(marker, eventPaint);
        continue;
      }
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(start, eventY - 6, end, eventY + 6),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, eventPaint);
    }

    final cursorX = _x(snapshot.position, left, right);
    canvas.drawLine(
      Offset(cursorX, 5),
      Offset(cursorX, size.height - 5),
      Paint()
        ..color = colors.textPrimary
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(cursorX, routeY),
      5,
      Paint()
        ..color = colors.canvas
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cursorX, routeY),
      5,
      Paint()
        ..color = colors.textPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  double _x(Duration position, double left, double right) {
    final fraction = position.inMicroseconds / timeline.duration.inMicroseconds;
    return left + (right - left) * fraction.clamp(0.0, 1.0);
  }

  @override
  bool shouldRepaint(covariant ReplayEvidencePainter oldDelegate) {
    return oldDelegate.timeline != timeline ||
        oldDelegate.snapshot.position != snapshot.position ||
        oldDelegate.colors != colors;
  }
}

String formatReplayOffset(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '${value.inMinutes}:$seconds';
}
