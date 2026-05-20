import 'package:flutter_perf_guard/src/profiling/memory/memory_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryMetrics', () {
    late MemoryMetrics normalMetrics;
    late MemoryMetrics highUsageMetrics;

    setUp(() {
      normalMetrics = MemoryMetrics(
        heapUsedBytes: 50 * 1024 * 1024, // 50 MB
        heapCapacityBytes: 200 * 1024 * 1024, // 200 MB
        externalBytes: 10 * 1024 * 1024,
        rssBytes: 80 * 1024 * 1024,
        gcCount: 2,
        timestamp: DateTime(2024),
      );

      highUsageMetrics = MemoryMetrics(
        heapUsedBytes: 180 * 1024 * 1024, // 180 MB
        heapCapacityBytes: 200 * 1024 * 1024, // 200 MB
        externalBytes: 5 * 1024 * 1024,
        rssBytes: 300 * 1024 * 1024,
        gcCount: 10,
        timestamp: DateTime(2024),
      );
    });

    group('heapUsagePercent', () {
      test('calculates correct percentage for normal usage', () {
        expect(normalMetrics.heapUsagePercent, closeTo(0.25, 0.001));
      });

      test('calculates correct percentage for high usage', () {
        expect(highUsageMetrics.heapUsagePercent, closeTo(0.90, 0.001));
      });

      test('returns 0 when capacity is zero', () {
        final zeroCapacity = MemoryMetrics(
          heapUsedBytes: 100,
          heapCapacityBytes: 0,
          externalBytes: 0,
          rssBytes: 0,
          gcCount: 0,
          timestamp: DateTime(2024),
        );
        expect(zeroCapacity.heapUsagePercent, equals(0.0));
      });
    });

    group('human-readable conversions', () {
      test('heapUsedMb is correct', () {
        expect(normalMetrics.heapUsedMb, closeTo(50.0, 0.1));
      });

      test('heapCapacityMb is correct', () {
        expect(normalMetrics.heapCapacityMb, closeTo(200.0, 0.1));
      });

      test('externalMb is correct', () {
        expect(normalMetrics.externalMb, closeTo(10.0, 0.1));
      });

      test('rssMb is correct', () {
        expect(normalMetrics.rssMb, closeTo(80.0, 0.1));
      });
    });

    group('toJson', () {
      test('contains all required keys', () {
        final json = normalMetrics.toJson();
        expect(json.keys, containsAll([
          'heapUsedBytes', 'heapCapacityBytes', 'externalBytes',
          'rssBytes', 'gcCount', 'timestamp', 'heapUsagePercent',
          'heapUsedMb', 'rssMb',
        ]));
      });

      test('heapUsagePercent in json is correct', () {
        final json = normalMetrics.toJson();
        expect(json['heapUsagePercent'], closeTo(0.25, 0.001));
      });
    });

    group('copyWith', () {
      test('creates modified copy preserving unchanged fields', () {
        final copy = normalMetrics.copyWith(heapUsedBytes: 100 * 1024 * 1024);
        expect(copy.heapUsedMb, closeTo(100.0, 0.1));
        expect(copy.heapCapacityBytes, equals(normalMetrics.heapCapacityBytes));
        expect(copy.gcCount, equals(normalMetrics.gcCount));
      });
    });

    group('equality', () {
      test('same data yields equal metrics', () {
        final copy = normalMetrics.copyWith();
        expect(normalMetrics, equals(copy));
      });

      test('different data yields unequal metrics', () {
        expect(normalMetrics, isNot(equals(highUsageMetrics)));
      });
    });

    group('toString', () {
      test('contains heap and rss info', () {
        final str = normalMetrics.toString();
        expect(str, contains('50.0MB'));
        expect(str, contains('200.0MB'));
      });
    });
  });
}
