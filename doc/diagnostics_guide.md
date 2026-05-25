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

---

## Performance Grades

Every export now includes an A–F grade per category:

| Grade | Meaning |
|-------|---------|
| 🟢 A | Excellent — no action needed |
| 🟢 B | Good — minor issues, monitor |
| 🟡 C | Fair — noticeable issues, investigate |
| 🟠 D | Poor — users are affected, fix soon |
| 🔴 F | Critical — severe issue, fix immediately |

### Grade thresholds

**Frames:**

| Grade | FPS | Jank Rate |
|-------|-----|-----------|
| A | ≥ 58 | < 1% |
| B | ≥ 55 | < 3% |
| C | ≥ 45 | < 8% |
| D | ≥ 30 | < 15% |
| F | < 30 | ≥ 15% |

**Memory (heap usage):**

| Grade | Heap % |
|-------|--------|
| A | < 50% |
| B | < 65% |
| C | < 80% |
| D | < 90% |
| F | ≥ 90% |

**Rebuilds (excessive widget count):**

| Grade | Excessive Widgets |
|-------|------------------|
| A | 0 |
| B | 1 |
| C | 2–3 |
| D | 4–6 |
| F | > 6 |

---

## Widget File Locations in Reports

In **debug mode**, the export includes the exact file and line where
each excessively rebuilding widget is defined:

**REBUILD** — ProductCard rebuilding 94x/sec

**File**: lib/screens/home_screen.dart:142

**Location**: HomeScreen > Column > ListView > ProductCard
→ Add const or use ValueListenableBuilder

In **profile/release mode**, file info is unavailable:

**REBUILD** — ProductCard rebuilding 94x/sec
File: run in debug mode to see file location
→ Add const or use ValueListenableBuilder


**How to use this:**
1. Run your app in debug mode (`flutter run`)
2. Reproduce the slow interaction
3. Export the report
4. Open the file at the line shown
5. Apply the suggested fix

---

## Reading the Text Report

The `.txt` report has 3 parts:

**Part 1 — Metrics** (Frames, Memory, Image Cache, Rebuilds, Navigation,
Network, Async): raw numbers with plain English summary per section.

**Part 2 — What To Fix**: numbered list of actionable items, sorted by
severity. Each item includes the file location (debug mode) and a specific
one-line fix.

**Part 3 — Footer**: generation timestamp and package version.

The "What To Fix" section is the most useful for beginners — ignore
everything else and just work through that list top to bottom.

---

## Accessing New Profilers Directly

### NetworkProfiler

```dart
// Access the profiler
final np = PerfGuard.instance.networkProfiler;

// Read summaries
print(np.plainEnglishSummary);

// Iterate records
for (final r in np.records) {
  if (r.isSlow) print('Slow: ${r.url} — ${r.durationMs}ms');
  if (r.hasFailed) print('Failed: ${r.url} — ${r.statusCode}');
}
```

### AsyncProfiler

```dart
final ap = PerfGuard.instance.asyncProfiler;

// Wrap your calls
final data = await ap.track('load_dashboard', () => api.getDashboard());

// Read summary
print(ap.plainEnglishSummary);
```

### ImageCacheAnalyzer

```dart
final ia = PerfGuard.instance.imageCacheAnalyzer;

// Get a point-in-time snapshot
final snap = ia.snapshot();
print('Cache: ${snap.currentSizeMb}MB / ${snap.maxSizeMb}MB');

// Plain English
print(ia.plainEnglishSummary);

// Fix high pressure
ia.trimCacheTo(50 * 1024 * 1024); // 50MB cap
```