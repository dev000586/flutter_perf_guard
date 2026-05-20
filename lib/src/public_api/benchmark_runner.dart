import 'dart:async';

import '../benchmark/benchmark_result.dart';
import '../benchmark/benchmark_suite.dart';

/// Executes [BenchmarkSuite]s and collects [BenchmarkResult]s.
///
/// Usage:
/// ```dart
/// final runner = BenchmarkRunner();
/// final suite = BenchmarkSuite(name: 'Rendering')
///   ..add('build_list', () { /* ... */ });
/// final results = await runner.run(suite);
/// ```
class BenchmarkRunner {
  final int defaultWarmupRuns;
  final int defaultMeasuredRuns;

  const BenchmarkRunner({
    this.defaultWarmupRuns = 3,
    this.defaultMeasuredRuns = 10,
  });

  /// Runs a single [BenchmarkSuite] and returns all results.
  Future<List<BenchmarkResult>> run(
    BenchmarkSuite suite, {
    int? warmupRuns,
    int? measuredRuns,
  }) async {
    final warmup = warmupRuns ?? defaultWarmupRuns;
    final measured = measuredRuns ?? defaultMeasuredRuns;
    final results = <BenchmarkResult>[];

    for (final benchmark in suite.benchmarks) {
      final result = await _runBenchmark(
        suite: suite.name,
        benchmark: benchmark,
        warmup: warmup,
        measured: measured,
      );
      results.add(result);
    }
    return results;
  }

  /// Runs multiple suites sequentially.
  Future<Map<String, List<BenchmarkResult>>> runAll(
    List<BenchmarkSuite> suites,
  ) async {
    final results = <String, List<BenchmarkResult>>{};
    for (final suite in suites) {
      results[suite.name] = await run(suite);
    }
    return results;
  }

  Future<BenchmarkResult> _runBenchmark({
    required String suite,
    required BenchmarkEntry benchmark,
    required int warmup,
    required int measured,
  }) async {
    // Warmup phase
    for (int i = 0; i < warmup; i++) {
      await _execute(benchmark);
    }

    // Measured phase
    final durations = <Duration>[];
    for (int i = 0; i < measured; i++) {
      final sw = Stopwatch()..start();
      await _execute(benchmark);
      sw.stop();
      durations.add(sw.elapsed);
    }

    return BenchmarkResult.fromDurations(
      suite: suite,
      name: benchmark.name,
      durations: durations,
    );
  }

  Future<void> _execute(BenchmarkEntry benchmark) async {
    if (benchmark.isAsync) {
      await benchmark.asyncBody!();
    } else {
      benchmark.body!();
    }
  }
}
