import 'package:flutter_perf_guard/src/core/bus/diagnostics_event_bus.dart';
import 'package:flutter_perf_guard/src/core/events/jank_event.dart';
import 'package:flutter_perf_guard/src/core/events/memory_event.dart';
import 'package:flutter_perf_guard/src/core/events/performance_event.dart';
import 'package:flutter_perf_guard/src/profiling/memory/memory_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

// Concrete test event
class _TestEvent extends PerformanceEvent {
  const _TestEvent({
    required super.id,
    required super.timestamp,
    required super.source,
    super.severity,
  });

  @override
  Map<String, dynamic> toJson() =>
      {'id': id, 'source': source};
}

void main() {
  group('DiagnosticsEventBus', () {
    late DiagnosticsEventBus bus;

    setUp(() {
      // Use a fresh instance per test to avoid cross-test pollution
      bus = DiagnosticsEventBus.instance;
    });

    group('emit and allEvents', () {
      test('emitted event is received by allEvents subscriber', () async {
        final received = <PerformanceEvent>[];
        final sub = bus.allEvents.listen(received.add);

        final event = _TestEvent(
          id: 'test_1',
          timestamp: DateTime.now(),
          source: 'Test',
        );
        bus.emit(event);
        await Future.delayed(Duration.zero);

        expect(received, contains(event));
        await sub.cancel();
      });

      test('emitAll sends all events', () async {
        final received = <PerformanceEvent>[];
        final sub = bus.allEvents.listen(received.add);

        final events = List.generate(
          5,
          (i) => _TestEvent(
            id: 'test_$i',
            timestamp: DateTime.now(),
            source: 'Test',
          ),
        );
        bus.emitAll(events);
        await Future.delayed(Duration.zero);

        for (final e in events) {
          expect(received, contains(e));
        }
        await sub.cancel();
      });
    });

    group('typed streams', () {
      test('jankEvents only receives JankEvents', () async {
        final jankReceived = <JankEvent>[];
        final allReceived = <PerformanceEvent>[];

        final s1 = bus.jankEvents.listen(jankReceived.add);
        final s2 = bus.allEvents.listen(allReceived.add);

        // Emit a non-jank event
        bus.emit(_TestEvent(
          id: 'x',
          timestamp: DateTime.now(),
          source: 'test',
        ));

        // Emit a jank event
        final jank = JankEvent(
          id: 'jank_1',
          timestamp: DateTime.now(),
          source: 'FrameProfiler',
          consecutiveJankFrames: 3,
          worstFrameDuration: const Duration(milliseconds: 50),
          averageFrameDuration: const Duration(milliseconds: 30),
          droppedFrames: 2,
        );
        bus.emit(jank);
        await Future.delayed(Duration.zero);

        expect(jankReceived.length, equals(1));
        expect(jankReceived.first, equals(jank));
        expect(allReceived.length, equals(2));

        await s1.cancel();
        await s2.cancel();
      });

      test('memoryEvents only receives MemoryEvents', () async {
        final received = <MemoryEvent>[];
        final sub = bus.memoryEvents.listen(received.add);

        bus.emit(_TestEvent(
          id: 'x',
          timestamp: DateTime.now(),
          source: 'test',
        ));

        final memEvent = MemoryEvent.fromSample(
          id: 'mem_1',
          metrics: MemoryMetrics(
            heapUsedBytes: 10,
            heapCapacityBytes: 100,
            externalBytes: 0,
            rssBytes: 20,
            gcCount: 0,
            timestamp: DateTime.now(),
          ),
          allocationDelta: 10,
          leakSuspected: false,
        );
        bus.emit(memEvent);
        await Future.delayed(Duration.zero);

        expect(received.length, equals(1));
        expect(received.first, equals(memEvent));
        await sub.cancel();
      });
    });

    group('criticalEvents', () {
      test('only surfaces warning and critical severity events', () async {
        final received = <PerformanceEvent>[];
        final sub = bus.criticalEvents.listen(received.add);

        bus.emit(_TestEvent(
          id: 'info',
          timestamp: DateTime.now(),
          source: 'test',
          severity: EventSeverity.info,
        ));
        bus.emit(_TestEvent(
          id: 'warn',
          timestamp: DateTime.now(),
          source: 'test',
          severity: EventSeverity.warning,
        ));
        bus.emit(_TestEvent(
          id: 'crit',
          timestamp: DateTime.now(),
          source: 'test',
          severity: EventSeverity.critical,
        ));
        await Future.delayed(Duration.zero);

        expect(received.length, equals(2));
        expect(received.map((e) => e.id), containsAll(['warn', 'crit']));
        await sub.cancel();
      });
    });

    group('fromSource', () {
      test('filters events by source', () async {
        final received = <PerformanceEvent>[];
        final sub = bus.fromSource('FrameProfiler').listen(received.add);

        bus.emit(_TestEvent(
          id: '1',
          timestamp: DateTime.now(),
          source: 'MemoryProfiler',
        ));
        bus.emit(_TestEvent(
          id: '2',
          timestamp: DateTime.now(),
          source: 'FrameProfiler',
        ));
        await Future.delayed(Duration.zero);

        expect(received.length, equals(1));
        expect(received.first.id, equals('2'));
        await sub.cancel();
      });
    });
  });
}
