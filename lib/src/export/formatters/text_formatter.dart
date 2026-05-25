import '../../analysis/grader/performance_grader.dart';
import '../../monitoring/async/async_profiler.dart';
import '../../monitoring/image/image_cache_analyzer.dart';
import '../../monitoring/navigation/navigation_tracker.dart';
import '../../monitoring/network/network_profiler.dart';
import '../../public_api/frame_profiler.dart';
import '../../public_api/memory_profiler.dart';
import '../../public_api/rebuild_tracker.dart';

/// Generates a human-readable plain text performance report.
class TextFormatter {
  final FrameProfiler frameProfiler;
  final MemoryProfiler memoryProfiler;
  final RebuildTracker rebuildTracker;
  final NavigationTracker navigationTracker;
  final NetworkProfiler? networkProfiler;
  final AsyncProfiler? asyncProfiler;
  final ImageCacheAnalyzer imageCacheAnalyzer;

  TextFormatter({
    required this.frameProfiler,
    required this.memoryProfiler,
    required this.rebuildTracker,
    required this.navigationTracker,
    required this.imageCacheAnalyzer, this.networkProfiler,
    this.asyncProfiler,
  });

  String format() {
    final grader = PerformanceGrader(
      frameProfiler: frameProfiler,
      memoryProfiler: memoryProfiler,
      rebuildTracker: rebuildTracker,
      navigationTracker: navigationTracker,
    );

    final buf = StringBuffer();
    final now = DateTime.now();
    const width = 60;
    final divider = '═' * width;
    final thinDivider = '─' * width;

    buf.writeln(divider);
    buf.writeln(_center('flutter_perf_guard', width));
    buf.writeln(_center('Performance Report', width));
    buf.writeln(_center(
        '${now.year}-${_pad(now.month)}-${_pad(now.day)} '
            '${_pad(now.hour)}:${_pad(now.minute)}:${_pad(now.second)}',
        width));
    buf.writeln(divider);
    buf.writeln();

    // Overall grade
    final overall = grader.overallGrade;
    buf.writeln(
        'OVERALL GRADE : ${overall.emoji} ${overall.label}');
    buf.writeln(thinDivider);
    buf.writeln();

    // ── FRAMES ──────────────────────────────────────────────
    buf.writeln('FRAMES   ${grader.gradeFrames().emoji} ${grader.gradeFrames().label}');
    buf.writeln(thinDivider);
    buf.writeln('  Average FPS      : ${frameProfiler.currentFps().toStringAsFixed(1)}');
    buf.writeln('  Jank Events      : ${frameProfiler.jankFrames}');
    buf.writeln('  Worst Frame      : ${frameProfiler.worstFrameDuration.inMilliseconds}ms  (budget: 16ms)');
    buf.writeln('  Avg Frame Time   : ${frameProfiler.averageFrameTime.inMilliseconds}ms');
    buf.writeln('  Jank Rate        : ${(frameProfiler.jankRate * 100).toStringAsFixed(1)}%');
    buf.writeln('  Summary          : ${grader.frameSummary()}');
    buf.writeln();

    // ── MEMORY ──────────────────────────────────────────────
    final mem = memoryProfiler.latest;
    buf.writeln('MEMORY   ${grader.gradeMemory().emoji} ${grader.gradeMemory().label}');
    buf.writeln(thinDivider);
    if (mem != null) {
      buf.writeln('  Heap Used        : ${mem.heapUsedMb.toStringAsFixed(1)}MB');
      buf.writeln('  Heap Capacity    : ${mem.heapCapacityMb.toStringAsFixed(1)}MB');
      buf.writeln('  Heap Usage       : ${(mem.heapUsagePercent * 100).toStringAsFixed(0)}%');
      buf.writeln('  RSS              : ${mem.rssMb.toStringAsFixed(1)}MB');
      buf.writeln('  Peak Heap        : ${(memoryProfiler.peakHeapBytes / (1024 * 1024)).toStringAsFixed(1)}MB');
    } else {
      buf.writeln('  No memory data collected yet');
    }
    buf.writeln('  Summary          : ${grader.memorySummary()}');
    buf.writeln();

    // ── IMAGE CACHE ─────────────────────────────────────────
    final imgSnap = imageCacheAnalyzer.snapshot();
    buf.writeln('IMAGE CACHE');
    buf.writeln(thinDivider);
    buf.writeln('  Cached Images    : ${imgSnap.currentCount} / ${imgSnap.maxCount}');
    buf.writeln('  Cache Size       : ${imgSnap.currentSizeMb.toStringAsFixed(1)}MB / ${imgSnap.maxSizeMb.toStringAsFixed(1)}MB');
    buf.writeln('  Usage            : ${(imgSnap.usagePercent * 100).toStringAsFixed(0)}%');
    buf.writeln('  Summary          : ${imageCacheAnalyzer.plainEnglishSummary}');
    buf.writeln();

    // ── REBUILDS ────────────────────────────────────────────
    buf.writeln('REBUILDS   ${grader.gradeRebuilds().emoji} ${grader.gradeRebuilds().label}');
    buf.writeln(thinDivider);
    final hot = rebuildTracker.hotWidgets.take(5).toList();
    if (hot.isEmpty) {
      buf.writeln('  No rebuild data (enable in debug mode)');
    } else {
      buf.writeln('  Top Offenders:');
      for (int i = 0; i < hot.length; i++) {
        final m = hot[i];
        final rate = m.rebuildsPerSecond.toStringAsFixed(0);
        final flag = m.isExcessive ? ' ← EXCESSIVE' : '';
        buf.writeln('  ${i + 1}. ${m.widgetType.padRight(24)} ${rate.padLeft(4)}/sec$flag');
        if (m.location.fileInfo != null) {
          buf.writeln('     File: ${m.location.fileInfo}');
        }
        if (m.location.ancestorPath != null) {
          buf.writeln('     Path: ${m.location.ancestorPath}');
        }
      }
    }
    buf.writeln('  Summary: ${grader.rebuildSummary()}');
    buf.writeln();

    // ── NAVIGATION ──────────────────────────────────────────
    buf.writeln('NAVIGATION   ${grader.gradeNavigation().emoji} ${grader.gradeNavigation().label}');
    buf.writeln(thinDivider);
    final navHistory = navigationTracker.history;
    if (navHistory.isEmpty) {
      buf.writeln('  No navigation data recorded');
    } else {
      final slow =
      navHistory.where((r) => r.isSlow).toList();
      buf.writeln('  Total Transitions : ${navHistory.length}');
      buf.writeln('  Slow Transitions  : ${slow.length}');
      for (final r in slow.take(3)) {
        buf.writeln(
            '  ${r.fromRoute ?? "?"} → ${r.toRoute ?? "?"}'
                ' — ${r.duration.inMilliseconds}ms');
      }
    }
    buf.writeln('  Summary: ${grader.navigationSummary()}');
    buf.writeln();

    // ── NETWORK ─────────────────────────────────────────────
    if (networkProfiler != null) {
      buf.writeln('NETWORK');
      buf.writeln(thinDivider);
      final netRecords = networkProfiler!.records;
      if (netRecords.isEmpty) {
        buf.writeln('  No network requests recorded');
      } else {
        buf.writeln('  Total Requests  : ${netRecords.length}');
        buf.writeln('  Slow (> 1s)     : ${networkProfiler!.slowRequests.length}');
        buf.writeln('  Failed          : ${networkProfiler!.failedRequests.length}');
        for (final r in networkProfiler!.slowRequests.take(3)) {
          buf.writeln('  ${r.method} ${r.url}');
          buf.writeln('    → ${r.durationMs.toStringAsFixed(0)}ms  status: ${r.statusCode ?? "?"}');
        }
      }
      buf.writeln('  Summary: ${networkProfiler!.plainEnglishSummary}');
      buf.writeln();
    }

    // ── ASYNC ───────────────────────────────────────────────
    if (asyncProfiler != null) {
      buf.writeln('ASYNC OPERATIONS');
      buf.writeln(thinDivider);
      final asyncRecords = asyncProfiler!.records;
      if (asyncRecords.isEmpty) {
        buf.writeln('  No async operations recorded');
      } else {
        buf.writeln('  Total Operations : ${asyncRecords.length}');
        buf.writeln('  Slow             : ${asyncProfiler!.slowOperations.length}');
        buf.writeln('  Failed           : ${asyncProfiler!.failedOperations.length}');
        for (final r in asyncProfiler!.slowOperations.take(3)) {
          buf.writeln('  ${r.name}: ${r.duration.inMilliseconds}ms');
        }
      }
      buf.writeln('  Summary: ${asyncProfiler!.plainEnglishSummary}');
      buf.writeln();
    }

    // ── SUGGESTIONS ─────────────────────────────────────────
    buf.writeln('WHAT TO FIX');
    buf.writeln(divider);
    _writeSuggestions(buf, grader, networkProfiler, asyncProfiler);
    buf.writeln(divider);
    buf.writeln('Generated by flutter_perf_guard v1.0.0');
    buf.writeln(divider);

    return buf.toString();
  }

