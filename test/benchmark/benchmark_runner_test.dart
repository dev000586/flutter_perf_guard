import 'dart:math' as math;

import 'package:flutter_perf_guard/src/benchmark/benchmark_result.dart';
import 'package:flutter_perf_guard/src/benchmark/benchmark_suite.dart';
import 'package:flutter_perf_guard/src/public_api/benchmark_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BenchmarkRunner suite execution', () {
    const runner = BenchmarkRunner(
      defaultWarmupRuns: 2,
      defaultMeasuredRuns: 5,
    );

    test('list sort benchmark produces valid stats', () async {
      final suite = BenchmarkSuite(name: 'ListPerf')
        ..add('sort_100', () {
          final list = List.generate(100, (i) => 100 - i);
          list.sort();
        })
        ..add('sort_1000', () {
          final list = List.generate(1000, (i) => 1000 - i);
          list.sort();
        });

      final results = await runner.run(suite);

      expect(results.length, equals(2));

      // sort_1000 should be slower than sort_100
      expect(
        results[1].mean.inMicroseconds,
        greaterThan(results[0].mean.inMicroseconds),
      );

      // Both within 100ms (reasonable for small lists)
      for (final r in results) {
        expect(r.mean, lessThan(const Duration(milliseconds: 100)));
        expect(r.p99, greaterThanOrEqualTo(r.mean));
        expect(r.min.inMicroseconds, lessThanOrEqualTo(r.mean.inMicroseconds));
        expect(r.max.inMicroseconds, greaterThanOrEqualTo(r.mean.inMicroseconds));
      }
    });

    test('string concatenation benchmark', () async {
      final suite = BenchmarkSuite(name: 'StringPerf')
        ..add('concat_10', () {
          var s = '';
          for (int i = 0; i < 10; i++) {
            s += 'x';
          }
          blackHole(s);
        })
        ..add('buffer_10', () {
          final buf = StringBuffer();
          for (int i = 0; i < 10; i++) {
            buf.write('x');
          }
          blackHole(buf.toString());
        });

      final results = await runner.run(suite);
      expect(results.length, equals(2));
      // Both should complete in < 1ms
      for (final r in results) {
        expect(r.mean, lessThan(const Duration(milliseconds: 1)));
      }
    });

    test('async benchmarks measure wait time', () async {
      const delayMicros = 1000; // 1ms
      final suite = BenchmarkSuite(name: 'AsyncPerf')
        ..addAsync('delay_1ms', () async {
          await Future.delayed(const Duration(microseconds: delayMicros));
        });

      final results = await runner.run(
        suite,
        warmupRuns: 1,
        measuredRuns: 5,
      );

      expect(results.first.mean.inMicroseconds, greaterThanOrEqualTo(delayMicros));
    });

    test('mathematical computation benchmark', () async {
      final suite = BenchmarkSuite(name: 'MathPerf')
        ..add('sqrt_loop_1k', () {
          double acc = 0;
          for (int i = 1; i <= 1000; i++) {
            acc += math.sqrt(i.toDouble());
          }
          blackHole(acc);
        })
        ..add('sin_loop_1k', () {
          double acc = 0;
          for (int i = 0; i < 1000; i++) {
            acc += math.sin(i.toDouble());
          }
          blackHole(acc);
        });

      final results = await runner.run(suite);

      for (final r in results) {
        // Stats should be internally consistent
        expect(r.min.inMicroseconds, lessThanOrEqualTo(r.mean.inMicroseconds));
        expect(r.mean.inMicroseconds, lessThanOrEqualTo(r.max.inMicroseconds));
        expect(r.median.inMicroseconds, lessThanOrEqualTo(r.p95.inMicroseconds));
        expect(r.p95.inMicroseconds, lessThanOrEqualTo(r.p99.inMicroseconds));
        expect(r.stdDevMicros, greaterThanOrEqualTo(0.0));
        expect(r.opsPerSecond, greaterThan(0.0));
      }
    });

    test('runAll produces results for all suites', () async {
      final suiteA = BenchmarkSuite(name: 'SuiteA')
        ..add('a1', () {})
        ..add('a2', () {});
      final suiteB = BenchmarkSuite(name: 'SuiteB')
        ..add('b1', () {});

      final allResults = await runner.runAll([suiteA, suiteB]);

      expect(allResults.keys, containsAll(['SuiteA', 'SuiteB']));
      expect(allResults['SuiteA']!.length, equals(2));
      expect(allResults['SuiteB']!.length, equals(1));
    });

    test('custom warmup and measured runs are respected', () async {
      final suite = BenchmarkSuite(name: 'CustomRuns')
        ..add('noop', () {});

      final results = await runner.run(
        suite,
        warmupRuns: 1,
        measuredRuns: 7,
      );

      expect(results.first.durations.length, equals(7));
    });

    test('toJson contains all required keys', () async {
      final suite = BenchmarkSuite(name: 'JsonTest')
        ..add('work', () {
          var x = 0;
          for (int i = 0; i < 100; i++) {
            x += i;
          }
          blackHole(x);
        });

      final results = await runner.run(suite, warmupRuns: 1, measuredRuns: 3);
      final json = results.first.toJson();

      expect(json, containsPair('suite', 'JsonTest'));
      expect(json, containsPair('name', 'work'));
      expect(json['runs'], equals(3));
      expect(json['meanMs'], isA<double>());
      expect(json['p99Ms'], isA<double>());
      expect(json['opsPerSecond'], isA<double>());
    });
  });

  group('BenchmarkResult edge cases', () {
    test('single run produces valid stats', () {
      final result = BenchmarkResult.fromDurations(
        suite: 'edge',
        name: 'single',
        durations: [const Duration(milliseconds: 5)],
      );
      expect(result.mean.inMilliseconds, equals(5));
      expect(result.min.inMilliseconds, equals(5));
      expect(result.max.inMilliseconds, equals(5));
      expect(result.median.inMilliseconds, equals(5));
      expect(result.stdDevMicros, closeTo(0.0, 0.001));
    });

    test('two runs produce correct median', () {
      final result = BenchmarkResult.fromDurations(
        suite: 'edge',
        name: 'two',
        durations: [
          const Duration(milliseconds: 2),
          const Duration(milliseconds: 8),
        ],
      );
      // Mean = 5ms
      expect(result.mean.inMilliseconds, equals(5));
      // Median = one of the two values
      expect(
        [2, 8],
        contains(result.median.inMilliseconds),
      );
    });

    test('high-variance data has non-zero stddev', () {
      final result = BenchmarkResult.fromDurations(
        suite: 'edge',
        name: 'variance',
        durations: [
          const Duration(microseconds: 100),
          const Duration(milliseconds: 100),
        ],
      );
      expect(result.stdDevMicros, greaterThan(0.0));
    });
  });
}

// Prevent dead-code elimination
/// Prevents dead-code elimination by passing [value] through a trivial
/// computation the compiler cannot statically predict.
@pragma('vm:never-inline')
void blackHole(dynamic value) {
  // The pragma prevents inlining, making the value "observable" to the
  // compiler. The body is intentionally empty.
}
