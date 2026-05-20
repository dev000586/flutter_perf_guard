import 'package:flutter_perf_guard/src/benchmark/benchmark_result.dart';
import 'package:flutter_perf_guard/src/benchmark/benchmark_suite.dart';
import 'package:flutter_perf_guard/src/core/bus/diagnostics_event_bus.dart';
import 'package:flutter_perf_guard/src/core/events/performance_event.dart';
import 'package:flutter_perf_guard/src/public_api/benchmark_runner.dart';
import 'package:flutter_perf_guard/src/public_api/timeline_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

class _StressEvent extends PerformanceEvent {
  const _StressEvent(String id)
      : super(
          id: id,
          timestamp: const _FixedTime(),
          source: 'stress',
        );

  @override
  Map<String, dynamic> toJson() => {'id': id};
}

class _FixedTime implements DateTime {
  const _FixedTime();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('Performance stress tests', () {
    group('DiagnosticsEventBus throughput', () {
      test('handles 10,000 events without dropping', () async {
        final bus = DiagnosticsEventBus.instance;
        final received = <PerformanceEvent>[];
        final sub = bus.allEvents.listen(received.add);

        const count = 10000;
        final sw = Stopwatch()..start();
        for (int i = 0; i < count; i++) {
          bus.emit(_StressEvent('evt_$i'));
        }
        await Future.delayed(const Duration(milliseconds: 100));
        sw.stop();

        // Should handle 10k events in under 500ms
        expect(sw.elapsedMilliseconds, lessThan(500));
        // All events must be received (no drops)
        expect(received.where((e) => e.source == 'stress').length,
            equals(count));

        await sub.cancel();
      });

      test('handles concurrent subscribers efficiently', () async {
        final bus = DiagnosticsEventBus.instance;
        final subs = <dynamic>[];
        final received = List.generate(5, (_) => <PerformanceEvent>[]);

        // 5 concurrent subscribers
        for (int i = 0; i < 5; i++) {
          final idx = i;
          subs.add(bus.allEvents.listen((e) {
            if (e.source == 'concurrent_stress') received[idx].add(e);
          }));
        }

        const count = 1000;
        for (int i = 0; i < count; i++) {
          bus.emit(const _ConcurrentEvent());
        }
        await Future.delayed(const Duration(milliseconds: 500));

        // All 5 subscribers should receive all events
        for (final list in received) {
          expect(list.length, equals(count));
        }

        for (final s in subs) {
          await s.cancel();
        }
      });
    });

    group('BenchmarkRunner', () {
      test('runs suite and returns correct number of results', () async {
        final suite = BenchmarkSuite(name: 'TestSuite')
          ..add('noop', () {})
          ..add('small_work', () {
            var sum = 0;
            for (int i = 0; i < 1000; i++) {
              sum += i;
            }
            blackHole(sum);
          });

        const runner = BenchmarkRunner(
          defaultWarmupRuns: 2,
          defaultMeasuredRuns: 5,
        );
        final results = await runner.run(suite);

        expect(results.length, equals(2));
        expect(results[0].name, equals('noop'));
        expect(results[1].name, equals('small_work'));
      });

      test('measured runs count is correct', () async {
        final suite = BenchmarkSuite(name: 'CountSuite')
          ..add('count', () {});

        const runner = BenchmarkRunner(
          defaultWarmupRuns: 3,
          defaultMeasuredRuns: 7,
        );

        // We'll verify via result.durations.length
        final results = await runner.run(suite);
        expect(results.first.durations.length, equals(7));
      });

      test('async benchmark runs correctly', () async {
        final suite = BenchmarkSuite(name: 'AsyncSuite')
          ..addAsync('async_noop', () async {
            await Future.delayed(const Duration(microseconds: 500));
          });

        const runner = BenchmarkRunner(
          defaultWarmupRuns: 1,
          defaultMeasuredRuns: 3,
        );
        final results = await runner.run(suite);
        expect(results.first.durations.length, equals(3));
        // Each async op takes at least 100µs
        expect(
          results.first.mean.inMicroseconds,
          greaterThanOrEqualTo(100),
        );
      });
    });

    group('TimelineRecorder', () {
      test('records events and exports valid JSON', () async {
        final bus = DiagnosticsEventBus.instance;
        final recorder = TimelineRecorder(bus: bus);
        recorder.start(maxEntries: 500);

        for (int i = 0; i < 100; i++) {
          bus.emit(_StressEvent('tl_$i'));
        }
        await Future.delayed(const Duration(milliseconds: 50));
        recorder.stop();

        final json = recorder.exportJson();
        expect(json, isNotEmpty);
        expect(json, contains('"entryCount"'));
      });

      test('respects maxEntries circular buffer', () async {
        final bus = DiagnosticsEventBus.instance;
        final recorder = TimelineRecorder(bus: bus, maxEntries: 10);
        recorder.start();

        for (int i = 0; i < 50; i++) {
          bus.emit(_StressEvent('buf_$i'));
        }
        await Future.delayed(const Duration(milliseconds: 50));
        recorder.stop();

        expect(recorder.entryCount, lessThanOrEqualTo(10));
      });
    });

    group('BenchmarkResult statistics correctness', () {
      test('uniform 1ms runs give correct mean/stddev', () {
        final result = BenchmarkResult.fromDurations(
          suite: 's',
          name: 'n',
          durations: List.generate(
              100, (_) => const Duration(milliseconds: 1)),
        );
        expect(result.mean.inMicroseconds, equals(1000));
        expect(result.stdDevMicros, closeTo(0.0, 0.001));
      });

      test('p99 is within range', () {
        final result = BenchmarkResult.fromDurations(
          suite: 's',
          name: 'n',
          durations:
              List.generate(100, (i) => Duration(microseconds: i * 100 + 100)),
        );
        expect(result.p99.inMicroseconds,
            greaterThanOrEqualTo(result.p95.inMicroseconds));
        expect(result.p99.inMicroseconds,
            lessThanOrEqualTo(result.max.inMicroseconds));
      });
    });
  });
}

class _ConcurrentEvent extends PerformanceEvent {
  const _ConcurrentEvent()
      : super(
          id: 'c',
          timestamp: const _FixedTime2(),
          source: 'concurrent_stress',
        );

  @override
  Map<String, dynamic> toJson() => {};
}

class _FixedTime2 implements DateTime {
  const _FixedTime2();
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// Silence dart analyzer
@pragma('vm:never-inline')
void blackHole(dynamic value) {}
