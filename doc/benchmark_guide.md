# Benchmark Guide

## Overview

`flutter_perf_guard` includes a runtime benchmark engine (`BenchmarkRunner`)
for measuring the performance of Dart code, widget builds, async operations,
and algorithms with statistical rigor.

---

## Quick Start

```dart
import 'package:flutter_perf_guard/flutter_perf_guard.dart';

final suite = BenchmarkSuite(name: 'CoreAlgorithms')
  ..add('list_sort_1k', () {
    final list = List.generate(1000, (i) => 1000 - i);
    list.sort();
  })
  ..add('json_encode', () {
    jsonEncode({'key': 'value', 'count': 42});
  })
  ..addAsync('future_value', () async {
    await Future.value(42);
  });

const runner = BenchmarkRunner(
  defaultWarmupRuns: 5,    // warmup before measuring
  defaultMeasuredRuns: 20, // measured iterations
);

final results = await runner.run(suite);

for (final r in results) {
  print('${r.suite}/${r.name}');
  print('  mean:   ${(r.mean.inMicroseconds / 1000).toStringAsFixed(3)}ms');
  print('  median: ${(r.median.inMicroseconds / 1000).toStringAsFixed(3)}ms');
  print('  p95:    ${(r.p95.inMicroseconds / 1000).toStringAsFixed(3)}ms');
  print('  p99:    ${(r.p99.inMicroseconds / 1000).toStringAsFixed(3)}ms');
  print('  stddev: ${r.stdDevMicros.toStringAsFixed(1)}µs');
  print('  ops/s:  ${r.opsPerSecond.toStringAsFixed(0)}');
}
```

---

## BenchmarkSuite API

```dart
final suite = BenchmarkSuite(
  name: 'MyBenchmarks',
  description: 'Optional suite description',
);

// Synchronous benchmark
suite.add('name', () {
  // work to measure
});

// Asynchronous benchmark
suite.addAsync('async_name', () async {
  await someAsyncOperation();
});
```

---

## BenchmarkRunner API

```dart
const runner = BenchmarkRunner(
  defaultWarmupRuns: 3,     // runs before measurement (discarded)
  defaultMeasuredRuns: 10,  // runs used for statistics
);

// Run a single suite
final results = await runner.run(suite);

// Override runs per suite
final results = await runner.run(
  suite,
  warmupRuns: 10,
  measuredRuns: 50,
);

// Run multiple suites
final allResults = await runner.runAll([suiteA, suiteB, suiteC]);
// Returns Map<String, List<BenchmarkResult>>
```

---

## BenchmarkResult Statistics

| Field | Type | Description |
|-------|------|-------------|
| `mean` | `Duration` | Arithmetic mean of all measured runs |
| `median` | `Duration` | 50th percentile |
| `p95` | `Duration` | 95th percentile (tail latency) |
| `p99` | `Duration` | 99th percentile |
| `min` | `Duration` | Fastest run |
| `max` | `Duration` | Slowest run |
| `stdDevMicros` | `double` | Standard deviation in microseconds |
| `opsPerSecond` | `double` | 1,000,000 / mean.inMicroseconds |
| `durations` | `List<Duration>` | Raw measured durations |

```dart
// Example: detect high variance (unstable benchmark)
if (result.stdDevMicros > result.mean.inMicroseconds * 0.1) {
  print('Warning: high variance (${result.stdDevMicros.toStringAsFixed(0)}µs stddev) '
        '– results may be noisy');
}

// Example: compare two implementations
final ratio = resultB.mean.inMicroseconds / resultA.mean.inMicroseconds;
print('B is ${ratio.toStringAsFixed(2)}x ${ratio < 1 ? "faster" : "slower"} than A');
```

---

## Widget Build Benchmarks

To benchmark widget builds, use `tester.runAsync` in widget tests:

```dart
testWidgets('ListView.builder build time', (tester) async {
  final suite = BenchmarkSuite(name: 'Widgets')
    ..addAsync('listview_builder_100', () async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            itemCount: 100,
            itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
          ),
        ),
      );
      await tester.pump();
    });

  const runner = BenchmarkRunner(
    defaultWarmupRuns: 2,
    defaultMeasuredRuns: 10,
  );
  final results = await runner.run(suite);
  expect(results.first.mean, lessThan(const Duration(milliseconds: 16)));
});
```

---

## Benchmark Best Practices

### 1. Always warm up
The Dart JIT compiler optimizes hot code paths after repeated execution.
Use at least 3–5 warmup runs to reach steady-state performance.

```dart
const runner = BenchmarkRunner(
  defaultWarmupRuns: 5,   // ← don't skip warmup
  defaultMeasuredRuns: 20,
);
```

### 2. Use profile mode for realistic results
```bash
flutter test --profile test/benchmark/my_benchmark_test.dart
```

### 3. Prevent dead-code elimination
The compiler may optimize away work with no observable side effects:

```dart
// ❌ May be eliminated
suite.add('compute', () {
  var sum = 0;
  for (int i = 0; i < 1000; i++) sum += i;
  // sum is never used → optimizer may remove the loop
});

// ✅ Force use of result
int? _sink;
suite.add('compute', () {
  var sum = 0;
  for (int i = 0; i < 1000; i++) sum += i;
  _sink = sum;  // prevents elimination
});
```

### 4. Isolate the unit under test
Each benchmark should measure exactly one thing:

```dart
// ❌ Mixed concerns
suite.add('full_pipeline', () {
  final data = generateData();   // not what we're measuring
  processData(data);
  renderResult(data);
});

// ✅ Isolated
final testData = generateData();  // prepared outside benchmark
suite.add('process_only', () {
  processData(testData);
});
```

### 5. Use meaningful iteration counts
Too few runs → high variance. Use `p95` and `stdDevMicros` to assess stability.

---

## Regression Testing with Benchmarks

```dart
void main() {
  test('processData under 2ms (p99)', () async {
    final suite = BenchmarkSuite(name: 'Regression')
      ..add('processData', () => processData(testFixture));

    const runner = BenchmarkRunner(
      defaultWarmupRuns: 5,
      defaultMeasuredRuns: 20,
    );
    final results = await runner.run(suite);
    final result = results.first;

    // Assert performance budget
    expect(
      result.p99,
      lessThan(const Duration(milliseconds: 2)),
      reason: 'p99 exceeded 2ms budget: ${result.p99.inMicroseconds}µs',
    );
  });
}
```

---

## Exporting Benchmark Results

```dart
final results = await runner.runAll(suites);
final json = {
  'timestamp': DateTime.now().toIso8601String(),
  'platform': Platform.operatingSystem,
  'results': results.entries.expand((e) => e.value).map((r) => r.toJson()).toList(),
};
final file = File('benchmark_results.json');
await file.writeAsString(const JsonEncoder.withIndent('  ').convert(json));
```

---

## Interpreting Results

| p99 vs mean ratio | Interpretation |
|---|---|
| < 1.5× | Stable, low variance |
| 1.5× – 3× | Moderate variance, possible GC pauses |
| 3× – 10× | High variance, investigate outliers |
| > 10× | Unstable – check for I/O, locks, or large allocations |

A high `stdDevMicros` relative to `mean` indicates the benchmark environment
is noisy. Run on a quiet device with no other apps, and consider using
`flutter run --profile` instead of `flutter test` for accurate timings.
