import 'package:flutter_perf_guard/flutter_perf_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MemoryProfiler concurrency', () {
    final bus = DiagnosticsEventBus.instance;

    MemoryMetrics makeMetrics(int heapMb, int capacityMb) => MemoryMetrics(
          heapUsedBytes: heapMb * 1024 * 1024,
          heapCapacityBytes: capacityMb * 1024 * 1024,
          externalBytes: 0,
          rssBytes: (heapMb + 10) * 1024 * 1024,
          gcCount: 0,
          timestamp: DateTime.now(),
        );

    test('concurrent emits from multiple sources do not interleave events', () async {
      final received = <MemoryEvent>[];
      final sub = bus.memoryEvents.listen(received.add);

      // Emit memory events rapidly from "multiple sources"
      final futures = List.generate(50, (i) async {
        bus.emit(MemoryEvent.fromSample(
          id: 'mem_concurrent_$i',
          metrics: makeMetrics(50 + i, 200),
          allocationDelta: i * 1024,
          leakSuspected: false,
        ));
      });

      await Future.wait(futures);
      await Future.delayed(const Duration(milliseconds: 50));

      // All 50 events must be received in some order
      expect(received.length, equals(50));

      // All event IDs must be unique
      final ids = received.map((e) => e.id).toSet();
      expect(ids.length, equals(50));

      await sub.cancel();
    });

    test('leak detection events are correctly emitted', () async {
      final leakEvents = <MemoryEvent>[];
      final sub = bus.memoryEvents.where((e) => e.leakSuspected).listen(leakEvents.add);

      // Simulate escalating heap to trigger leak flag
      for (int i = 0; i < 5; i++) {
        bus.emit(MemoryEvent.fromSample(
          id: 'leak_sim_$i',
          metrics: makeMetrics(50 + i * 20, 200), // growing heap
          allocationDelta: 20 * 1024 * 1024,
          leakSuspected: i >= 3, // flag after 3 samples
        ));
      }

      await Future.delayed(const Duration(milliseconds: 50));

      expect(leakEvents, isNotEmpty);
      for (final e in leakEvents) {
        expect(e.leakSuspected, isTrue);
        expect(e.severity.isCritical, isTrue);
      }

      await sub.cancel();
    });

    test('memory events carry correct delta', () async {
      final received = <MemoryEvent>[];
      final sub = bus.memoryEvents.listen(received.add);

      bus.emit(MemoryEvent.fromSample(
        id: 'delta_test',
        metrics: makeMetrics(100, 200),
        allocationDelta: 5 * 1024 * 1024, // 5 MB delta
        leakSuspected: false,
      ));

      await Future.delayed(Duration.zero);

      expect(received.length, equals(1));
      expect(received.first.allocationDelta, equals(5 * 1024 * 1024));

      await sub.cancel();
    });

    test('severity is info for normal memory usage', () async {
      final received = <MemoryEvent>[];
      final sub = bus.memoryEvents.listen(received.add);

      bus.emit(MemoryEvent.fromSample(
        id: 'normal_mem',
        metrics: makeMetrics(50, 200), // 25% heap
        allocationDelta: 0,
        leakSuspected: false,
      ));

      await Future.delayed(Duration.zero);

      expect(received.first.severity.isInfo, isTrue);
      await sub.cancel();
    });

    test('severity is critical when leak suspected', () async {
      final received = <MemoryEvent>[];
      final sub = bus.memoryEvents.listen(received.add);

      bus.emit(MemoryEvent.fromSample(
        id: 'leak_mem',
        metrics: makeMetrics(50, 200),
        allocationDelta: 1024 * 1024,
        leakSuspected: true,
      ));

      await Future.delayed(Duration.zero);

      expect(received.first.severity.isCritical, isTrue);
      await sub.cancel();
    });

    test('toJson serializes all fields', () {
      final metrics = makeMetrics(80, 200);
      final event = MemoryEvent.fromSample(
        id: 'json_test',
        metrics: metrics,
        allocationDelta: 1024,
        leakSuspected: false,
      );

      final json = event.toJson();
      expect(json['id'], equals('json_test'));
      expect(json['leakSuspected'], isFalse);
      expect(json['allocationDelta'], equals(1024));
      expect(json['metrics'], isA<Map>());
      expect(json['metrics']['heapUsedMb'], closeTo(80.0, 0.1));
    });
  });
}
