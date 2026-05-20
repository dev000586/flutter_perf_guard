# Profiling Guide

## When to Profile

Profile during:
- **Development** – use `PerfGuardConfig.full` with dashboard and overlay
- **QA / staging** – use `PerfGuardConfig.minimal` to catch regressions
- **Production monitoring** – use frame + memory only, disable rebuild tracker
- **Performance investigations** – enable `TimelineRecorder`, reproduce the issue, export

---

## Frame Profiling

### Setup

```dart
await PerfGuard.initialize(
  config: const PerfGuardConfig(
    enableFrameProfiler: true,
    enableJankDetector: true,
    jankThreshold: Duration(milliseconds: 16),    // 60fps budget
    consecutiveJankFramesThreshold: 3,
    frameHistorySize: 300,                        // keep last 300 frames
  ),
);
```

### Reading frame data

```dart
final fp = PerfGuard.instance.frameProfiler;

// Current rolling FPS (last 60 frames)
print('FPS: ${fp.currentFps()}');
print('FPS (30-frame window): ${fp.currentFps(windowSize: 30)}');

// Jank statistics
print('Jank rate: ${(fp.jankRate * 100).toStringAsFixed(1)}%');
print('Jank frames: ${fp.jankFrames} / ${fp.totalFrames}');
print('Worst frame: ${fp.worstFrameDuration.inMilliseconds}ms');

// Frame history for charts
final history = fp.history; // List<FrameMetrics>
for (final frame in history) {
  print('#${frame.frameNumber}: ${frame.totalDuration.inMilliseconds}ms '
      '(build=${frame.buildDuration.inMilliseconds}ms '
      'raster=${frame.rasterDuration.inMilliseconds}ms)');
}
```

### Detecting jank in real-time

```dart
DiagnosticsEventBus.instance.jankEvents.listen((event) {
  print('Jank detected!');
  print('  Consecutive frames: ${event.consecutiveJankFrames}');
  print('  Worst: ${event.worstFrameDuration.inMilliseconds}ms');
  print('  Average: ${event.averageFrameDuration.inMilliseconds}ms');
  print('  Dropped: ${event.droppedFrames} frames');
  print('  Avg FPS: ${event.averageFps.toStringAsFixed(1)}');
});
```

### Understanding build vs raster

| Metric | What it means | Common causes |
|--------|--------------|---------------|
| `buildDuration` high | Widget tree is expensive to build | Deep widget trees, expensive `build()` methods, unnecessary rebuilds |
| `rasterDuration` high | GPU work is expensive | Overdraw, large images, complex clipping, shaders |
| Both high | Everything is slow | Major architectural issue |

---

## Memory Profiling

### Setup

```dart
await PerfGuard.initialize(
  config: const PerfGuardConfig(
    enableMemoryProfiler: true,
    memorySamplingInterval: Duration(seconds: 1),  // sample every second
    memoryWarningThreshold: 0.75,                  // warn at 75% heap
    memoryCriticalThreshold: 0.90,                 // critical at 90%
  ),
);
```

### Reading memory data

```dart
final mp = PerfGuard.instance.memoryProfiler;

final latest = mp.latest;
if (latest != null) {
  print('Heap: ${latest.heapUsedMb.toStringAsFixed(1)}MB '
        '/ ${latest.heapCapacityMb.toStringAsFixed(1)}MB '
        '(${(latest.heapUsagePercent * 100).toStringAsFixed(0)}%)');
  print('External: ${latest.externalMb.toStringAsFixed(1)}MB');
  print('RSS: ${latest.rssMb.toStringAsFixed(1)}MB');
}

print('Average heap: ${mp.averageHeapMb.toStringAsFixed(1)}MB');
print('Peak heap: ${mp.peakHeapBytes ~/ (1024 * 1024)}MB');
```

### Leak detection events

The `MemoryProfiler` uses a 10-sample sliding-window linear regression.
If the heap grows consistently by > 512 KB per sample interval with no GC relief,
a `MemoryEvent` with `leakSuspected = true` is emitted.

```dart
DiagnosticsEventBus.instance.memoryEvents
  .where((e) => e.leakSuspected)
  .listen((event) {
    print('⚠ Potential memory leak detected!');
    print('  Heap: ${event.metrics.heapUsedMb.toStringAsFixed(1)}MB');
    print('  Delta since last: ${event.allocationDelta ~/ 1024}KB');
  });
```

### Common leak causes in Flutter

1. **Listeners not removed** – `StreamSubscription`, `AnimationController`,
   `ScrollController`, `TextEditingController` not disposed
2. **Static caches** – unbounded `Map` or `List` stored as static fields
3. **Image cache** – `PaintingBinding.instance.imageCache.maximumSizeBytes`
   too large
4. **Overlay entries** – not removed on route pop
5. **Platform channels** – callbacks holding widget references

---

## Rebuild Tracking

> Only active in **debug mode** via `debugOnRebuildDirtyWidget`.

