import '../../monitoring/navigation/navigation_tracker.dart';
import '../../public_api/frame_profiler.dart';
import '../../public_api/memory_profiler.dart';
import '../../public_api/rebuild_tracker.dart';

/// Grades each performance category A–F and produces plain English summaries.
class PerformanceGrader {
  final FrameProfiler frameProfiler;
  final MemoryProfiler memoryProfiler;
  final RebuildTracker rebuildTracker;
  final NavigationTracker navigationTracker;

  const PerformanceGrader({
    required this.frameProfiler,
    required this.memoryProfiler,
    required this.rebuildTracker,
    required this.navigationTracker,
  });

  PerformanceGrade gradeFrames() {
    final fps = frameProfiler.currentFps();
    final jankRate = frameProfiler.jankRate;
    // final worstMs = frameProfiler.worstFrameDuration.inMilliseconds;

    if (fps >= 58 && jankRate < 0.01) return PerformanceGrade.A;
    if (fps >= 55 && jankRate < 0.03) return PerformanceGrade.B;
    if (fps >= 45 && jankRate < 0.08) return PerformanceGrade.C;
    if (fps >= 30 && jankRate < 0.15) return PerformanceGrade.D;
    return PerformanceGrade.F;
  }

  PerformanceGrade gradeMemory() {
    final latest = memoryProfiler.latest;
    if (latest == null) return PerformanceGrade.A;
    final usage = latest.heapUsagePercent;
    if (usage < 0.50) return PerformanceGrade.A;
    if (usage < 0.65) return PerformanceGrade.B;
    if (usage < 0.80) return PerformanceGrade.C;
    if (usage < 0.90) return PerformanceGrade.D;
    return PerformanceGrade.F;
  }

  PerformanceGrade gradeRebuilds() {
    final excessive = rebuildTracker.excessiveRebuilds.length;
    if (excessive == 0) return PerformanceGrade.A;
    if (excessive <= 1) return PerformanceGrade.B;
    if (excessive <= 3) return PerformanceGrade.C;
    if (excessive <= 6) return PerformanceGrade.D;
    return PerformanceGrade.F;
  }

  PerformanceGrade gradeNavigation() {
    final slowCount =
        navigationTracker.history.where((r) => r.isSlow).length;
    if (slowCount == 0) return PerformanceGrade.A;
    if (slowCount <= 1) return PerformanceGrade.B;
    if (slowCount <= 3) return PerformanceGrade.C;
    return PerformanceGrade.D;
  }

  PerformanceGrade get overallGrade {
    final grades = [
      gradeFrames(),
      gradeMemory(),
      gradeRebuilds(),
      gradeNavigation(),
    ];
    // Overall = worst category grade
    return grades.reduce((a, b) => a.score < b.score ? a : b);
  }

  /// Plain English summary for frames.
  String frameSummary() {
    final fps = frameProfiler.currentFps().toStringAsFixed(1);
    final jank = frameProfiler.jankFrames;
    final worstMs = frameProfiler.worstFrameDuration.inMilliseconds;
    final grade = gradeFrames();

    switch (grade) {
      case PerformanceGrade.A:
        return '✅ Excellent — $fps FPS, no jank detected';
      case PerformanceGrade.B:
        return '✅ Good — $fps FPS, $jank minor jank frames';
      case PerformanceGrade.C:
        return '⚠ Fair — $fps FPS, $jank jank frames (worst: ${worstMs}ms)';
      case PerformanceGrade.D:
        return '⚠ Poor — $fps FPS, significant jank (worst: ${worstMs}ms)';
      case PerformanceGrade.F:
        return '❌ Critical — $fps FPS, severe jank (worst: ${worstMs}ms). '
            'Check for heavy work on the UI thread.';
    }
  }

  /// Plain English summary for memory.
  String memorySummary() {
    final latest = memoryProfiler.latest;
    if (latest == null) return '✅ No memory data yet';
    final heapMb = latest.heapUsedMb.toStringAsFixed(1);
    final pct = (latest.heapUsagePercent * 100).toStringAsFixed(0);
    final grade = gradeMemory();

    switch (grade) {
      case PerformanceGrade.A:
        return '✅ Healthy — ${heapMb}MB heap ($pct% used)';
      case PerformanceGrade.B:
        return '✅ Good — ${heapMb}MB heap ($pct% used)';
      case PerformanceGrade.C:
        return '⚠ Moderate — ${heapMb}MB heap ($pct% used). '
            'Monitor for growth.';
      case PerformanceGrade.D:
        return '⚠ High — ${heapMb}MB heap ($pct% used). '
            'Check for retained listeners or large image caches.';
      case PerformanceGrade.F:
        return '❌ Critical — ${heapMb}MB heap ($pct% used). '
            'Memory leak likely. Ensure all controllers/subscriptions are disposed.';
    }
  }

  /// Plain English summary for rebuilds.
  String rebuildSummary() {
    final excessive = rebuildTracker.excessiveRebuilds;
    if (excessive.isEmpty) return '✅ No excessive rebuilds detected';

    final top = excessive.first;
    final rate = top.rebuildsPerSecond.toStringAsFixed(0);
    final file = top.location.fileInfo != null
        ? '\n   File: ${top.location.fileInfo}'
        : '\n   Run in debug mode to see file location';
    final path = top.location.ancestorPath != null
        ? '\n   Location: ${top.location.ancestorPath}'
        : '';

    return '❌ ${excessive.length} widget(s) rebuilding excessively\n'
        '   Worst: ${top.widgetType} at $rate/sec$file$path\n'
        '   Fix: Add const constructor or use RepaintBoundary';
  }

  /// Plain English summary for navigation.
  String navigationSummary() {
    final slow =
    navigationTracker.history.where((r) => r.isSlow).toList();
    if (slow.isEmpty) return '✅ All route transitions are fast';
    return '⚠ ${slow.length} slow transition(s) detected\n'
        '   Slowest: ${slow.first.fromRoute ?? "?"} → '
        '${slow.first.toRoute ?? "?"} '
        '(${slow.first.duration.inMilliseconds}ms)\n'
        '   Fix: Defer heavy initState work with addPostFrameCallback';
  }

  Map<String, dynamic> toJson() => {
    'overall': overallGrade.label,
    'frames': {
      'grade': gradeFrames().label,
      'summary': frameSummary(),
    },
    'memory': {
      'grade': gradeMemory().label,
      'summary': memorySummary(),
    },
    'rebuilds': {
      'grade': gradeRebuilds().label,
      'summary': rebuildSummary(),
    },
    'navigation': {
      'grade': gradeNavigation().label,
      'summary': navigationSummary(),
    },
  };
}

/// A–F performance grade with numeric score for comparison.
enum PerformanceGrade {
  A(5, 'A', '🟢'),
  B(4, 'B', '🟢'),
  C(3, 'C', '🟡'),
  D(2, 'D', '🟠'),
  F(1, 'F', '🔴');

  final int score;
  final String label;
  final String emoji;

  const PerformanceGrade(this.score, this.label, this.emoji);
}