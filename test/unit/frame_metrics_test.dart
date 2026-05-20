import 'package:flutter_perf_guard/src/profiling/frame/frame_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FrameMetrics', () {
    late FrameMetrics goodFrame;
    late FrameMetrics slowFrame;
    late FrameMetrics jankFrame;

    setUp(() {
      goodFrame = const FrameMetrics(
        frameNumber: 1,
        buildDuration: Duration(milliseconds: 3),
        rasterDuration: Duration(milliseconds: 2),
        totalDuration: Duration(milliseconds: 5),
        vsyncOverhead: Duration(microseconds: 200),
        timestampMicros: 1000000,
      );

      slowFrame = const FrameMetrics(
        frameNumber: 2,
        buildDuration: Duration(milliseconds: 6),
        rasterDuration: Duration(milliseconds: 5),
        totalDuration: Duration(milliseconds: 11),
        vsyncOverhead: Duration(microseconds: 200),
        timestampMicros: 1016000,
      );

      jankFrame = const FrameMetrics(
        frameNumber: 3,
        buildDuration: Duration(milliseconds: 12),
        rasterDuration: Duration(milliseconds: 10),
        totalDuration: Duration(milliseconds: 22),
        vsyncOverhead: Duration(microseconds: 200),
        timestampMicros: 1033000,
      );
    });

    group('isJank', () {
      test('returns false for fast frame (5ms)', () {
        expect(goodFrame.isJank, isFalse);
      });

      test('returns false for slow frame (11ms)', () {
        expect(slowFrame.isJank, isFalse);
      });

      test('returns true for jank frame (22ms)', () {
        expect(jankFrame.isJank, isTrue);
      });

      test('returns true for exactly 17ms frame', () {
        const borderJank = FrameMetrics(
          frameNumber: 4,
          buildDuration: Duration(milliseconds: 9),
          rasterDuration: Duration(milliseconds: 8),
          totalDuration: Duration(milliseconds: 17),
          vsyncOverhead: Duration.zero,
          timestampMicros: 0,
        );
        expect(borderJank.isJank, isTrue);
      });

      test('returns false for exactly 16ms frame', () {
        const border = FrameMetrics(
          frameNumber: 5,
          buildDuration: Duration(milliseconds: 8),
          rasterDuration: Duration(milliseconds: 8),
          totalDuration: Duration(milliseconds: 16),
          vsyncOverhead: Duration.zero,
          timestampMicros: 0,
        );
        expect(border.isJank, isFalse);
      });
    });

    group('isSlow', () {
      test('returns false for fast frame', () {
        expect(goodFrame.isSlow, isFalse);
      });

      test('returns true for 11ms frame', () {
        expect(slowFrame.isSlow, isTrue);
      });
    });

    group('fps', () {
      test('calculates correct fps for 5ms frame', () {
        expect(goodFrame.fps, closeTo(200.0, 1.0));
      });

      test('calculates correct fps for 22ms frame', () {
        expect(jankFrame.fps, closeTo(45.45, 0.5));
      });

      test('returns 60 for zero-duration frame', () {
        const zeroFrame = FrameMetrics(
          frameNumber: 0,
          buildDuration: Duration.zero,
          rasterDuration: Duration.zero,
          totalDuration: Duration.zero,
          vsyncOverhead: Duration.zero,
          timestampMicros: 0,
        );
        expect(zeroFrame.fps, equals(60.0));
      });
    });

    group('buildFraction / rasterFraction', () {
      test('build fraction sums to correct ratio', () {
        expect(goodFrame.buildFraction, closeTo(0.6, 0.01));
        expect(goodFrame.rasterFraction, closeTo(0.4, 0.01));
      });

      test('fractions for zero total are 0', () {
        const zeroFrame = FrameMetrics(
          frameNumber: 0,
          buildDuration: Duration.zero,
          rasterDuration: Duration.zero,
          totalDuration: Duration.zero,
          vsyncOverhead: Duration.zero,
          timestampMicros: 0,
        );
        expect(zeroFrame.buildFraction, equals(0.0));
        expect(zeroFrame.rasterFraction, equals(0.0));
      });
    });

    group('toJson', () {
      test('contains all expected keys', () {
        final json = goodFrame.toJson();
        expect(json.keys, containsAll([
          'frameNumber', 'buildDurationMicros', 'rasterDurationMicros',
          'totalDurationMicros', 'fps', 'isJank', 'isSlow',
        ]));
      });

      test('serializes values correctly', () {
        final json = goodFrame.toJson();
        expect(json['frameNumber'], equals(1));
        expect(json['isJank'], isFalse);
        expect(json['totalDurationMicros'], equals(5000));
      });
    });

    group('equality', () {
      test('identical frames are equal', () {
        expect(goodFrame, equals(goodFrame));
      });

      test('different frames are not equal', () {
        expect(goodFrame, isNot(equals(jankFrame)));
      });
    });

    group('toString', () {
      test('includes key info', () {
        final str = goodFrame.toString();
        expect(str, contains('1'));
        expect(str, contains('5ms'));
      });
    });
  });
}