  void _writeSuggestions(
      StringBuffer buf,
      PerformanceGrader grader,
      NetworkProfiler? net,
      AsyncProfiler? async_,
      ) {
    int count = 0;

    // Frame
    if (grader.gradeFrames().score <= 3) {
      count++;
      buf.writeln('$count. FRAMES — ${grader.frameSummary()}');
      if (frameProfiler.jankRate > 0.05) {
        buf.writeln('   → Add RepaintBoundary around expensive widgets');
        buf.writeln('   → Use const constructors on static widgets');
      }
      buf.writeln();
    }

    // Rebuilds
    final excessive = rebuildTracker.excessiveRebuilds;
    for (final m in excessive.take(3)) {
      count++;
      buf.writeln(
          '$count. REBUILD — ${m.widgetType} rebuilding '
              '${m.rebuildsPerSecond.toStringAsFixed(0)}x/sec');
      if (m.location.fileInfo != null) {
        buf.writeln('   File: ${m.location.fileInfo}');
      }
      if (m.location.ancestorPath != null) {
        buf.writeln('   Location: ${m.location.ancestorPath}');
      }
      buf.writeln('   → Add const or use ValueListenableBuilder');
      buf.writeln();
    }

    // Memory
    if (grader.gradeMemory().score <= 3) {
      count++;
      buf.writeln('$count. MEMORY — ${grader.memorySummary()}');
      buf.writeln('   → Check dispose() calls on controllers and subscriptions');
      buf.writeln();
    }

    // Network
    if (net != null) {
      for (final r in net.slowRequests.take(2)) {
        count++;
        buf.writeln(
            '$count. NETWORK — ${r.method} ${r.url} took ${r.durationMs.toStringAsFixed(0)}ms');
        buf.writeln('   → Cache this response or show a loading indicator');
        buf.writeln();
      }
    }

    // Async
    if (async_ != null) {
      for (final r in async_.slowOperations.take(2)) {
        count++;
        buf.writeln(
            '$count. ASYNC — "${r.name}" took ${r.duration.inMilliseconds}ms');
        buf.writeln('   → Run in a background isolate or cache the result');
        buf.writeln();
      }
    }

    if (count == 0) {
      buf.writeln('✅ No issues found — your app is performing well!');
      buf.writeln();
    }
  }

  static String _center(String text, int width) {
    if (text.length >= width) return text;
    final pad = (width - text.length) ~/ 2;
    return ' ' * pad + text;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}