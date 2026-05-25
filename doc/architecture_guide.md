# Architecture Guide

## Overview

`flutter_perf_guard` is built on **Clean Architecture** principles with strict
layer separation, SOLID design, and an event-driven core. Every component
communicates through the `DiagnosticsEventBus` — no direct coupling between
profilers, analyzers, or UI.

---

## Layer Map

```
┌─────────────────────────────────────────────────────────┐
│                    Public API Layer                      │
│  PerfGuard · PerformanceMonitor · FrameProfiler         │
│  MemoryProfiler · RebuildTracker · BenchmarkRunner      │
│  PerfGuardOverlay · DiagnosticsDashboard                │
├─────────────────────────────────────────────────────────┤
│              Performance Monitoring Engine               │
│  FrameProfiler (SchedulerBinding hook)                  │
│  MemoryProfiler (NativeRuntime sampling)                │
│  RebuildTracker (debugOnRebuildDirtyWidget)             │
├─────────────────────────────────────────────────────────┤
│               Rendering Diagnostics Layer                │
│  RepaintBoundaryAnalyzer · OverdrawAnalyzer             │
│  LayoutPassTracker · ImageRenderAnalyzer                │
├─────────────────────────────────────────────────────────┤
│                 Memory Analysis Engine                   │
│  Heap sampler · Leak detector (linear regression)       │
│  GC tracker · Allocation delta tracker                  │
├─────────────────────────────────────────────────────────┤
│                    Profiling Engine                      │
│  FrameMetrics · RebuildMetrics · MemoryMetrics          │
│  JankReport · RepaintReport · LayoutReport              │
├─────────────────────────────────────────────────────────┤
│                  Visualization Layer                     │
│  PerfGuardOverlay · DiagnosticsDashboard                │
│  FrameBarChart · MemoryLineChart · RebuildHeatmap       │
├─────────────────────────────────────────────────────────┤
│               Platform Integration Layer                 │
│  Android · iOS · Web · macOS · Windows · Linux          │
│  (plugin stubs + NativeRuntime abstraction)             │
├─────────────────────────────────────────────────────────┤
│                 Core Infrastructure                      │
│  DiagnosticsEventBus (RxDart PublishSubject)            │
│  PerformanceEvent hierarchy · PerfGuardConfig           │
└─────────────────────────────────────────────────────────┘
```

---

## Core Design Patterns

### 1. Observer / Event-Driven Architecture

All inter-component communication flows through `DiagnosticsEventBus`:

```
FrameProfiler ──emit(FrameEvent)──▶ DiagnosticsEventBus
                                           │
                        ┌──────────────────┼──────────────────┐
                        ▼                  ▼                  ▼
              DiagnosticsDashboard  PerformanceMonitor  TimelineRecorder
```

Subscribers choose exactly which event types they care about:

```dart
bus.frameEvents.listen(...)    // Only FrameEvents
bus.jankEvents.listen(...)     // Only JankEvents
bus.criticalEvents.listen(...) // Warning + Critical severity
bus.allEvents.listen(...)      // Everything
```

**Benefit:** Components are fully decoupled. Adding a new subscriber
(e.g. a Slack alerter, DevTools extension) requires zero changes to existing code.

---

### 2. Singleton with Dependency Injection

`PerfGuard` is a singleton that owns the object graph and passes
dependencies into each component via constructor injection:

```dart
// Inside PerfGuard._init()
_frameProfiler = FrameProfiler(config: _config, bus: _bus);
_memoryProfiler = MemoryProfiler(config: _config, bus: _bus);
_rebuildTracker = RebuildTracker(config: _config, bus: _bus);
```

- No service locator or global variables on individual components
- Every class receives its dependencies at construction time
- Easy to unit-test by injecting mocks

---

### 3. Adapter Pattern (Platform Layer)

Platform-specific capabilities (native memory, GPU stats) are accessed
through an adapter interface so the core remains platform-agnostic:

```dart
abstract class PlatformMemoryAdapter {
  int get heapUsedBytes;
  int get heapCapacityBytes;
  int get externalBytes;
  int get rssBytes;
}

// Implementations per platform
class NativeMemoryAdapter implements PlatformMemoryAdapter { ... }
class WebMemoryAdapter implements PlatformMemoryAdapter { ... }
```

---

### 4. Modular Profiler Plugins

Each profiler implements a common lifecycle interface:

```dart
abstract class ProfilerPlugin {
  Future<void> start();
  Future<void> stop();
  void pause();
  void resume();
  Map<String, dynamic> toJson();
}
```

New profilers can be added without touching `PerfGuard`:

```dart
class CustomNetworkProfiler implements ProfilerPlugin {
  // ... implementation
}
```

---

### 5. Value Objects for Metrics