### Setup

```dart
await PerfGuard.initialize(
  config: const PerfGuardConfig(
    enableRebuildTracker: true,
    excessiveRebuildRatePerSecond: 60.0,
    rebuildHistorySize: 100,
  ),
);
```

### Finding hot widgets

```dart
final rt = PerfGuard.instance.rebuildTracker;

// Top 20 widgets by rebuild count
for (final m in rt.hotWidgets) {
  print('${m.widgetType}: ${m.rebuildCount} rebuilds, '
        '${m.rebuildsPerSecond.toStringAsFixed(1)}/s');
}

// Widgets rebuilding excessively (> 60/s)
for (final m in rt.excessiveRebuilds) {
  print('EXCESSIVE: ${m.widgetType} '
        '(${m.rebuildsPerSecond.toStringAsFixed(0)}/s)');
}
```

### Optimization techniques

| Pattern | Fix |
|---------|-----|
| Rebuild storm on setState | Move state down, split widgets |
| InheritedWidget rebuilding too much | Use `select()` or `context.watch()` selectively |
| Animation driving full tree | Wrap animated widget in `AnimatedBuilder` + `RepaintBoundary` |
| Expensive `build()` | Extract to `const` subwidgets |
| List items rebuilding | Use `ListView.builder` + `const` item widgets |

---

## Timeline Recording

Record a bounded session and export for analysis:

```dart
final recorder = PerfGuard.instance.timelineRecorder;

// Start recording (keeps last 5000 events)
recorder.start(maxEntries: 5000);

// ... reproduce the issue ...

// Stop and export
recorder.stop();
final json = recorder.exportJson(pretty: true);

// Write to file or send to backend
final file = File('/tmp/timeline.json');
await file.writeAsString(json);
```

### Timeline JSON format

```json
{
  "startTime": "2024-06-10T10:00:00.000Z",
  "durationMs": 5234,
  "entryCount": 842,
  "entries": [
    {
      "offsetMs": 0.0,
      "id": "frame_1",
      "source": "FrameProfiler",
      "severity": "INFO",
      "metrics": { "frameNumber": 1, "totalDurationMicros": 4200, ... }
    },
    {
      "offsetMs": 16.67,
      "id": "jank_1704878400000",
      "source": "FrameProfiler",
      "severity": "CRITICAL",
      "consecutiveJankFrames": 4,
      "worstFrameDurationMs": 48.2
    }
  ]
}
```

---

## Startup Analysis

Mark milestones from app start to interactive:

```dart
// In main() - before runApp
PerfGuard.instance.startupAnalyzer.markAppStart();

// In your first widget's initState
PerfGuard.instance.startupAnalyzer.markFirstFrame();

// When your navigator is ready
PerfGuard.instance.startupAnalyzer.markNavigatorReady();

// When initial data is loaded
PerfGuard.instance.startupAnalyzer.markDataLoaded();

// When the user can interact
PerfGuard.instance.startupAnalyzer.markInteractive();

// Read results
final sa = PerfGuard.instance.startupAnalyzer;
print('Time to first frame: ${sa.timeToFirstFrame?.inMilliseconds}ms');
print('Time to interactive: ${sa.timeToInteractive?.inMilliseconds}ms');
```

---

## Navigation Performance

```dart
// Add observer
MaterialApp(
  navigatorObservers: [PerfGuard.instance.navigationTracker],
)

// Read results
final nt = PerfGuard.instance.navigationTracker;
for (final record in nt.history) {
  if (record.isSlow) {
    print('Slow transition: ${record.fromRoute} → ${record.toRoute} '
          '${record.duration.inMilliseconds}ms');
  }
}
```

Transitions slower than 300 ms are flagged as slow in `NavigationRecord.isSlow`.

---

## Export and Reporting

### Manual snapshot

```dart
// Returns the JSON file path (native) or JSON string (web)
final path = await PerfGuard.instance.exportReport();
print('Report at: $path');
```

### Auto-export on critical events

```dart
await PerfGuard.initialize(
  config: const PerfGuardConfig(
    autoExportOnCritical: true,
    exportDirectory: '/data/user/0/com.example.app/files/perf',
  ),
);
```

### Raw snapshot map

```dart
final map = await PerfGuard.instance.takeSnapshot();
// Use with your own reporting backend
await myAnalyticsClient.send(map);
```

---

## Profiling Checklist

- [ ] Run in **profile mode** (`flutter run --profile`) for accurate frame timings
- [ ] Disable `debugShowCheckedModeBanner` in debug builds
- [ ] Use a **physical device** – emulators have different GPU characteristics
- [ ] Reproduce the exact user flow before checking metrics
- [ ] Check `buildDuration` and `rasterDuration` separately
- [ ] Look for rebuild storms in the Rebuilds tab
- [ ] Monitor heap trend over time, not just peak
- [ ] Export a timeline when investigating a specific regression
