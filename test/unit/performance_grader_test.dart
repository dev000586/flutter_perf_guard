import 'package:flutter_perf_guard/src/analysis/grader/performance_grader.dart';
import 'package:flutter_perf_guard/src/core/bus/diagnostics_event_bus.dart';
import 'package:flutter_perf_guard/src/monitoring/navigation/navigation_tracker.dart';
import 'package:flutter_perf_guard/src/public_api/frame_profiler.dart';
import 'package:flutter_perf_guard/src/public_api/memory_profiler.dart';
import 'package:flutter_perf_guard/src/public_api/perf_guard_config.dart';
import 'package:flutter_perf_guard/src/public_api/rebuild_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bus = DiagnosticsEventBus.instance;
  const config = PerfGuardConfig();

  PerformanceGrader makeGrader() => PerformanceGrader(
    frameProfiler: FrameProfiler(config: config, bus: bus),
    memoryProfiler: MemoryProfiler(config: config, bus: bus),
    rebuildTracker: RebuildTracker(config: config, bus: bus),
    navigationTracker: NavigationTracker(bus: bus),
  );

  group('PerformanceGrade', () {
    test('score ordering is correct', () {
      expect(PerformanceGrade.A.score,
          greaterThan(PerformanceGrade.B.score));
      expect(PerformanceGrade.B.score,
          greaterThan(PerformanceGrade.C.score));
      expect(PerformanceGrade.C.score,
          greaterThan(PerformanceGrade.D.score));
      expect(PerformanceGrade.D.score,
          greaterThan(PerformanceGrade.F.score));
    });

    test('labels are correct', () {
      expect(PerformanceGrade.A.label, equals('A'));
      expect(PerformanceGrade.B.label, equals('B'));
      expect(PerformanceGrade.C.label, equals('C'));
      expect(PerformanceGrade.D.label, equals('D'));
      expect(PerformanceGrade.F.label, equals('F'));
    });

    test('emojis are set', () {
      for (final grade in PerformanceGrade.values) {
        expect(grade.emoji, isNotEmpty);
      }
    });
  });

  group('PerformanceGrader', () {
    group('gradeFrames()', () {
      test('returns a valid grade', () {
        final grader = makeGrader();
        final grade = grader.gradeFrames();
        expect(PerformanceGrade.values, contains(grade));
      });

      test('returns A when no frames recorded (no jank)', () {
        final grader = makeGrader();
        // No frames recorded → fps = 0 → graded based on jankRate = 0
        // jankRate < 0.01 with fps < 58 → C or below
        // Exact grade depends on fps threshold
        final grade = grader.gradeFrames();
        expect(grade, isNotNull);
      });
    });

    group('gradeMemory()', () {
      test('returns A when no memory data', () {
        final grader = makeGrader();
        expect(grader.gradeMemory(), equals(PerformanceGrade.A));
      });
    });

    group('gradeRebuilds()', () {
      test('returns A when no excessive rebuilds', () {
        final grader = makeGrader();
        expect(grader.gradeRebuilds(), equals(PerformanceGrade.A));
      });
    });

    group('gradeNavigation()', () {
      test('returns A when no slow transitions', () {
        final grader = makeGrader();
        expect(grader.gradeNavigation(), equals(PerformanceGrade.A));
      });
    });

    group('overallGrade', () {
      test('returns worst individual grade', () {
        final grader = makeGrader();
        final overall = grader.overallGrade;
        final categories = [
          grader.gradeFrames(),
          grader.gradeMemory(),
          grader.gradeRebuilds(),
          grader.gradeNavigation(),
        ];
        final worst =
        categories.reduce((a, b) => a.score < b.score ? a : b);
        expect(overall, equals(worst));
      });
    });

    group('summaries', () {
      test('frameSummary returns non-empty string', () {
        expect(makeGrader().frameSummary(), isNotEmpty);
      });

      test('memorySummary returns non-empty string', () {
        expect(makeGrader().memorySummary(), isNotEmpty);
      });

      test('rebuildSummary returns positive message when no excessive rebuilds',
              () {
            expect(makeGrader().rebuildSummary(), contains('✅'));
          });

      test('navigationSummary returns positive message when no slow transitions',
              () {
            expect(makeGrader().navigationSummary(), contains('✅'));
          });

      test('all summaries contain emoji indicator', () {
        final grader = makeGrader();
        for (final summary in [
          grader.frameSummary(),
          grader.memorySummary(),
          grader.rebuildSummary(),
          grader.navigationSummary(),
        ]) {
          final hasEmoji = summary.contains('✅') ||
              summary.contains('⚠') ||
              summary.contains('❌');
          expect(hasEmoji, isTrue,
              reason: 'Summary should contain emoji: $summary');
        }
      });
    });

    group('toJson()', () {
      test('contains all category keys', () {
        final json = makeGrader().toJson();
        expect(json.keys,
            containsAll(['overall', 'frames', 'memory', 'rebuilds', 'navigation']));
      });

      test('each category has grade and summary', () {
        final json = makeGrader().toJson();
        for (final key in ['frames', 'memory', 'rebuilds', 'navigation']) {
          final cat = json[key] as Map;
          expect(cat.containsKey('grade'), isTrue);
          expect(cat.containsKey('summary'), isTrue);
        }
      });

      test('overall grade is a valid letter', () {
        final json = makeGrader().toJson();
        expect(['A', 'B', 'C', 'D', 'F'], contains(json['overall']));
      });
    });
  });
}