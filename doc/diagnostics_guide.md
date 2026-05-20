# Diagnostics Guide

## Event Severity Levels

| Level | Meaning | Action |
|-------|---------|--------|
| `info` | Normal operation, metric recorded | Log / chart |
| `warning` | Performance degradation observed | Investigate |
| `critical` | Severe issue requiring immediate attention | Alert / fix |

---

## Reading the Dashboard

Open the dashboard from anywhere in your app:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const DiagnosticsDashboard()),
);
```

### FRAMES tab

| Element | Description |
|---------|-------------|
| FPS card | Rolling 30-frame average. Green ≥ 55fps, orange ≥ 30fps, red < 30fps |
| Jank Events | Count of `JankEvent`s emitted (consecutive jank sequences) |
| Jank Frames | Individual frames that exceeded the 16ms threshold |
| Bar chart | Each bar = one frame. Green < 8ms, orange 8–16ms, red > 16ms |
| Red dashed line | 16ms budget line |

### MEMORY tab

| Element | Description |
|---------|-------------|
| Heap card | Current used / capacity |
| RSS card | Resident Set Size (OS-level memory) |
| External card | Native/platform allocations |
| Progress bar | Heap usage fraction; turns red above warning threshold |
| Line chart | Heap trend over last N samples |

### REBUILDS tab

Each row shows one widget type:
- **Rebuild count** – total rebuilds since tracker started
- **Rebuilds/s** – current rate
- **Avg time** – average `Element.rebuild` duration
- **⚠** badge – excessive rebuild rate (> 60/s)
- Red border – flagged as excessive

### LOG tab

Scrollable chronological log of all events, color-coded:
- White: frame events
- Red: jank events, memory warnings

---

## PerfGuardOverlay HUD Fields

```
⚡ PerfGuard
FPS    59.8         ← rolling 30-frame average (green/orange/red)
Build  2.14ms      ← last frame build time (orange if > 8ms)
Raster 1.88ms      ← last frame raster time (orange if > 8ms)
Heap   42.1MB      ← current heap (red if > 512MB)
RSS    84.3MB
⚠ JANK             ← flashes red for 2s after a JankEvent
```

---

## Event Bus Diagnostics

### Subscribe to all events for logging

```dart
DiagnosticsEventBus.instance.allEvents.listen((event) {
  debugPrint('[${event.severity.label}] ${event.source}: ${event.id}');
});
```

### Filtered subscriptions

```dart
// Only critical alerts
DiagnosticsEventBus.instance.criticalEvents.listen((event) {
  _showAlertBanner(event);
});

// Only from a specific component
DiagnosticsEventBus.instance
  .fromSource('MemoryProfiler')
  .listen((event) { ... });

// Typed + source filtered
DiagnosticsEventBus.instance
  .fromSourceTyped<FrameEvent>('FrameProfiler')
  .listen((event) { ... });
```

### Buffered sliding window

```dart
// Get the last 10 frame events as a list each time a new one arrives
DiagnosticsEventBus.instance
  .bufferedWindow<FrameEvent>(10)
  .listen((window) {
    final avgFps = window.fold(0.0, (s, e) => s + e.metrics.fps) / window.length;
    print('10-frame avg FPS: ${avgFps.toStringAsFixed(1)}');
  });
```

---

## Diagnosing Specific Issues

### Issue: App feels laggy during scroll

1. Open Dashboard → FRAMES tab
2. Scroll the list in your app
3. Watch for orange/red bars during scroll
4. If build bars are tall → check REBUILDS tab for list item widgets
5. If raster bars are tall → look for overdraw or complex clipping

**Common fix:**
```dart
// Add itemExtent to skip layout for off-screen items
ListView.builder(
  itemExtent: 56.0,
  itemBuilder: (_, i) => const MyListItem(),
)
```

---

### Issue: Memory grows over time

1. Open Dashboard → MEMORY tab
2. Watch the line chart – consistent upward slope with no drops = leak
3. Check event log for `[MEM ⚠]` entries
4. Export a report and read `optimizationSuggestions`

**Common fix:**
```dart
@override
void dispose() {
  _animationController.dispose();
  _subscription.cancel();
  _focusNode.dispose();
  super.dispose();
}
```

---

### Issue: Screen push is slow

1. Enable navigation tracking
2. Check `PerfGuard.instance.navigationTracker.history`
3. Look for records where `isSlow == true`

**Common fix:**
```dart
// Defer heavy work to after first frame
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadData();        // don't block the push animation
    _buildIndex();
  });
}
```

---

### Issue: Specific widget is rebuilding too much

1. Open Dashboard → REBUILDS tab
2. Find the widget (sorted by rebuild count)
3. Note the rebuild rate and average time
4. Check `hasRepaintBoundary` in exported JSON

**Common fix:**
```dart
// Wrap with RepaintBoundary
RepaintBoundary(
  child: MyFrequentlyUpdatedWidget(),
)

// Or use const where possible
const MyExpensiveWidget(data: staticData)
```

---

## Runtime Diagnostics Checks

```dart
// Check if jank has occurred during a test flow
final fp = PerfGuard.instance.frameProfiler;
final jankBefore = fp.jankFrames;

await tester.fling(find.byType(ListView), const Offset(0, -300), 1000);
await tester.pumpAndSettle();

final jankDuring = fp.jankFrames - jankBefore;
if (jankDuring > 0) {
  print('WARNING: $jankDuring jank frames during scroll');
}
```

```dart
// Assert no excessive rebuilds after a user flow
final rt = PerfGuard.instance.rebuildTracker;
rt.reset();

// ... perform user flow ...

final excessive = rt.excessiveRebuilds;
assert(
  excessive.isEmpty,
  'Excessive rebuilds: ${excessive.map((m) => m.widgetType).join(', ')}',
);
```

---

## Optimization Suggestion Codes

The exporter generates suggestions with these fields:

```json
{
  "category": "frame | memory | rebuild",
  "severity": "info | warning | critical",
  "message": "Human-readable suggestion",
  "metric": "metric key that triggered this",
  "value": 0.08
}
```

| Category | Metric | Threshold | Message |
|----------|--------|-----------|---------|
| frame | jankRate | > 5% | Add RepaintBoundary |
| memory | heapUsagePercent | > 80% | Check retained objects |
| rebuild | excessiveRebuildCount | > 0 | Use const / memoization |

---

## DevTools Integration

`flutter_perf_guard` emits timeline events compatible with Flutter DevTools:

```dart
import 'dart:developer' as developer;

// Events are automatically tagged in the DevTools timeline
developer.Timeline.startSync('PerfGuard.FrameProfiler');
// ... profiling work ...
developer.Timeline.finishSync();
```

Open DevTools → Performance tab → Timeline while the overlay is active to
see PerfGuard events interleaved with Flutter framework events.
