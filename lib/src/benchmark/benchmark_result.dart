import 'dart:math' as math;

/// Statistical result for a single benchmark run.
class BenchmarkResult {
  final String suite;
  final String name;
  final List<Duration> durations;
  final Duration mean;
  final Duration median;
  final Duration p95;
  final Duration p99;
  final Duration min;
  final Duration max;
  final double stdDevMicros;
  final DateTime runAt;

  const BenchmarkResult({
    required this.suite,
    required this.name,
    required this.durations,
    required this.mean,
    required this.median,
    required this.p95,
    required this.p99,
    required this.min,
    required this.max,
    required this.stdDevMicros,
    required this.runAt,
  });

  factory BenchmarkResult.fromDurations({
    required String suite,
    required String name,
    required List<Duration> durations,
  }) {
    assert(durations.isNotEmpty, 'durations must not be empty');
    final sorted = [...durations]
      ..sort((a, b) => a.inMicroseconds.compareTo(b.inMicroseconds));

    final totalMicros =
        sorted.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
    final meanMicros = totalMicros ~/ sorted.length;

    final meanD = Duration(microseconds: meanMicros);
    final variance = sorted.fold<double>(
          0.0,
          (sum, d) =>
              sum +
              math.pow(d.inMicroseconds - meanMicros, 2).toDouble(),
        ) /
        sorted.length;

    return BenchmarkResult(
      suite: suite,
      name: name,
      durations: durations,
      mean: meanD,
      median: _percentile(sorted, 0.50),
      p95: _percentile(sorted, 0.95),
      p99: _percentile(sorted, 0.99),
      min: sorted.first,
      max: sorted.last,
      stdDevMicros: math.sqrt(variance),
      runAt: DateTime.now(),
    );
  }

  static Duration _percentile(List<Duration> sorted, double p) {
    final idx = ((sorted.length - 1) * p).round();
    return sorted[idx.clamp(0, sorted.length - 1)];
  }

  /// Iterations per second based on the mean duration.
  double get opsPerSecond =>
      mean.inMicroseconds > 0 ? 1000000.0 / mean.inMicroseconds : 0.0;

  Map<String, dynamic> toJson() => {
        'suite': suite,
        'name': name,
        'runs': durations.length,
        'meanMs': mean.inMicroseconds / 1000,
        'medianMs': median.inMicroseconds / 1000,
        'p95Ms': p95.inMicroseconds / 1000,
        'p99Ms': p99.inMicroseconds / 1000,
        'minMs': min.inMicroseconds / 1000,
        'maxMs': max.inMicroseconds / 1000,
        'stdDevMicros': stdDevMicros,
        'opsPerSecond': opsPerSecond,
        'runAt': runAt.toIso8601String(),
      };

  @override
  String toString() =>
      'BenchmarkResult[$suite/$name] mean=${mean.inMicroseconds / 1000}ms '
      'p95=${p95.inMicroseconds / 1000}ms ops/s=${opsPerSecond.toStringAsFixed(0)}';
}
