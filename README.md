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
| **Rebuild Tracking** | Widget rebuild frequency, file name + line (debug), ancestor path, hot-widget ranking |
| **Network Profiling** | HTTP request timing, status, size, slow/failed detection via HttpOverrides |
| **Async Profiling** | Named async operation tracking with slow/failed detection |
| **Image Cache Analysis** | Cache hit rate, size pressure, plain English fix suggestions |
| **Performance Grading** | A–F grade per category with plain English summaries |
| **Real-time Dashboard** | Full-screen diagnostics dashboard with frames, memory, rebuilds, event log |
| **Performance Overlay** | Lightweight HUD with FPS, build/raster times, memory, jank alerts |
| **Timeline Recording** | Bounded circular-buffer timeline with JSON export |
| **Benchmark Engine** | Statistical micro-benchmark runner (mean, median, p95, p99, stddev) |
| **Startup Analysis** | App-start to interactive milestone tracking |
| **Navigation Tracking** | Route transition duration monitoring |
| **Report Export** | Human-readable `.txt` report + JSON snapshot with grades and file locations |
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
      enableRebuildTracker: true,     // debug mode only
      enableJankDetector: true,
      enableNetworkProfiler: true,    // intercepts all HTTP requests
      enableAsyncProfiler: true,      // track named async operations
      verbose: true,
    ),
  );

  runApp(const MyApp());
}
```

### 2. Track async operations (optional)

```dart
// Wrap any async call to measure it:
final products = await PerfGuard.instance.asyncProfiler.track(
  'fetch_products',
  () => api.getProducts(),
);
```

### 3. Export a readable report

```dart
// Exports a human-readable .txt file to app documents directory
final path = await PerfGuard.instance.exportReport(
  format: ReportFormat.text,
);
print('Report saved to: $path');
```

### 4. Add the Overlay HUD

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

### 5. Open the Dashboard

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const DiagnosticsDashboard()),
);
```

### 6. Subscribe to Events

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

### NetworkProfiler

```dart
final np = PerfGuard.instance.networkProfiler;

np.records           // List<NetworkRequestRecord> — all requests
np.slowRequests      // requests taking > 1 second
np.failedRequests    // requests with status >= 400 or errors
np.plainEnglishSummary  // human-readable summary string
```

### AsyncProfiler

```dart
final ap = PerfGuard.instance.asyncProfiler;

// Track any async operation by name:
final result = await ap.track('load_user', () => fetchUser(id));

// Track synchronous expensive work:
final sorted = ap.trackSync('sort_products', () => products.sort(...));

ap.slowOperations      // List<AsyncOperationRecord>
ap.failedOperations    // List<AsyncOperationRecord>
ap.plainEnglishSummary // human-readable summary
ap.reset()
```

### ImageCacheAnalyzer

```dart
final ia = PerfGuard.instance.imageCacheAnalyzer;

final snap = ia.snapshot();
snap.currentCount      // int — cached image count
snap.currentSizeMb     // double — cache size in MB
snap.usagePercent      // double — 0.0–1.0
ia.plainEnglishSummary // human-readable summary
ia.trimCacheTo(50 * 1024 * 1024); // trim to 50MB
ia.clearCache();
```

### PerformanceGrader

