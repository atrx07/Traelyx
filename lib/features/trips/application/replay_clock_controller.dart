import 'package:flutter/foundation.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';

class ReplayClockController extends ChangeNotifier {
  ReplayClockController(this.timeline) : _snapshot = timeline.at(Duration.zero);

  final ReplayTimeline timeline;
  ReplayTimelineSnapshot _snapshot;

  ReplayTimelineSnapshot get snapshot => _snapshot;

  double get fraction =>
      _snapshot.position.inMicroseconds / timeline.duration.inMicroseconds;

  void seek(Duration position) {
    final clampedMicros = position.inMicroseconds.clamp(
      0,
      timeline.duration.inMicroseconds,
    );
    final next = Duration(microseconds: clampedMicros);
    if (next == _snapshot.position) return;
    _snapshot = timeline.at(next);
    notifyListeners();
  }

  void seekFraction(double fraction) {
    if (!fraction.isFinite) throw ArgumentError.value(fraction, 'fraction');
    final clamped = fraction.clamp(0.0, 1.0);
    seek(
      Duration(
        microseconds: (timeline.duration.inMicroseconds * clamped).round(),
      ),
    );
  }

  void seekToEvent(int index) {
    if (index < 0 || index >= timeline.events.length) {
      throw RangeError.index(index, timeline.events, 'index');
    }
    seek(timeline.events[index].midpoint);
  }
}
