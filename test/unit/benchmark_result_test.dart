import 'package:flutter_perf_guard/src/benchmark/benchmark_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BenchmarkResult', () {
    List<Duration> buildDurations(List<int> micros) =>
        micros.map((m) => Duration(microseconds: m)).toList();

    group('fromDurations - statistics', () {
      test('calculates correct mean', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'mean_test',
          durations: buildDurations([1000, 2000, 3000, 4000]),
        );
        expect(result.mean.inMicroseconds, equals(2500));
      });

      test('calculates correct median (odd count)', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'median_test',
          durations: buildDurations([1000, 2000, 3000]),
        );
        expect(result.median.inMicroseconds, equals(2000));
      });

      test('calculates correct min and max', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'minmax_test',
          durations: buildDurations([5000, 1000, 3000, 9000, 2000]),
        );
        expect(result.min.inMicroseconds, equals(1000));
        expect(result.max.inMicroseconds, equals(9000));
      });

      test('p95 is >= median', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'p95_test',
          durations:
              buildDurations(List.generate(100, (i) => (i + 1) * 100)),
        );
        expect(
            result.p95.inMicroseconds, greaterThanOrEqualTo(result.median.inMicroseconds));
      });

      test('p99 is >= p95', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'p99_test',
          durations:
              buildDurations(List.generate(100, (i) => (i + 1) * 100)),
        );
        expect(
            result.p99.inMicroseconds, greaterThanOrEqualTo(result.p95.inMicroseconds));
      });

      test('single duration result', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'single',
          durations: buildDurations([5000]),
        );
        expect(result.mean.inMicroseconds, equals(5000));
        expect(result.min.inMicroseconds, equals(5000));
        expect(result.max.inMicroseconds, equals(5000));
      });
    });

    group('opsPerSecond', () {
      test('calculates ops/s from mean', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'ops',
          durations: buildDurations([1000000]), // 1 second
        );
        expect(result.opsPerSecond, closeTo(1.0, 0.01));
      });

      test('calculates 1000 ops/s for 1ms mean', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'ops_ms',
          durations: buildDurations([1000]), // 1 ms
        );
        expect(result.opsPerSecond, closeTo(1000.0, 1.0));
      });
    });

    group('toJson', () {
      test('contains all required keys', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'suite',
          name: 'bench',
          durations: buildDurations([1000, 2000, 3000]),
        );
        final json = result.toJson();
        expect(json.keys, containsAll([
          'suite', 'name', 'runs', 'meanMs', 'medianMs',
          'p95Ms', 'p99Ms', 'minMs', 'maxMs', 'stdDevMicros',
          'opsPerSecond', 'runAt',
        ]));
      });

      test('suite and name are correct', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'MySuite',
          name: 'myBench',
          durations: buildDurations([1000]),
        );
        expect(result.toJson()['suite'], equals('MySuite'));
        expect(result.toJson()['name'], equals('myBench'));
      });
    });

    group('stdDev', () {
      test('stdDev is 0 for uniform durations', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'uniform',
          durations: buildDurations([1000, 1000, 1000, 1000]),
        );
        expect(result.stdDevMicros, closeTo(0.0, 0.001));
      });

      test('stdDev is positive for varied durations', () {
        final result = BenchmarkResult.fromDurations(
          suite: 'test',
          name: 'varied',
          durations: buildDurations([1000, 5000, 1000, 5000]),
        );
        expect(result.stdDevMicros, greaterThan(0.0));
      });
    });
  });
}
