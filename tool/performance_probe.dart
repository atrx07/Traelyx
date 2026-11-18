import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:traelyx/core/maps/map_contract.dart';
import 'package:traelyx/core/maps/offline_route_map.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/trips/application/replay_clock_controller.dart';
import 'package:traelyx/features/trips/domain/replay_timeline.dart';
import 'package:traelyx/features/trips/presentation/replay_evidence_timeline.dart';

import 'performance_workload.dart';

const _reportChannel = MethodChannel(
  'io.github.atrx07.traelyx/performance-qa/v1',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kProfileMode) {
    throw StateError('The performance probe requires profile mode.');
  }
  runApp(MaterialApp(theme: TraelyxTheme.dark, home: const _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with SingleTickerProviderStateMixin {
  late final MapRouteGeometry route = performanceRoute();
  late final ReplayTimeline timeline = performanceTimeline(route);
  late final ReplayClockController clock = ReplayClockController(timeline);
  late final Ticker ticker = createTicker(_tick);
  final buildTimes = <double>[];
  final rasterTimes = <double>[];
  final totalTimes = <double>[];
  Map<String, Object>? databaseReport;
  Duration previous = Duration.zero;
  bool collecting = false;
  bool finishing = false;
  String status = 'Preparing synthetic 1,000-trip database';

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    Directory? temporary;
    try {
      final path = await _reportChannel.invokeMethod<String>(
        'temporaryDirectory',
      );
      if (path == null) throw StateError('QA temporary directory unavailable.');
      final root = Directory(path);
      temporary = await root.createTemp('m8-performance-');
      databaseReport = await benchmarkDatabase(
        NativeDatabase(File('${temporary.path}/synthetic.sqlite')),
      );
      await temporary.delete(recursive: true);
      temporary = null;
      if (!mounted) return;
      setState(() {
        status = 'Profiling production replay renderers';
      });
      clock.play();
      unawaited(ticker.start());
    } catch (_) {
      if (temporary != null && temporary.existsSync()) {
        await temporary.delete(recursive: true);
      }
      await _reportChannel.invokeMethod<void>(
        'failed',
        'database_probe_failed',
      );
      if (mounted) {
        setState(() {
          status = 'Performance probe failed';
        });
      }
    }
  }

  void _timings(List<ui.FrameTiming> timings) {
    for (final frame in timings) {
      if (buildTimes.length >= 20000) break;
      buildTimes.add(frame.buildDuration.inMicroseconds / 1000);
      rasterTimes.add(frame.rasterDuration.inMicroseconds / 1000);
      totalTimes.add(frame.totalSpan.inMicroseconds / 1000);
    }
  }

  void _tick(Duration elapsed) {
    if (finishing) return;
    final delta = elapsed - previous;
    previous = elapsed;
    clock.advance(delta);
    if (!collecting && elapsed >= const Duration(seconds: 3)) {
      collecting = true;
      SchedulerBinding.instance.addTimingsCallback(_timings);
    }
    if (elapsed >= const Duration(seconds: 33)) {
      unawaited(_finish());
      return;
    }
    setState(() {});
  }

  Future<void> _finish() async {
    finishing = true;
    ticker.stop();
    clock.pause();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    if (buildTimes.length < 100) {
      await _reportChannel.invokeMethod<void>(
        'failed',
        'insufficient_rendered_frames',
      );
      return;
    }
    final report = <String, Object>{
      'contract_version': 1,
      'workload_version': performanceWorkloadVersion,
      'build_mode': 'profile',
      'database': databaseReport!,
      'replay': {
        'workload':
            'production offline map, evidence timeline and normal-speed replay clock',
        'route_points': 1000,
        'route_segments': 2,
        'event_count': 50,
        'warmup_seconds': 3,
        'sample_window_seconds': 30,
        'build': timingDistribution(buildTimes),
        'raster': timingDistribution(rasterTimes),
        'total_span': timingDistribution(totalTimes),
        'build_over_60fps_budget': buildTimes
            .where((value) => value > 1000 / 60)
            .length,
        'raster_over_60fps_budget': rasterTimes
            .where((value) => value > 1000 / 60)
            .length,
        'full_result_screen_measured': false,
      },
      'process_rss_bytes_at_end': ProcessInfo.currentRss,
      'network_requested': false,
      'ordinary_database_opened': false,
    };
    await _reportChannel.invokeMethod<void>('finished', report);
    if (mounted) {
      setState(() {
        status = 'Profile measurements saved — synthetic data only';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Traelyx performance QA')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(status),
          const SizedBox(height: 12),
          OfflineRouteMap(
            geometry: route,
            replayMarker: clock.snapshot.routeMarker?.coordinate,
            replayMarkerAfterPointIndex:
                clock.snapshot.routeMarker?.afterPointIndex,
            replayPosition: clock.snapshot.position,
            cameraFollow: 1,
          ),
          const SizedBox(height: 12),
          ReplayEvidenceTimeline(timeline: timeline, snapshot: clock.snapshot),
        ],
      ),
    ),
  );

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    ticker.dispose();
    clock.dispose();
    super.dispose();
  }
}
