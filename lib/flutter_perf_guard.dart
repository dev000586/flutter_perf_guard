/// flutter_perf_guard
///
/// Enterprise-grade Flutter performance analysis, debugging, profiling,
/// and optimization toolkit for production-scale Flutter applications.
library flutter_perf_guard;

// ─── Analysis Results ────────────────────────────────────────────────────────
export 'src/analysis/jank/jank_report.dart';
export 'src/analysis/layout/layout_report.dart';
export 'src/analysis/repaint/repaint_report.dart';
// ─── Benchmark ───────────────────────────────────────────────────────────────
export 'src/benchmark/benchmark_result.dart';
export 'src/benchmark/benchmark_suite.dart';
// ─── Core Models & Events ────────────────────────────────────────────────────
export 'src/core/bus/diagnostics_event_bus.dart';
export 'src/core/events/frame_event.dart';
export 'src/core/events/jank_event.dart';
export 'src/core/events/memory_event.dart';
export 'src/core/events/performance_event.dart';
export 'src/core/events/rebuild_event.dart';
// ─── Export / Reports ────────────────────────────────────────────────────────
export 'src/export/profiling_report.dart';
export 'src/export/report_exporter.dart';
// ─── Profiling Models ────────────────────────────────────────────────────────
export 'src/profiling/frame/frame_metrics.dart';
export 'src/profiling/memory/memory_metrics.dart';
export 'src/profiling/rebuild/rebuild_metrics.dart';
// ─── Public API Layer ────────────────────────────────────────────────────────
export 'src/public_api/benchmark_runner.dart';
export 'src/public_api/diagnostics_dashboard.dart';
export 'src/public_api/frame_profiler.dart';
export 'src/public_api/memory_profiler.dart';
export 'src/public_api/perf_guard.dart';
export 'src/public_api/perf_guard_config.dart';
export 'src/public_api/performance_monitor.dart';
export 'src/public_api/performance_overlay_widget.dart';
export 'src/public_api/rebuild_tracker.dart';
export 'src/public_api/timeline_recorder.dart';
