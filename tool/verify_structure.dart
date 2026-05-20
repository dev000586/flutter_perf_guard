#!/usr/bin/env dart
// Script to verify the package structure is complete.
// Run from the package root: dart tool/verify_structure.dart

import 'dart:io';

import 'package:flutter/foundation.dart';

const requiredFiles = [
  'pubspec.yaml',
  'README.md',
  'CHANGELOG.md',
  'LICENSE',
  'analysis_options.yaml',
  'lib/flutter_perf_guard.dart',
  // Public API
  'lib/src/public_api/perf_guard.dart',
  'lib/src/public_api/perf_guard_config.dart',
  'lib/src/public_api/performance_monitor.dart',
  'lib/src/public_api/frame_profiler.dart',
  'lib/src/public_api/memory_profiler.dart',
  'lib/src/public_api/rebuild_tracker.dart',
  'lib/src/public_api/timeline_recorder.dart',
  'lib/src/public_api/benchmark_runner.dart',
  'lib/src/public_api/performance_overlay_widget.dart',
  'lib/src/public_api/diagnostics_dashboard.dart',
  // Core
  'lib/src/core/bus/diagnostics_event_bus.dart',
  'lib/src/core/events/performance_event.dart',
  'lib/src/core/events/frame_event.dart',
  'lib/src/core/events/memory_event.dart',
  'lib/src/core/events/rebuild_event.dart',
  'lib/src/core/events/jank_event.dart',
  // Profiling models
  'lib/src/profiling/frame/frame_metrics.dart',
  'lib/src/profiling/memory/memory_metrics.dart',
  'lib/src/profiling/rebuild/rebuild_metrics.dart',
  // Monitoring
  'lib/src/monitoring/startup/startup_analyzer.dart',
  'lib/src/monitoring/navigation/navigation_tracker.dart',
  // Analysis
  'lib/src/analysis/jank/jank_report.dart',
  'lib/src/analysis/repaint/repaint_report.dart',
  'lib/src/analysis/layout/layout_report.dart',
  // Export
  'lib/src/export/profiling_report.dart',
  'lib/src/export/report_exporter.dart',
  // Benchmark
  'lib/src/benchmark/benchmark_suite.dart',
  'lib/src/benchmark/benchmark_result.dart',
  // Tests
  'test/unit/frame_metrics_test.dart',
  'test/unit/memory_metrics_test.dart',
  'test/unit/rebuild_metrics_test.dart',
  'test/unit/jank_event_test.dart',
  'test/unit/timeline_recorder_test.dart',
  'test/unit/perf_guard_config_test.dart',
  'test/unit/diagnostics_event_bus_test.dart',
  'test/unit/navigation_startup_test.dart',
  'test/rendering/overlay_test.dart',
  'test/benchmark/benchmark_runner_test.dart',
  'test/concurrency/memory_concurrency_test.dart',
  'test/stress/stress_test.dart',
  // Docs
  'doc/architecture_guide.md',
  'doc/profiling_guide.md',
  'doc/optimization_guide.md',
  'doc/benchmark_guide.md',
  'doc/diagnostics_guide.md',
  // Example
  'example/pubspec.yaml',
  'example/lib/main.dart',
];

void main() {
  final root = Directory.current;
  int missing = 0;
  int found = 0;

  for (final path in requiredFiles) {
    final file = File('${root.path}/$path');
    if (file.existsSync()) {
      if (kDebugMode) {
        print('  ✅  $path');
      }
      found++;
    } else {
      if (kDebugMode) {
        print('  ❌  MISSING: $path');
      }
      missing++;
    }
  }

  if (kDebugMode) {
    print('\n─────────────────────────────────');
  }
  if (kDebugMode) {
    print('Found:   $found / ${requiredFiles.length}');
  }
  if (missing > 0) {
    if (kDebugMode) {
      print('Missing: $missing');
    }
    exit(1);
  } else {
    if (kDebugMode) {
      print('All files present. Package structure verified. ✅');
    }
  }
}
