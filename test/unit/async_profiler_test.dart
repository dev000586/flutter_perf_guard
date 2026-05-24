import 'package:flutter_perf_guard/src/core/bus/diagnostics_event_bus.dart';
import 'package:flutter_perf_guard/src/monitoring/async/async_profiler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bus = DiagnosticsEventBus.instance;

  group('AsyncOperationRecord', () {
    test('toJson contains all required keys', () {
      final record = AsyncOperationRecord(
        name: 'fetch_data',
        duration: const Duration(milliseconds: 300),
        timestamp: DateTime.now(),
      );
      final json = record.toJson();
      expect(json.keys,
          containsAll(['name', 'durationMs', 'timestamp']));
    });

    test('toJson includes error when set', () {
      final record = AsyncOperationRecord(
        name: 'failing_op',
        duration: const Duration(milliseconds: 100),
        timestamp: DateTime.now(),
        error: 'Connection refused',
      );
      expect(record.toJson()['error'], equals('Connection refused'));
    });

    test('toJson omits error when null', () {
      final record = AsyncOperationRecord(
        name: 'ok_op',
        duration: const Duration(milliseconds: 100),
        timestamp: DateTime.now(),
      );
      expect(record.toJson().containsKey('error'), isFalse);
    });
  });

  group('AsyncProfiler', () {
    late AsyncProfiler profiler;

    setUp(() {
      profiler = AsyncProfiler(
        bus: bus,
        slowThreshold: const Duration(milliseconds: 200),
      );
    });

    tearDown(() => profiler.reset());

    group('track()', () {
      test('records successful async operation', () async {
        await profiler.track('test_op', () async {
          await Future.delayed(const Duration(milliseconds: 10));
        });
        expect(profiler.records.length, equals(1));
        expect(profiler.records.first.name, equals('test_op'));
        expect(profiler.records.first.error, isNull);
      });

      test('records duration correctly', () async {
        await profiler.track('timed_op', () async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        expect(profiler.records.first.duration.inMilliseconds,
            greaterThanOrEqualTo(50));
      });

      test('records error and rethrows', () async {
        expect(
              () => profiler.track('failing_op', () async {
            throw Exception('test error');
          }),
          throwsException,
        );
        await Future.delayed(Duration.zero);
        expect(profiler.records.length, equals(1));
        expect(profiler.records.first.error, isNotNull);
        expect(profiler.records.first.error, contains('test error'));
      });

      test('returns value from operation', () async {
        final result = await profiler.track('value_op', () async => 42);
        expect(result, equals(42));
      });
    });

    group('trackSync()', () {
      test('records synchronous operation', () {
        profiler.trackSync('sync_op', () => 'result');
        expect(profiler.records.length, equals(1));
        expect(profiler.records.first.name, equals('sync_op'));
      });

      test('records sync error and rethrows', () {
        expect(
              () => profiler.trackSync('failing_sync', () {
            throw Exception('sync error');
          }),
          throwsException,
        );
        expect(profiler.records.first.error, isNotNull);
      });

      test('returns value from sync operation', () {
        final result = profiler.trackSync('sync_value', () => 99);
        expect(result, equals(99));
      });
    });

    group('slowOperations', () {
      test('flags operations exceeding slowThreshold', () async {
        await profiler.track('fast', () async {
          await Future.delayed(const Duration(milliseconds: 10));
        });
        await profiler.track('slow', () async {
          await Future.delayed(const Duration(milliseconds: 300));
        });
        expect(profiler.slowOperations.length, equals(1));
        expect(profiler.slowOperations.first.name, equals('slow'));
      });

      test('does not flag operations under threshold', () async {
        await profiler.track('ok', () async {
          await Future.delayed(const Duration(milliseconds: 50));
        });
        expect(profiler.slowOperations, isEmpty);
      });
    });

    group('failedOperations', () {
      test('includes operations with errors', () async {
        try {
          await profiler.track('bad', () async {
            throw Exception('fail');
          });
        } catch (_) {}
        expect(profiler.failedOperations.length, equals(1));
        expect(profiler.failedOperations.first.name, equals('bad'));
      });
    });

    group('plainEnglishSummary', () {
      test('shows positive message when no operations', () {
        expect(profiler.plainEnglishSummary, contains('✅'));
      });

      test('shows positive when all operations are fast and successful',
              () async {
            await profiler.track('fast', () async {
              await Future.delayed(const Duration(milliseconds: 10));
            });
            expect(profiler.plainEnglishSummary, contains('✅'));
          });

      test('flags slow operations', () async {
        await profiler.track('slow_one', () async {
          await Future.delayed(const Duration(milliseconds: 300));
        });
        expect(profiler.plainEnglishSummary, contains('⚠'));
        expect(profiler.plainEnglishSummary, contains('slow_one'));
      });

      test('flags failed operations', () async {
        try {
          await profiler.track('broken', () async {
            throw Exception('broken');
          });
        } catch (_) {}
        expect(profiler.plainEnglishSummary, contains('❌'));
      });
    });

    group('reset()', () {
      test('clears all records', () async {
        await profiler.track('op', () async {});
        profiler.reset();
        expect(profiler.records, isEmpty);
      });
    });

    group('toJson()', () {
      test('returns zero count when empty', () {
        final json = profiler.toJson();
        expect(json['totalOperations'], equals(0));
      });

      test('includes stats when records exist', () async {
        await profiler.track('op1', () async {
          await Future.delayed(const Duration(milliseconds: 10));
        });
        final json = profiler.toJson();
        expect(json['totalOperations'], equals(1));
        expect(json.containsKey('averageDurationMs'), isTrue);
        expect(json.containsKey('operations'), isTrue);
      });
    });

    test('records capped at 500', () async {
      for (int i = 0; i < 600; i++) {
        profiler.trackSync('op_$i', () => i);
      }
      expect(profiler.records.length, equals(500));
    });
  });
}