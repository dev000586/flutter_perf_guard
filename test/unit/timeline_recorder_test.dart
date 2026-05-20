import 'dart:convert';

import 'package:flutter_perf_guard/src/core/bus/diagnostics_event_bus.dart';
import 'package:flutter_perf_guard/src/core/events/performance_event.dart';
import 'package:flutter_perf_guard/src/public_api/timeline_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

class _SimpleEvent extends PerformanceEvent {
  final String tag;
  _SimpleEvent(String id, this.tag)
      : super(
    id: id,
    timestamp: DateTime.now(),  // real DateTime, no fake stub needed
    source: 'test',
  );
  @override
  Map<String, dynamic> toJson() => {'id': id, 'tag': tag, 'source': source};
}

void main() {
  group('TimelineRecorder', () {
    final bus = DiagnosticsEventBus.instance;

    test('isRecording is false before start', () {
      final recorder = TimelineRecorder(bus: bus);
      expect(recorder.isRecording, isFalse);
    });

    test('isRecording is true after start', () {
      final recorder = TimelineRecorder(bus: bus);
      recorder.start();
      expect(recorder.isRecording, isTrue);
      recorder.stop();
    });

    test('isRecording is false after stop', () {
      final recorder = TimelineRecorder(bus: bus);
      recorder.start();
      recorder.stop();
      expect(recorder.isRecording, isFalse);
    });

    test('records events between start and stop', () async {
      final recorder = TimelineRecorder(bus: bus, maxEntries: 100);
      recorder.start();

      bus.emit(_SimpleEvent('ev1', 'alpha'));
      bus.emit(_SimpleEvent('ev2', 'beta'));
      await Future.delayed(const Duration(milliseconds: 20));

      recorder.stop();

      final entries = recorder.entries;
      expect(entries.any((e) => e['id'] == 'ev1'), isTrue);
      expect(entries.any((e) => e['id'] == 'ev2'), isTrue);
    });

    test('does not record events after stop', () async {
      final recorder = TimelineRecorder(bus: bus, maxEntries: 100);
      recorder.start();
      await Future.delayed(const Duration(milliseconds: 5));
      recorder.stop();

      final countAfterStop = recorder.entryCount;

      bus.emit(_SimpleEvent('post_stop', 'extra'));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(recorder.entryCount, equals(countAfterStop));
    });

    test('clear resets all entries', () async {
      final recorder = TimelineRecorder(bus: bus, maxEntries: 100);
      recorder.start();
      bus.emit(_SimpleEvent('x', 'x'));
      await Future.delayed(const Duration(milliseconds: 10));
      recorder.stop();
      recorder.clear();

      expect(recorder.entryCount, equals(0));
      expect(recorder.startTime, isNull);
    });

    test('respects maxEntries circular buffer', () async {
      final recorder = TimelineRecorder(bus: bus, maxEntries: 5);
      recorder.start();

      for (int i = 0; i < 20; i++) {
        bus.emit(_SimpleEvent('overflow_$i', 'x'));
      }
      await Future.delayed(const Duration(milliseconds: 30));
      recorder.stop();

      expect(recorder.entryCount, lessThanOrEqualTo(5));
    });

    test('start again after stop resets buffer', () async {
      final recorder = TimelineRecorder(bus: bus, maxEntries: 100);

      recorder.start();
      bus.emit(_SimpleEvent('first_session', 'f'));
      await Future.delayed(const Duration(milliseconds: 10));
      recorder.stop();

      recorder.start();
      await Future.delayed(const Duration(milliseconds: 5));
      recorder.stop();

      // After second start, only second-session events should be present
      final entries = recorder.entries;
      expect(entries.any((e) => e['id'] == 'first_session'), isFalse);
    });

    group('exportJson', () {
      test('returns valid JSON string', () async {
        final recorder = TimelineRecorder(bus: bus, maxEntries: 10);
        recorder.start();
        bus.emit(_SimpleEvent('export_test', 'tag'));
        await Future.delayed(const Duration(milliseconds: 10));
        recorder.stop();

        final json = recorder.exportJson();
        expect(() => jsonDecode(json), returnsNormally);
      });

      test('pretty export is indented', () async {
        final recorder = TimelineRecorder(bus: bus, maxEntries: 10);
        recorder.start();
        recorder.stop();

        final pretty = recorder.exportJson(pretty: true);
        expect(pretty, contains('\n'));
        expect(pretty, contains('  '));
      });

      test('compact export has no newlines', () async {
        final recorder = TimelineRecorder(bus: bus, maxEntries: 10);
        recorder.start();
        recorder.stop();

        final compact = recorder.exportJson(pretty: false);
        expect(compact, isNot(contains('\n')));
      });

      test('exported JSON contains entryCount field', () async {
        final recorder = TimelineRecorder(bus: bus, maxEntries: 10);
        recorder.start();
        recorder.stop();

        final json = jsonDecode(recorder.exportJson()) as Map;
        expect(json.containsKey('entryCount'), isTrue);
      });

      test('exported JSON entries contain offsetMs', () async {
        final recorder = TimelineRecorder(bus: bus, maxEntries: 10);
        recorder.start();
        bus.emit(_SimpleEvent('with_offset', 'o'));
        await Future.delayed(const Duration(milliseconds: 10));
        recorder.stop();

        final json = jsonDecode(recorder.exportJson()) as Map;
        final entries = json['entries'] as List;
        if (entries.isNotEmpty) {
          expect(entries.first.containsKey('offsetMs'), isTrue);
        }
      });
    });

    group('entriesByType', () {
      test('filters entries by source', () async {
        final recorder = TimelineRecorder(bus: bus, maxEntries: 50);
        recorder.start();
        bus.emit(_SimpleEvent('t1', 'frame'));
        bus.emit(_SimpleEvent('t2', 'memory'));
        await Future.delayed(const Duration(milliseconds: 20));
        recorder.stop();

        final all = recorder.entries;
        final byTest = recorder.entriesByType('test');
        expect(byTest.length, equals(all.length));
      });
    });

    test('toJson returns recording status and count', () {
      final recorder = TimelineRecorder(bus: bus);
      final json = recorder.toJson();
      expect(json.containsKey('recording'), isTrue);
      expect(json.containsKey('entryCount'), isTrue);
      expect(json.containsKey('maxEntries'), isTrue);
    });
  });
}
