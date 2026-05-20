# Changelog

All notable changes to `flutter_perf_guard` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] – 2026-05-21

### Added

#### Core Infrastructure
- `DiagnosticsEventBus` – centralized RxDart `PublishSubject`-backed event bus
  with typed streams (`frameEvents`, `memoryEvents`, `rebuildEvents`, `jankEvents`,
  `criticalEvents`)
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
- `RebuildTracker` – debug-only instrumentation via `debugOnRebuildDirtyWidget`
- `RebuildMetrics` with rebuild count, total/average time, rebuild rate,
  `hasRepaintBoundary`, `triggeredBySetState`
- `RebuildEvent` with `isUnnecessary` detection heuristic
- Hot widget ranking (top 20 by rebuild count)
- Excessive rebuild detection (> 60 rebuilds/s)
- Automatic pruning of old widget records

#### Timeline Recording
- `TimelineRecorder` – subscribes to all events and maintains circular buffer
- Configurable `maxEntries`
- `exportJson(pretty: bool)` for DevTools-compatible output
- `entriesByType()` filtering helper

#### Benchmark Engine
- `BenchmarkSuite` with `add()` (sync) and `addAsync()` methods
- `BenchmarkEntry` supporting both sync and async bodies
- `BenchmarkRunner` with configurable warmup and measured run counts
- `BenchmarkResult` with mean, median, p95, p99, min, max, stddev, ops/s
- `runAll()` for multi-suite execution
- Full `toJson()` serialization

#### Startup Analysis
- `StartupAnalyzer` with milestone tracking:
  `markAppStart`, `markFirstFrame`, `markNavigatorReady`,
  `markDataLoaded`, `markInteractive`
- `timeToFirstFrame` and `timeToInteractive` accessors

#### Navigation Tracking
- `NavigationTracker` extends `NavigatorObserver`
- Records push/pop/replace transitions with duration
- `isSlow` flag for transitions > 300ms

#### Visualization
- `PerfGuardOverlay` – lightweight HUD widget showing FPS, build/raster times,
  memory, and jank alerts. Renders via `CustomPainter`; zero widget rebuilds
  outside of event receipt
- `OverlayAlignment` enum (topLeft, topRight, bottomLeft, bottomRight)
- `DiagnosticsDashboard` – full-screen Flutter widget with 4 tabs:
  - **FRAMES** – stat cards + `CustomPainter` bar chart
  - **MEMORY** – heap progress bar + `CustomPainter` line chart
  - **REBUILDS** – sorted list with excessive rebuild highlighting
  - **LOG** – scrollable event log
- `_FrameChartPainter` – efficient `CustomPainter` with 16ms grid line
- `_MemoryChartPainter` – area chart with fill gradient

#### Export & Reporting
- `ProfilingReport` value object with full session snapshot
- `ReportExporter` – assembles snapshots from all profilers
- Auto-generated `optimizationSuggestions` based on thresholds:
  - Jank rate > 5% → RepaintBoundary suggestion
  - Heap > 80% → memory investigation suggestion
  - Excessive rebuilds → const/memoization suggestion
- JSON export to configurable directory (native) or string return (web)
- `autoExportOnCritical` option

#### Analysis Models
- `JankReport` + `JankSegment`
- `RepaintReport` + `RepaintZone`
- `LayoutReport` + `LayoutHotspot`

#### Tests
- Unit tests: `FrameMetrics`, `MemoryMetrics`, `RebuildMetrics`,
  `DiagnosticsEventBus`, `BenchmarkResult`
- Rendering tests: `PerfGuardOverlay` widget tests
- Stress tests: event bus throughput (10,000 events),
  concurrent subscribers, timeline buffer limits,
  `BenchmarkRunner` correctness

#### Documentation
- `README.md` with quick start, API reference, config table, export format
- `doc/architecture_guide.md` – layer map, design patterns, dependency graph
- `doc/profiling_guide.md` – frame, memory, rebuild, timeline, startup
- `doc/optimization_guide.md` – concrete code fixes for each diagnostic type
- `doc/benchmark_guide.md` – statistical best practices, regression testing
- `doc/diagnostics_guide.md` – dashboard reading, event bus patterns,
  per-issue diagnosis flows

#### Example App
- Full example app demonstrating: overlay HUD, dashboard navigation,
  jank simulation, memory pressure simulation, rebuild storm,
  benchmark suite execution, report export

### Platform Support
- Android ✅
- iOS ✅
- Web ✅ (memory export returns JSON string)
- macOS ✅
- Windows ✅
- Linux ✅

---
