import 'package:flutter_perf_guard/src/public_api/perf_guard_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerfGuardConfig', () {
    group('default values', () {
      const config = PerfGuardConfig();

      test('enableFrameProfiler defaults to true', () {
        expect(config.enableFrameProfiler, isTrue);
      });

      test('enableMemoryProfiler defaults to true', () {
        expect(config.enableMemoryProfiler, isTrue);
      });

      test('enableRebuildTracker defaults to true', () {
        expect(config.enableRebuildTracker, isTrue);
      });

      test('jankThreshold defaults to 16ms', () {
        expect(config.jankThreshold, equals(const Duration(milliseconds: 16)));
      });

      test('slowFrameThreshold defaults to 8ms', () {
        expect(config.slowFrameThreshold, equals(const Duration(milliseconds: 8)));
      });

      test('memoryWarningThreshold defaults to 0.80', () {
        expect(config.memoryWarningThreshold, closeTo(0.80, 0.001));
      });

      test('memoryCriticalThreshold defaults to 0.92', () {
        expect(config.memoryCriticalThreshold, closeTo(0.92, 0.001));
      });

      test('excessiveRebuildRatePerSecond defaults to 60', () {
        expect(config.excessiveRebuildRatePerSecond, closeTo(60.0, 0.001));
      });

      test('memorySamplingInterval defaults to 2 seconds', () {
        expect(config.memorySamplingInterval, equals(const Duration(seconds: 2)));
      });

      test('frameHistorySize defaults to 300', () {
        expect(config.frameHistorySize, equals(300));
      });

      test('verbose defaults to false', () {
        expect(config.verbose, isFalse);
      });

      test('autoExportOnCritical defaults to false', () {
        expect(config.autoExportOnCritical, isFalse);
      });
    });

    group('presets', () {
      test('minimal disables most modules', () {
        expect(PerfGuardConfig.minimal.enableFrameProfiler, isTrue);
        expect(PerfGuardConfig.minimal.enableMemoryProfiler, isFalse);
        expect(PerfGuardConfig.minimal.enableRebuildTracker, isFalse);
        expect(PerfGuardConfig.minimal.enableDashboard, isFalse);
        expect(PerfGuardConfig.minimal.enableStartupAnalyzer, isFalse);
      });

      test('full enables all modules', () {
        expect(PerfGuardConfig.full.enableFrameProfiler, isTrue);
        expect(PerfGuardConfig.full.enableMemoryProfiler, isTrue);
        expect(PerfGuardConfig.full.enableRebuildTracker, isTrue);
        expect(PerfGuardConfig.full.enableJankDetector, isTrue);
        expect(PerfGuardConfig.full.enableDashboard, isTrue);
        expect(PerfGuardConfig.full.enableStartupAnalyzer, isTrue);
        expect(PerfGuardConfig.full.enableNavigationTracker, isTrue);
        expect(PerfGuardConfig.full.enableAsyncProfiler, isTrue);
        expect(PerfGuardConfig.full.enableNetworkProfiler, isTrue);
        expect(PerfGuardConfig.full.enableRepaintAnalyzer, isTrue);
        expect(PerfGuardConfig.full.enableOverdrawAnalyzer, isTrue);
      });

      test('minimal keeps jank detector enabled', () {
        expect(PerfGuardConfig.minimal.enableJankDetector, isTrue);
      });
    });

    group('copyWith', () {
      test('copies with single field changed', () {
        const base = PerfGuardConfig();
        final copy = base.copyWith(verbose: true);

        expect(copy.verbose, isTrue);
        expect(copy.enableFrameProfiler, equals(base.enableFrameProfiler));
        expect(copy.jankThreshold, equals(base.jankThreshold));
      });

      test('copies with multiple fields changed', () {
        const base = PerfGuardConfig();
        final copy = base.copyWith(
          enableMemoryProfiler: false,
          memorySamplingInterval: const Duration(seconds: 5),
          frameHistorySize: 100,
        );

        expect(copy.enableMemoryProfiler, isFalse);
        expect(copy.memorySamplingInterval, equals(const Duration(seconds: 5)));
        expect(copy.frameHistorySize, equals(100));
        // Unchanged fields preserved
        expect(copy.enableFrameProfiler, isTrue);
        expect(copy.verbose, isFalse);
      });

      test('copyWith with no args returns equivalent config', () {
        const base = PerfGuardConfig(
          verbose: true,
          frameHistorySize: 200,
          jankThreshold: Duration(milliseconds: 20),
        );
        final copy = base.copyWith();

        expect(copy.verbose, equals(base.verbose));
        expect(copy.frameHistorySize, equals(base.frameHistorySize));
        expect(copy.jankThreshold, equals(base.jankThreshold));
      });
    });

    group('threshold validation', () {
      test('jankThreshold must be greater than slowFrameThreshold logically', () {
        const config = PerfGuardConfig(
          jankThreshold: Duration(milliseconds: 16),
          slowFrameThreshold: Duration(milliseconds: 8),
        );
        expect(
          config.jankThreshold.inMilliseconds,
          greaterThan(config.slowFrameThreshold.inMilliseconds),
        );
      });

      test('memoryCriticalThreshold should exceed memoryWarningThreshold', () {
        const config = PerfGuardConfig();
        expect(
          config.memoryCriticalThreshold,
          greaterThan(config.memoryWarningThreshold),
        );
      });
    });
  });
}
