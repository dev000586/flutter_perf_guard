import 'package:flutter/widgets.dart';
import 'package:flutter_perf_guard/src/core/bus/diagnostics_event_bus.dart';
import 'package:flutter_perf_guard/src/monitoring/navigation/navigation_tracker.dart';
import 'package:flutter_perf_guard/src/monitoring/startup/startup_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bus = DiagnosticsEventBus.instance;

  group('StartupAnalyzer', () {
    late StartupAnalyzer analyzer;

    setUp(() {
      analyzer = StartupAnalyzer(bus: bus);
    });

    test('timeToFirstFrame is null before any marks', () {
      expect(analyzer.timeToFirstFrame, isNull);
    });

    test('timeToInteractive is null before interactive mark', () {
      analyzer.markAppStart();
      expect(analyzer.timeToInteractive, isNull);
    });

    test('markFirstFrame sets timeToFirstFrame', () async {
      analyzer.markAppStart();
      await Future.delayed(const Duration(milliseconds: 10));
      analyzer.markFirstFrame();

      expect(analyzer.timeToFirstFrame, isNotNull);
      expect(
        analyzer.timeToFirstFrame!.inMilliseconds,
        greaterThanOrEqualTo(0),
      );
    });

    test('markInteractive sets timeToInteractive', () async {
      analyzer.markAppStart();
      await Future.delayed(const Duration(milliseconds: 5));
      analyzer.markInteractive();

      expect(analyzer.timeToInteractive, isNotNull);
    });

    test('markFirstFrame is idempotent (second call is ignored)', () {
      analyzer.markAppStart();
      analyzer.markFirstFrame();
      final first = analyzer.timeToFirstFrame;
      analyzer.markFirstFrame(); // should be ignored
      expect(analyzer.timeToFirstFrame, equals(first));
    });

    test('milestones are in chronological order', () async {
      analyzer.markAppStart();
      await Future.delayed(const Duration(milliseconds: 5));
      analyzer.markFirstFrame();
      await Future.delayed(const Duration(milliseconds: 5));
      analyzer.markNavigatorReady();
      await Future.delayed(const Duration(milliseconds: 5));
      analyzer.markInteractive();

      final ttff = analyzer.timeToFirstFrame!.inMilliseconds;
      final tti = analyzer.timeToInteractive!.inMilliseconds;
      expect(tti, greaterThanOrEqualTo(ttff));
    });

    test('toJson contains all milestone keys', () {
      analyzer.markAppStart();
      analyzer.markFirstFrame();
      analyzer.markInteractive();

      final json = analyzer.toJson();
      expect(json.containsKey('appStartTime'), isTrue);
      expect(json.containsKey('milestones'), isTrue);

      final milestones = json['milestones'] as Map;
      expect(milestones.containsKey('app_start'), isTrue);
      expect(milestones.containsKey('first_frame'), isTrue);
      expect(milestones.containsKey('interactive'), isTrue);
    });

    test('milestones without markAppStart produce no data', () {
      // No markAppStart called
      analyzer.markFirstFrame(); // should be no-op
      expect(analyzer.timeToFirstFrame, isNull);
    });
  });

  group('NavigationTracker', () {
    late NavigationTracker tracker;

    setUp(() {
      tracker = NavigationTracker(bus: bus);
    });

    test('history is empty initially', () {
      expect(tracker.history, isEmpty);
    });

    test('records push transition', () {
      final route = _FakeRoute('/home');
      tracker.didPush(route, null);
      // Navigate away to complete the transition
      tracker.didPop(route, null);

      expect(tracker.history, isNotEmpty);
    });

    test('NavigationRecord.isSlow is false for fast transitions', () async {
      final route = _FakeRoute('/fast');
      tracker.didPush(route, null);
      // Immediately pop (< 300ms)
      tracker.didPop(route, null);

      final record = tracker.history.last;
      // Very fast pop should not be slow
      expect(record.duration.inMilliseconds, lessThan(300));
      expect(record.isSlow, isFalse);
    });

    test('toJson contains history', () {
      final json = tracker.toJson();
      expect(json.containsKey('transitionCount'), isTrue);
      expect(json.containsKey('history'), isTrue);
    });

    test('NavigationRecord.toJson contains required keys', () {
      final record = NavigationRecord(
        type: 'push',
        fromRoute: '/home',
        toRoute: '/detail',
        duration: const Duration(milliseconds: 150),
        timestamp: DateTime(2024),
      );

      final json = record.toJson();
      expect(json.keys, containsAll([
        'type', 'fromRoute', 'toRoute', 'durationMs', 'isSlow', 'timestamp',
      ]));
    });

    test('history is bounded to 100 entries', () {
      final route = _FakeRoute('/route');
      for (int i = 0; i < 150; i++) {
        tracker.didPush(route, null);
        tracker.didPop(route, null);
      }

      expect(tracker.history.length, lessThanOrEqualTo(100));
    });
  });
}

class _FakeRoute extends Route<void> {
  _FakeRoute(String name)
      : super(settings: RouteSettings(name: name));
}
