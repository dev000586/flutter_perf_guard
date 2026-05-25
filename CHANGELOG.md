# Changelog

All notable changes to `flutter_perf_guard` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] – 2026-05-21

### Added

#### Core Infrastructure
- `DiagnosticsEventBus` – centralized RxDart `PublishSubject`-backed event bus
  with typed streams (`frameEvents`, `memoryEvents`, `rebuildEvents`,
  `jankEvents`, `criticalEvents`)
- `PerformanceEvent` abstract base class with `id`, `timestamp`, `source`,
  `severity` fields
- `EventSeverity` enum (`info`, `warning`, `critical`)
- `PerfGuardConfig` configuration value object with presets (`minimal`, `full`)
- `PerfGuard` singleton entry point with lifecycle management (`initialize`,
  `pause`, `resume`, `dispose`)

#### Frame Profiling
- `FrameProfiler` – hooks into `SchedulerBinding.addTimingsCallback` for
  zero-overhead per-frame metrics collection
- `FrameMetrics` value object with build/raster/total durations, FPS,
  `buildFraction`, `rasterFraction`
- `FrameEvent` typed event with `isJank` and `isSlow` flags
- Rolling frame history buffer (configurable size)
- Current FPS with configurable sliding window size

#### Jank Detection
- `JankEvent` emitted when ≥ N consecutive jank frames detected
- Configurable `jankThreshold` (default 16ms) and
  `consecutiveJankFramesThreshold` (default 3)
- Dropped frame count estimation
- Worst and average frame duration in jank sequence

#### Memory Profiling
- `MemoryProfiler` – periodic `developer.NativeRuntime.memoryUsage` sampling
- `MemoryMetrics` value object with heap used/capacity, external, RSS, GC count
- `MemoryEvent` with `leakSuspected` flag and `allocationDelta`
- Leak detection via 10-sample sliding-window linear regression
  (slope > 512 KB/sample triggers alert)
- Configurable `memorySamplingInterval`, `memoryWarningThreshold`,
  `memoryCriticalThreshold`

#### Rebuild Tracking
- `RebuildTracker` – debug-only instrumentation via
  `debugOnRebuildDirtyWidget`
- `RebuildMetrics` with rebuild count, total/average time, rebuild rate,
  `hasRepaintBoundary`, `triggeredBySetState`
- `RebuildEvent` with `isUnnecessary` detection heuristic
- Hot widget ranking (top 20 by rebuild count)
- Excessive rebuild detection (> 60 rebuilds/s)
- Automatic pruning of old widget records

#### Widget Location Tracking
- `RebuildLocation` – captures file name, line number, and full ancestor path
  for rebuilding widgets (debug mode only)
- `RebuildMetrics.location` field automatically captured on first rebuild
- Ancestor path collection via `visitAncestorElements`
- Debug-only file extraction support
- Release/profile mode fallback note:
  `"run in debug mode to see file location"`

#### Timeline Recording
- `TimelineRecorder` – subscribes to all events and maintains circular buffer
- Configurable `maxEntries`
- `exportJson(pretty: bool)` for DevTools-compatible output
- `entriesByType()` filtering helper

#### Benchmark Engine
- `BenchmarkSuite` with `add()` (sync) and `addAsync()` methods
- `BenchmarkEntry` supporting sync and async bodies
- `BenchmarkRunner` with configurable warmup and measured run counts
- `BenchmarkResult` with mean, median, p95, p99, min, max, stddev, ops/s
- `runAll()` for multi-suite execution
- Full `toJson()` serialization

#### Startup Analysis
- `StartupAnalyzer` with milestone tracking:
  `markAppStart`, `markFirstFrame`, `markNavigatorReady`,
  `markDataLoaded`, `markInteractive`
- `timeToFirstFrame`
- `timeToInteractive`

#### Navigation Tracking
- `NavigationTracker` extends `NavigatorObserver`
- Records push/pop/replace transitions with duration
- `isSlow` flag for transitions > 300ms

#### Network Request Profiling
- `NetworkProfiler` – hooks into `HttpOverrides.global`
  to intercept app HTTP traffic
- Records URL, method, status code, duration, response size,
  timestamp, and errors
- `slowRequests` (> 1 second)
- `failedRequests` (status ≥ 400 or thrown errors)
- Human-readable summaries with optimization suggestions
- Optional enablement via
  `PerfGuardConfig(enableNetworkProfiler: true)`

#### Async Operation Profiling
- `AsyncProfiler` – tracks named sync/async operations
- `track()` and `trackSync()` wrappers
- Records duration, timestamps, and failures
- Slow operation detection via configurable threshold
- Human-readable summaries with optimization suggestions

#### Image Cache Analysis
- `ImageCacheAnalyzer` – reads
  `PaintingBinding.instance.imageCache`
- Reports:
    - current image count
    - live image count
    - cache size
    - usage percentage
- `trimCacheTo(int maxBytes)`
- `clearCache()`
- Included in exports automatically

#### Performance Grading
- `PerformanceGrader` – grades categories A–F with emoji indicators
- Categories:
    - Frames
    - Memory
    - Rebuilds
    - Navigation
- Overall grade derived from worst category
- Human-readable summaries:
    - `frameSummary()`
    - `memorySummary()`
    - `rebuildSummary()`
    - `navigationSummary()`

#### Visualization
- `PerfGuardOverlay` – lightweight in-app HUD showing:
    - FPS
    - build/raster durations
    - memory
    - jank alerts
- Overlay rendered via `CustomPainter`
- `OverlayAlignment` enum:
    - topLeft
    - topRight
    - bottomLeft
    - bottomRight

- `DiagnosticsDashboard` full-screen diagnostics UI with tabs:
    - FRAMES
    - MEMORY
    - REBUILDS
    - LOG

- `_FrameChartPainter`
- `_MemoryChartPainter`

#### Export & Reporting
- `ProfilingReport` full-session snapshot model
- `ReportExporter`
- JSON export support
- Plain-text `.txt` report generation
- `ReportFormat` enum:
    - `text`
    - `json`
- Optimization suggestion generation:
    - repaint boundary suggestions
    - rebuild reduction suggestions
    - memory pressure warnings
- Rebuild reports include file locations and ancestor paths
- `autoExportOnCritical` option

#### File Writing
- Conditional import pair:
    - `file_writer.dart`
    - `file_writer_web.dart`
- Native export via `path_provider`
- Web fallback returns content string directly

#### Analysis Models
- `JankReport` + `JankSegment`
- `RepaintReport` + `RepaintZone`
- `LayoutReport` + `LayoutHotspot`

#### Tests
- Unit tests:
    - `FrameMetrics`
    - `MemoryMetrics`
    - `RebuildMetrics`
    - `DiagnosticsEventBus`
    - `BenchmarkResult`

- Rendering tests:
    - `PerfGuardOverlay`

- Stress tests:
    - event bus throughput
    - concurrent subscribers
    - timeline buffer limits
    - benchmark correctness

#### Documentation
- `README.md`
- `doc/architecture_guide.md`
- `doc/profiling_guide.md`
- `doc/optimization_guide.md`
- `doc/benchmark_guide.md`
- `doc/diagnostics_guide.md`

#### Example App
- Overlay HUD demo
- Dashboard navigation demo
- Jank simulation
- Memory pressure simulation
- Rebuild storm simulation
- Benchmark execution demo
- Report export demo

### Platform Support
- Android ✅
- iOS ✅
- Web ✅
- macOS ✅
- Windows ✅
- Linux ✅

