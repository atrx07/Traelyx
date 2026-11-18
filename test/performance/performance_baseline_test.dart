import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/performance_workload.dart';

void main() {
  test('nearest-rank quantiles preserve outliers and reject invalid input', () {
    expect(timingDistribution([3, 1, 2, 40]), {
      'count': 4,
      'p50_ms': 2.0,
      'p95_ms': 40.0,
      'p99_ms': 40.0,
      'max_ms': 40.0,
    });
    expect(() => timingDistribution([]), throwsArgumentError);
    expect(() => timingDistribution([double.nan]), throwsArgumentError);
    expect(() => timingDistribution([-1]), throwsArgumentError);
  });

  test('synthetic replay keeps governed segment gaps and bounded events', () {
    final route = performanceRoute();
    final timeline = performanceTimeline(route);
    expect(route.points, hasLength(1000));
    expect(route.segmentCount, 2);
    expect(timeline.events, hasLength(50));
    expect(timeline.discardedEventCount, 0);
    expect(
      timeline.at(const Duration(milliseconds: 1798200)).routeMarker,
      isNull,
    );
    expect(timeline.at(Duration.zero).routeMarker, isNotNull);
  });

  test(
    'file-backed 1000-trip workload verifies complete production queries',
    () async {
      final root = Directory('.dart_tool')..createSync(recursive: true);
      final temporary = root.createTempSync('m8-performance-');
      try {
        final report = await benchmarkDatabase(
          NativeDatabase(File('${temporary.path}/synthetic.sqlite')),
        );
        expect(report['trip_count'], 1000);
        expect(report['selected_trip_chunk_count'], 3600);
        expect(report['database_allocated_bytes'], greaterThan(0));
        final output = File('build/reports/host-performance-v1.json');
        output.parent.createSync(recursive: true);
        output.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({'contract_version': 1, 'platform': Platform.operatingSystem, 'mode': 'Flutter test host JIT; not Android performance acceptance', 'database': report})}\n',
        );
      } finally {
        if (temporary.parent.resolveSymbolicLinksSync() !=
            root.resolveSymbolicLinksSync()) {
          throw StateError('Unexpected fixture cleanup target.');
        }
        temporary.deleteSync(recursive: true);
      }
    },
  );
}
