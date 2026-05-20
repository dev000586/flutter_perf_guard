import 'package:flutter_perf_guard/src/profiling/rebuild/rebuild_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RebuildMetrics', () {
    late RebuildMetrics baseMetrics;
    final now = DateTime(2024, 1, 1, 12, 0, 0);

    setUp(() {
      baseMetrics = RebuildMetrics(
        widgetType: 'MyWidget',
        widgetKey: null,
        rebuildCount: 10,
        totalRebuildTime: const Duration(milliseconds: 50),
        averageRebuildTime: const Duration(milliseconds: 5),
        treeDepth: 3,
        hasRepaintBoundary: false,
        triggeredBySetState: true,
        firstSeen: now.subtract(const Duration(seconds: 1)),
        lastSeen: now,
      );
    });

    group('rebuildsPerSecond', () {
      test('calculates correct rate for 10 rebuilds in 1 second', () {
        expect(baseMetrics.rebuildsPerSecond, closeTo(10.0, 0.1));
      });

      test('returns 0 when firstSeen == lastSeen', () {
        final instant = RebuildMetrics(
          widgetType: 'W',
          rebuildCount: 5,
          totalRebuildTime: Duration.zero,
          averageRebuildTime: Duration.zero,
          treeDepth: 1,
          hasRepaintBoundary: false,
          triggeredBySetState: true,
          firstSeen: now,
          lastSeen: now,
        );
        expect(instant.rebuildsPerSecond, equals(0.0));
      });
    });

    group('isExcessive', () {
      test('is false for 10 rebuilds/s', () {
        expect(baseMetrics.isExcessive, isFalse);
      });

      test('is true for more than 60 rebuilds/s', () {
        final excessive = RebuildMetrics(
          widgetType: 'HotWidget',
          rebuildCount: 120,
          totalRebuildTime: const Duration(milliseconds: 120),
          averageRebuildTime: const Duration(milliseconds: 1),
          treeDepth: 2,
          hasRepaintBoundary: false,
          triggeredBySetState: true,
          firstSeen: now.subtract(const Duration(seconds: 1)),
          lastSeen: now,
        );
        expect(excessive.isExcessive, isTrue);
      });
    });

    group('increment', () {
      test('increments count and updates total', () {
        final incremented = baseMetrics.increment(
          rebuildTime: const Duration(milliseconds: 5),
          at: now.add(const Duration(milliseconds: 100)),
        );
        expect(incremented.rebuildCount, equals(11));
        expect(incremented.totalRebuildTime,
            equals(const Duration(milliseconds: 55)));
      });

      test('updates lastSeen', () {
        final newTime = now.add(const Duration(milliseconds: 100));
        final incremented = baseMetrics.increment(
          rebuildTime: const Duration(milliseconds: 5),
          at: newTime,
        );
        expect(incremented.lastSeen, equals(newTime));
      });

      test('preserves firstSeen', () {
        final incremented = baseMetrics.increment(
          rebuildTime: const Duration(milliseconds: 5),
          at: now.add(const Duration(milliseconds: 100)),
        );
        expect(incremented.firstSeen, equals(baseMetrics.firstSeen));
      });

      test('calculates correct average after increment', () {
        final incremented = baseMetrics.increment(
          rebuildTime: const Duration(milliseconds: 5),
          at: now.add(const Duration(milliseconds: 100)),
        );
        // 55ms total / 11 builds = 5ms average
        expect(
            incremented.averageRebuildTime.inMicroseconds,
            closeTo(5000, 100));
      });
    });

    group('toJson', () {
      test('contains all required keys', () {
        final json = baseMetrics.toJson();
        expect(json.keys, containsAll([
          'widgetType', 'rebuildCount', 'totalRebuildTimeMs',
          'averageRebuildTimeMs', 'treeDepth', 'hasRepaintBoundary',
          'triggeredBySetState', 'rebuildsPerSecond', 'isExcessive',
          'firstSeen', 'lastSeen',
        ]));
      });

      test('widgetKey is omitted when null', () {
        expect(baseMetrics.toJson().containsKey('widgetKey'), isFalse);
      });

      test('widgetKey is included when set', () {
        final withKey = RebuildMetrics(
          widgetType: 'W',
          widgetKey: 'my_key',
          rebuildCount: 1,
          totalRebuildTime: Duration.zero,
          averageRebuildTime: Duration.zero,
          treeDepth: 1,
          hasRepaintBoundary: false,
          triggeredBySetState: true,
          firstSeen: now,
          lastSeen: now,
        );
        expect(withKey.toJson()['widgetKey'], equals('my_key'));
      });
    });
  });
}