```dart
final grader = PerformanceGrader(
  frameProfiler: PerfGuard.instance.frameProfiler,
  memoryProfiler: PerfGuard.instance.memoryProfiler,
  rebuildTracker: PerfGuard.instance.rebuildTracker,
  navigationTracker: PerfGuard.instance.navigationTracker,
);

grader.gradeFrames()    // PerformanceGrade.A / B / C / D / F
grader.gradeMemory()
grader.gradeRebuilds()
grader.overallGrade     // worst category grade
grader.frameSummary()   // "✅ Excellent — 59.8 FPS, no jank detected"
grader.rebuildSummary() // "❌ ProductCard rebuilding 94x/sec\n   File: lib/screens/home_screen.dart:142"
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
│       │   └── rebuild/
│       │       ├── rebuild_metrics.dart
│       │       └── rebuild_location.dart
│       ├── monitoring/                  # Specialized Monitors
│       │   ├── startup/startup_analyzer.dart
│       │   └── navigation/navigation_tracker.dart
│       │   ├── network/network_profiler.dart 
│       │   ├── async/async_profiler.dart      
│       │   └── image/image_cache_analyzer.dart 
│       ├── analysis/                    # Analysis Reports
│       │   ├── grader/performance_grader.dart
│       │   ├── jank/jank_report.dart
│       │   ├── repaint/repaint_report.dart
│       │   └── layout/layout_report.dart
│       ├── export/                      # Report Generation
│       │   ├── profiling_report.dart
│       │   └── report_exporter.dart
│       │   ├── file_writer.dart               
│       │   ├── file_writer_web.dart           
│       │   └── formatters/
│       │       └── text_formatter.dart        
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

## Export Formats

### Human-Readable Text (default)

```dart
final path = await PerfGuard.instance.exportReport(
  format: ReportFormat.text,
);
```

```text
Output example:
════════════════════════════════════════════════════════════
flutter_perf_guard 
Performance Report
2024-06-10 10:30:00
════════════════════════════════════════════════════════════
OVERALL GRADE : 🟡 C
FRAMES   🟢 A
────────────────────────────────────────────────────────────
Average FPS      : 59.8
Jank Events      : 0
Worst Frame      : 9ms  (budget: 16ms)
Summary          : ✅ Excellent — 59.8 FPS, no jank detected
MEMORY   🟢 A
────────────────────────────────────────────────────────────
Heap Used        : 42.1MB
Heap Capacity    : 180.0MB
Heap Usage       : 23%
Summary          : ✅ Healthy — 42.1MB heap (23% used)
REBUILDS   🔴 F
────────────────────────────────────────────────────────────
Top Offenders:

ProductCard             94/sec ← EXCESSIVE
File: lib/screens/home_screen.dart:142
Path: HomeScreen > Column > ListView > ProductCard
CounterWidget           58/sec ← EXCESSIVE
File: lib/widgets/counter.dart:38

WHAT TO FIX
════════════════════════════════════════════════════════════

REBUILD — ProductCard rebuilding 94x/sec
File: lib/screens/home_screen.dart:142
Location: HomeScreen > Column > ListView > ProductCard
→ Add const or use ValueListenableBuilder
REBUILD — CounterWidget rebuilding 58x/sec
File: lib/widgets/counter.dart:38
→ Add const or use ValueListenableBuilder
════════════════════════════════════════════════════════════
```

### JSON (structured data)

```dart
final path = await PerfGuard.instance.exportReport(
  format: ReportFormat.json,
);
```

```json
{
  "grade": {
    "overall": "C",
    "frames":   { "grade": "A", "summary": "✅ Excellent — 59.8 FPS" },
    "memory":   { "grade": "A", "summary": "✅ Healthy — 42.1MB" },
    "rebuilds": { "grade": "F", "summary": "❌ 2 widget(s) rebuilding excessively" }
  },
  "rebuild": {
    "hotWidgets": [
      {
        "widgetType": "ProductCard",
        "rebuildsPerSecond": 94.0,
        "location": {
          "fileInfo": "lib/screens/home_screen.dart:142",
          "ancestorPath": "HomeScreen > Column > ListView > ProductCard"
        }
      }
    ]
  },
  "optimizationSuggestions": [
    {
      "category": "rebuild",
      "widget": "ProductCard",
      "rebuildsPerSec": "94",
      "file": "lib/screens/home_screen.dart:142",
      "location": "HomeScreen > Column > ListView > ProductCard",
      "message": "ProductCard rebuilding 94x/sec — add const or use RepaintBoundary"
    }
  ]
}
```

---

## License

MIT © 2024 flutter_perf_guard contributors. See [LICENSE](LICENSE).
