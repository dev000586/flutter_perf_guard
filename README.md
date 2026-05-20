# flutter_perf_guard

[![pub.dev](https://img.shields.io/pub/v/flutter_perf_guard.svg)](https://pub.dev/packages/flutter_perf_guard)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.10-blue)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Web%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-green)](https://flutter.dev/multi-platform)

**Enterprise-grade Flutter performance analysis, debugging, profiling, and optimization toolkit for production-scale applications.**

---

## Features

| Category | Feature |
|---|---|
| **Frame Analysis** | Per-frame build/raster timing, rolling FPS, worst-frame detection |
| **Jank Detection** | Consecutive-jank detection, dropped-frame counting, jank events |
| **Memory Profiling** | Heap sampling, leak detection via linear regression, GC tracking |
| **Rebuild Tracking** | Widget rebuild frequency, unnecessary rebuild detection, hot-widget ranking |
| **Real-time Dashboard** | Full-screen diagnostics dashboard with frames, memory, rebuilds, event log |
| **Performance Overlay** | Lightweight HUD with FPS, build/raster times, memory, jank alerts |
| **Timeline Recording** | Bounded circular-buffer timeline with JSON export |
| **Benchmark Engine** | Statistical micro-benchmark runner (mean, median, p95, p99, stddev) |
| **Startup Analysis** | App-start to interactive milestone tracking |
| **Navigation Tracking** | Route transition duration monitoring |
| **Report Export** | JSON snapshot export with automated optimization suggestions |
| **Event Bus** | Centralized typed `DiagnosticsEventBus` with RxDart streams |

---

## Installation

```yaml
dependencies:
  flutter_perf_guard: ^1.0.0
```

---

## Quick Start

### 1. Initialize

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PerfGuard.initialize(
    config: const PerfGuardConfig(
      enableFrameProfiler: true,
      enableMemoryProfiler: true,
      enableRebuildTracker: true,
      enableJankDetector: true,
      enableDashboard: true,
      verbose: true,
    ),
  );

  runApp(const MyApp());
}
```

### 2. Add the Overlay HUD

Wrap your root widget (or any subtree) with `PerfGuardOverlay`:

```dart
MaterialApp(
  home: PerfGuardOverlay(
    showFps: true,
    showMemory: true,
    showJankAlert: true,
    child: MyHomePage(),
  ),
)
```

### 3. Open the Dashboard

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const DiagnosticsDashboard()),
);
```

### 4. Subscribe to Events

```dart
final bus = DiagnosticsEventBus.instance;

// All frame events
bus.frameEvents.listen((e) {
  print('Frame #${e.metrics.frameNumber}: ${e.metrics.fps.toStringAsFixed(1)} FPS');
});

// Jank alerts only
bus.jankEvents.listen((e) {
  print('JANK: ${e.droppedFrames} dropped frames');
});

// All critical events
bus.criticalEvents.listen((e) {
  print('CRITICAL: ${e.source} – ${e.severity.label}');
});
```

---

## Configuration

```dart
const PerfGuardConfig(
  // Module toggles
  enableFrameProfiler: true,
  enableMemoryProfiler: true,
  enableRebuildTracker: true,   // debug mode only
  enableJankDetector: true,
  enableDashboard: true,
  enableStartupAnalyzer: true,
  enableNavigationTracker: true,
  enableAsyncProfiler: false,
  enableNetworkProfiler: false,

  // Thresholds
  jankThreshold: Duration(milliseconds: 16),
  slowFrameThreshold: Duration(milliseconds: 8),
  consecutiveJankFramesThreshold: 3,
  memoryWarningThreshold: 0.80,   // 80% heap
  memoryCriticalThreshold: 0.92,

  // Sampling
  memorySamplingInterval: Duration(seconds: 2),
  frameHistorySize: 300,

  // Export
  autoExportOnCritical: false,
  exportDirectory: '/tmp/perf_guard_reports',

  verbose: false,
)
```

Presets available:

```dart
PerfGuardConfig.minimal  // Frame + jank only, lowest overhead
PerfGuardConfig.full     // All modules enabled
```

---

## API Reference

### PerfGuard (Singleton)

```dart
// Initialize
await PerfGuard.initialize(config: myConfig);

// Access sub-components
PerfGuard.instance.frameProfiler
PerfGuard.instance.memoryProfiler
PerfGuard.instance.rebuildTracker
PerfGuard.instance.timelineRecorder
PerfGuard.instance.startupAnalyzer
PerfGuard.instance.navigationTracker

// Export
final path = await PerfGuard.instance.exportReport();
final map = await PerfGuard.instance.takeSnapshot();

// Pause/resume (e.g. on background)
PerfGuard.instance.pause();
PerfGuard.instance.resume();
```

### FrameProfiler

```dart
final fp = PerfGuard.instance.frameProfiler;

fp.currentFps()          // rolling 60-frame average
fp.averageFrameTime      // Duration
fp.jankRate              // 0.0–1.0
fp.jankFrames            // int
fp.totalFrames           // int
fp.history               // List<FrameMetrics>
fp.worstFrameDuration    // Duration
```

### MemoryProfiler

```dart
final mp = PerfGuard.instance.memoryProfiler;

mp.latest          // MemoryMetrics?
mp.history         // List<MemoryMetrics>
mp.averageHeapMb   // double
mp.peakHeapBytes   // int
```

### RebuildTracker

```dart
final rt = PerfGuard.instance.rebuildTracker;

rt.allMetrics          // List<RebuildMetrics>
rt.hotWidgets          // Top 20 by rebuild count
rt.excessiveRebuilds   // Widgets rebuilding > 60/s
rt.reset()
```

### TimelineRecorder

```dart
final rec = PerfGuard.instance.timelineRecorder;

rec.start(maxEntries: 5000);
// ... your app runs ...
rec.stop();

final json = rec.exportJson(pretty: true);
```

### BenchmarkRunner

```dart
final suite = BenchmarkSuite(name: 'MyBenchmarks')
  ..add('list_sort', () {
    final l = List.generate(1000, (i) => i);
    l.sort();
  })
  ..addAsync('db_query', () async {
    await Future.delayed(const Duration(milliseconds: 5));
  });

const runner = BenchmarkRunner(defaultMeasuredRuns: 20);
final results = await runner.run(suite);

for (final r in results) {
  print('${r.name}: mean=${r.mean.inMilliseconds}ms p95=${r.p95.inMilliseconds}ms');
}
```

---

## Navigation Tracking

Add the observer to your `MaterialApp`:

```dart
MaterialApp(
  navigatorObservers: [
    PerfGuard.instance.navigationTracker,
  ],
  ...
)
```

---

## Architecture

```
flutter_perf_guard/
├── lib/
│   ├── flutter_perf_guard.dart          # Public exports
│   └── src/
│       ├── public_api/                  # Public API Layer
│       │   ├── perf_guard.dart          # Singleton entry point
│       │   ├── perf_guard_config.dart
│       │   ├── performance_monitor.dart
│       │   ├── frame_profiler.dart
│       │   ├── memory_profiler.dart
│       │   ├── rebuild_tracker.dart
│       │   ├── timeline_recorder.dart
│       │   ├── benchmark_runner.dart
│       │   ├── performance_overlay_widget.dart
│       │   └── diagnostics_dashboard.dart
│       ├── core/                        # Core Infrastructure
│       │   ├── bus/diagnostics_event_bus.dart
│       │   └── events/                  # Typed events
│       ├── profiling/                   # Data Models
│       │   ├── frame/frame_metrics.dart
│       │   ├── memory/memory_metrics.dart
│       │   └── rebuild/rebuild_metrics.dart
│       ├── monitoring/                  # Specialized Monitors
│       │   ├── startup/startup_analyzer.dart
│       │   └── navigation/navigation_tracker.dart
│       ├── analysis/                    # Analysis Reports
│       │   ├── jank/jank_report.dart
│       │   ├── repaint/repaint_report.dart
│       │   └── layout/layout_report.dart
│       ├── export/                      # Report Generation
│       │   ├── profiling_report.dart
│       │   └── report_exporter.dart
│       └── benchmark/                   # Benchmark Engine
│           ├── benchmark_suite.dart
│           └── benchmark_result.dart
├── test/
│   ├── unit/
│   ├── rendering/
│   ├── stress/
│   └── benchmark/
└── example/
```

---

## Performance Overhead

`flutter_perf_guard` is designed for zero-cost in release builds:

- `RebuildTracker` is only active in debug mode (uses `debugOnRebuildDirtyWidget`)
- `FrameProfiler` uses Flutter's native `SchedulerBinding.addTimingsCallback`
- `MemoryProfiler` samples on a timer (default 2s interval) – not per-frame
- `PerfGuardOverlay` uses `IgnorePointer` and only rebuilds on event receipt
- All streams are lazy (no work until someone subscribes)

Typical overhead in profile mode: **< 1% CPU, < 2MB RAM**.

---

## Export Format

```json
{
  "sessionId": "session_1718000000000",
  "startTime": "2024-06-10T10:00:00.000Z",
  "frame": {
    "totalFrames": 1200,
    "jankFrames": 12,
    "jankRate": 0.01,
    "currentFps": 59.8,
    "averageFrameTimeMs": 7.2
  },
  "memory": {
    "latestHeapMb": 42.1,
    "peakHeapBytes": 55000000
  },
  "rebuild": {
    "trackedWidgets": 45,
    "excessiveRebuildCount": 2
  },
  "optimizationSuggestions": [
    {
      "category": "rebuild",
      "severity": "warning",
      "message": "2 widget(s) rebuilding excessively. Use const constructors or memoization."
    }
  ]
}
```

---

## License

MIT © 2024 flutter_perf_guard contributors. See [LICENSE](LICENSE).
