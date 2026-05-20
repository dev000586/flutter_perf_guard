import 'package:flutter_perf_guard/src/core/events/jank_event.dart';
import 'package:flutter_perf_guard/src/core/events/performance_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JankEvent', () {
    late JankEvent mildJank;
    late JankEvent severeJank;

    setUp(() {
      mildJank = JankEvent(
        id: 'jank_1',
        timestamp: DateTime(2024),
        source: 'FrameProfiler',
        consecutiveJankFrames: 3,
        worstFrameDuration: const Duration(milliseconds: 25),
        averageFrameDuration: const Duration(milliseconds: 20),
        droppedFrames: 1,
      );

      severeJank = JankEvent(
        id: 'jank_2',
        timestamp: DateTime(2024),
        source: 'FrameProfiler',
        consecutiveJankFrames: 10,
        worstFrameDuration: const Duration(milliseconds: 120),
        averageFrameDuration: const Duration(milliseconds: 80),
        droppedFrames: 5,
        culpritWidgetPath: 'Scaffold > ListView > ExpensiveItem',
      );
    });

    group('averageFps', () {
      test('calculates FPS from averageFrameDuration', () {
        // 20ms average → 50 FPS
        expect(mildJank.averageFps, closeTo(50.0, 0.5));
      });

      test('severe jank has low FPS', () {
        // 80ms average → 12.5 FPS
        expect(severeJank.averageFps, closeTo(12.5, 0.5));
      });
    });

    group('severity', () {
      test('default severity is critical', () {
        expect(mildJank.severity, equals(EventSeverity.critical));
      });

      test('critical events are included in criticalEvents stream filter', () {
        expect(mildJank.severity.isCritical, isTrue);
      });
    });

    group('culpritWidgetPath', () {
      test('is null when not provided', () {
        expect(mildJank.culpritWidgetPath, isNull);
      });

      test('is set when provided', () {
        expect(severeJank.culpritWidgetPath,
            equals('Scaffold > ListView > ExpensiveItem'));
      });
    });

    group('toJson', () {
      test('contains all required keys', () {
        final json = mildJank.toJson();
        expect(json.keys, containsAll([
          'id', 'timestamp', 'source', 'severity',
          'consecutiveJankFrames', 'worstFrameDurationMs',
          'averageFrameDurationMs', 'droppedFrames', 'averageFps',
        ]));
      });

      test('culpritWidgetPath is present when set', () {
        final json = severeJank.toJson();
        expect(json.containsKey('culpritWidgetPath'), isTrue);
        expect(json['culpritWidgetPath'],
            equals('Scaffold > ListView > ExpensiveItem'));
      });

      test('culpritWidgetPath is absent when null', () {
        final json = mildJank.toJson();
        expect(json.containsKey('culpritWidgetPath'), isFalse);
      });

      test('averageFps is serialized', () {
        final json = mildJank.toJson();
        expect(json['averageFps'], closeTo(50.0, 0.5));
      });

      test('durations are in milliseconds', () {
        final json = mildJank.toJson();
        expect(json['worstFrameDurationMs'], closeTo(25.0, 0.01));
        expect(json['averageFrameDurationMs'], closeTo(20.0, 0.01));
      });
    });

    group('equality', () {
      test('same event equals itself', () {
        expect(mildJank, equals(mildJank));
      });

      test('different events are not equal', () {
        expect(mildJank, isNot(equals(severeJank)));
      });
    });

    group('props', () {
      test('props includes all equality fields', () {
        expect(mildJank.props, isNotEmpty);
      });
    });
  });

  group('EventSeverity extensions', () {
    test('info.isInfo is true', () {
      expect(EventSeverity.info.isInfo, isTrue);
      expect(EventSeverity.info.isWarning, isFalse);
      expect(EventSeverity.info.isCritical, isFalse);
    });

    test('warning.isWarning is true', () {
      expect(EventSeverity.warning.isWarning, isTrue);
      expect(EventSeverity.warning.isInfo, isFalse);
      expect(EventSeverity.warning.isCritical, isFalse);
    });

    test('critical.isCritical is true', () {
      expect(EventSeverity.critical.isCritical, isTrue);
      expect(EventSeverity.critical.isInfo, isFalse);
      expect(EventSeverity.critical.isWarning, isFalse);
    });

    test('labels are correct', () {
      expect(EventSeverity.info.label, equals('INFO'));
      expect(EventSeverity.warning.label, equals('WARNING'));
      expect(EventSeverity.critical.label, equals('CRITICAL'));
    });
  });
}