All metric types (`FrameMetrics`, `MemoryMetrics`, `RebuildMetrics`) are:

- **Immutable** (`final` fields, `const` constructors where possible)
- **Equatable** (value-based equality for diffing)
- **Self-serializing** (`toJson()` method)
- **Self-describing** (`toString()` with key values)

This makes them safe to pass across isolates and easy to cache.

---

## Event Hierarchy

```
PerformanceEvent (abstract)
├── FrameEvent        – per-frame build/raster timing
├── MemoryEvent       – heap snapshot + leak flag
├── RebuildEvent      – per-widget rebuild record
└── JankEvent         – consecutive jank frame sequence
```

Every event carries:
- `id` – unique string identifier
- `timestamp` – capture time
- `source` – originating component name
- `severity` – info / warning / critical

---

## DiagnosticsEventBus Internals

```
PublishSubject<PerformanceEvent>
         │
         ├── .whereType<FrameEvent>()    → frameEvents stream
         ├── .whereType<MemoryEvent>()   → memoryEvents stream
         ├── .whereType<RebuildEvent>()  → rebuildEvents stream
         ├── .whereType<JankEvent>()     → jankEvents stream
         └── .where(severity >= warning) → criticalEvents stream
```

`PublishSubject` (from RxDart) is used instead of `StreamController`
because it supports multiple independent subscribers, each receiving
every event — critical for the dashboard + timeline recorder + alert
system all listening simultaneously.

---

## Thread Safety

- `DiagnosticsEventBus.emit()` is called from the UI thread (frame callbacks)
- `MemoryProfiler._takeSample()` is called from a `Timer` (also UI thread)
- `RebuildTracker._onRebuild()` is called from `debugOnRebuildDirtyWidget` (UI thread)
- Stream subscriptions are dispatched on the zone where they are created

All operations are **single-threaded on the Dart event loop**. No explicit
locking is needed. Background isolate communication is handled via `SendPort`
when `enableAsyncProfiler` is active.

---

## Configuration Flow

```
PerfGuardConfig
      │
      ▼
PerfGuard._init(config)
      │
      ├── FrameProfiler(config: config, ...)
      │         └── Uses: jankThreshold, frameHistorySize, consecutiveJankFramesThreshold
      │
      ├── MemoryProfiler(config: config, ...)
      │         └── Uses: memorySamplingInterval, memoryWarningThreshold
      │
      ├── RebuildTracker(config: config, ...)
      │         └── Uses: rebuildHistorySize, excessiveRebuildRatePerSecond
      │
      └── ReportExporter(config: config, ...)
                └── Uses: exportDirectory, autoExportOnCritical
```

---

## Adding a New Profiler

1. Create `lib/src/profiling/my_feature/my_metrics.dart` (value object)
2. Create `lib/src/monitoring/my_feature/my_profiler.dart` (implements lifecycle)
3. Create `lib/src/core/events/my_event.dart` (extends `PerformanceEvent`)
4. Add a toggle to `PerfGuardConfig`
5. Wire up in `PerfGuard._init()`
6. Export from `lib/flutter_perf_guard.dart`
7. Add tests in `test/unit/`

---

## Dependency Graph

```
PerfGuard
├── DiagnosticsEventBus (singleton, shared)
├── PerfGuardConfig (value object)
├── FrameProfiler
│   └── DiagnosticsEventBus (emit)
├── MemoryProfiler
│   └── DiagnosticsEventBus (emit)
├── RebuildTracker
│   ├── DiagnosticsEventBus (emit)
│   └── RebuildLocation (captures per widget, debug only)
├── NetworkProfiler                       
│   └── HttpOverrides (global intercept)
├── AsyncProfiler                         
│   └── DiagnosticsEventBus (emit)
├── ImageCacheAnalyzer                    
│   └── PaintingBinding.imageCache (read-only)
├── TimelineRecorder
│   └── DiagnosticsEventBus (subscribe)
├── PerformanceMonitor
│   └── DiagnosticsEventBus (subscribe)
├── PerformanceGrader                     
│   ├── FrameProfiler (read-only)
│   ├── MemoryProfiler (read-only)
│   ├── RebuildTracker (read-only)
│   └── NavigationTracker (read-only)
├── StartupAnalyzer
├── NavigationTracker (NavigatorObserver)
└── ReportExporter
├── FrameProfiler (read-only)
├── MemoryProfiler (read-only)
├── RebuildTracker (read-only)
├── NavigationTracker (read-only)       
├── NetworkProfiler (read-only)    
├── AsyncProfiler (read-only)      
├── ImageCacheAnalyzer (read-only) 
├── PerformanceGrader (computed)   
└── TextFormatter (export)        
```

No circular dependencies. All new components follow the same rule:
profilers emit or expose data, the exporter reads from them.
