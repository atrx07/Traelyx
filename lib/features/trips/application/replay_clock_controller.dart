import 'package:flutter/foundation.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';

enum ReplayPlaybackSpeed {
  half(multiplier: 0.5, label: '0.5×'),
  normal(multiplier: 1, label: '1×'),
  doubleSpeed(multiplier: 2, label: '2×');

  const ReplayPlaybackSpeed({required this.multiplier, required this.label});

  final double multiplier;
  final String label;
}

class ReplayClockController extends ChangeNotifier {
  ReplayClockController(this.timeline) : _snapshot = timeline.at(Duration.zero);

  final ReplayTimeline timeline;
  ReplayTimelineSnapshot _snapshot;
  bool _isPlaying = false;
  ReplayPlaybackSpeed _speed = ReplayPlaybackSpeed.normal;

  ReplayTimelineSnapshot get snapshot => _snapshot;
  bool get isPlaying => _isPlaying;
  bool get isAtEnd => _snapshot.position == timeline.duration;
  ReplayPlaybackSpeed get speed => _speed;

  double get fraction =>
      _snapshot.position.inMicroseconds / timeline.duration.inMicroseconds;

  void play() {
    if (_isPlaying) return;
    if (isAtEnd) _snapshot = timeline.at(Duration.zero);
    _isPlaying = true;
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    notifyListeners();
  }

  void setSpeed(ReplayPlaybackSpeed speed) {
    if (_speed == speed) return;
    _speed = speed;
    notifyListeners();
  }

  void advance(Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Must not be negative.');
    }
    if (!_isPlaying || elapsed == Duration.zero) return;
    final scaledMicros = (elapsed.inMicroseconds * _speed.multiplier).round();
    if (scaledMicros <= 0) return;
    final targetMicros = _snapshot.position.inMicroseconds + scaledMicros;
    if (targetMicros >= timeline.duration.inMicroseconds) {
      _snapshot = timeline.at(timeline.duration);
      _isPlaying = false;
      notifyListeners();
      return;
    }
    _snapshot = timeline.at(Duration(microseconds: targetMicros));
    notifyListeners();
  }

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
