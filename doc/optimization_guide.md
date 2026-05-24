# Optimization Guide

This guide maps `flutter_perf_guard` diagnostics to concrete Flutter
optimization techniques.

---

## Frame Performance

### High `buildDuration`

**Diagnosis:**
```dart
// Check FrameMetrics
frame.buildFraction > 0.7  // build is taking > 70% of frame budget
```

**Fixes:**

#### 1. Use `const` constructors
```dart
// Before
Text('Hello', style: TextStyle(fontSize: 16));

// After
const Text('Hello', style: TextStyle(fontSize: 16));
```

#### 2. Extract stateless subtrees
```dart
// Before – whole page rebuilds when counter changes
class _MyPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ExpensiveHeader(),   // rebuilds unnecessarily
      Text('$_counter'),
    ]);
  }
}

// After – only the counter rebuilds
class _MyPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const ExpensiveHeader(),   // const – never rebuilds
      Text('$_counter'),
    ]);
  }
}
```

#### 3. Use `RepaintBoundary` to isolate repaints
```dart
RepaintBoundary(
  child: AnimatedWidget(),   // GPU layer cached; does not repaint parent
)
```

#### 4. Move heavy computation out of `build()`
```dart
// Before
Widget build(BuildContext context) {
  final sorted = items.sorted(compare);  // O(n log n) every frame
  return ListView(...);
}

// After
late final sorted = items.sorted(compare);  // computed once

@override
Widget build(BuildContext context) {
  return ListView(...);  // uses cached result
}
```

---

### High `rasterDuration`

**Diagnosis:**
```dart
frame.rasterFraction > 0.6  // raster taking > 60% of frame budget
```

**Fixes:**

#### 1. Cache expensive paint operations with `RepaintBoundary`
Wrapping a widget in `RepaintBoundary` tells Flutter to rasterize it to
a separate GPU layer, which is composited cheaply on subsequent frames
if the widget doesn't change.

```dart
// Add around any widget that repaints independently
RepaintBoundary(
  child: CustomPaint(painter: ExpensivePainter()),
)
```

#### 2. Avoid `saveLayer` (caused by opacity, clipping, shaders)
```dart
// Expensive – causes saveLayer
Opacity(opacity: 0.5, child: ExpensiveWidget())

// Cheaper alternatives
// Option A: use color with alpha directly
ColoredBox(color: Colors.red.withOpacity(0.5))

// Option B: fade via AnimatedOpacity with RepaintBoundary
RepaintBoundary(
  child: AnimatedOpacity(opacity: _value, child: ExpensiveWidget()),
)
```

#### 3. Downscale large images
```dart
Image.network(
  url,
  cacheWidth: 200,   // decode at display size, not full resolution
  cacheHeight: 200,
)
```

#### 4. Avoid `ClipRRect` in hot paths
```dart
// Expensive
ClipRRect(borderRadius: BorderRadius.circular(8), child: image)

// Cheaper
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    image: DecorationImage(image: networkImage),
  ),
)
```

---

## Jank Elimination

### Finding the culprit

When `flutter_perf_guard` emits a `JankEvent`, the `culpritWidgetPath`
field may contain a hint. Cross-reference with the RebuildTracker's
`hotWidgets` at the same timestamp in the timeline.

### Common jank patterns

| JankEvent pattern | Likely cause |
|---|---|
| Jank on scroll start | Heavy `initState` in list items |
| Jank on route push | Expensive first build of destination page |
| Jank after image loads | Image decoding on UI thread |
| Periodic jank (fixed interval) | Timer firing expensive work |
| Jank on keyboard open | Relayout of entire page |

### Async-ify expensive work

```dart
// Blocks UI thread
void _onButtonTap() {
  final result = expensiveComputation(data);  // 50ms
  setState(() => _result = result);
}

// Non-blocking
Future<void> _onButtonTap() async {
  final result = await compute(expensiveComputation, data);
  if (mounted) setState(() => _result = result);
}
```

### Use `SchedulerBinding.scheduleTask` for non-critical work

```dart
SchedulerBinding.instance.scheduleTask(
  () => _buildSearchIndex(),
  Priority.animation - 1,  // lower than animations
);
```

---

## Memory Optimization

### When `MemoryEvent.leakSuspected == true`

The leak detector uses linear regression over 10 heap samples.
A positive slope > 512 KB per sample interval triggers the flag.

**Investigation steps:**

1. Open `DiagnosticsDashboard` → Memory tab
2. Watch for a steadily climbing heap with no GC-induced drops
3. Add `dispose()` calls and check for retained listeners:

```dart
class _MyState extends State<MyWidget> {
  StreamSubscription? _sub;
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: duration);
    _sub = someStream.listen(_onEvent);
  }

  @override
  void dispose() {
    _controller?.dispose();   // ← critical
    _sub?.cancel();           // ← critical
    super.dispose();
  }
}
```

### Image cache sizing

```dart
// Limit image cache to prevent OOM
PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
PaintingBinding.instance.imageCache.maximumSize = 100;                    // 100 images
```

### Reduce large list memory

```dart
// Use ListView.builder – only builds visible items
ListView.builder(
  itemCount: 10000,
  itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
)

// vs ListView(children: [...10000 items...])  ← builds all upfront
```

---

## Rebuild Optimization

### When `RebuildMetrics.isExcessive == true`

Rebuild rate > 60/s means a widget is rebuilding more often than the
frame budget allows.

**Fix 1: Move state down**
```dart
// Before – parent rebuilds causes child to rebuild
class Parent extends StatefulWidget {
  int _counter = 0;
  Widget build(BuildContext context) {
    return Column(children: [
      ExpensiveChild(),              // rebuilds on every counter change
      Text('$_counter'),
    ]);
  }
}

// After – counter state is isolated
class Parent extends StatelessWidget {
  Widget build(BuildContext context) {
    return Column(children: [
      const ExpensiveChild(),        // never rebuilds
      _CounterWidget(),              // rebuilds in isolation
    ]);
  }
}
```

**Fix 2: Use `ValueListenableBuilder` for fine-grained updates**
```dart
final _counter = ValueNotifier(0);

ValueListenableBuilder<int>(
  valueListenable: _counter,
  builder: (context, value, child) => Text('$value'),
)
```

**Fix 3: Memoize expensive child subtrees**
```dart
class Parent extends StatefulWidget {
  late final Widget _expensiveChild = const ExpensiveChild();

  Widget build(BuildContext context) {
    return Column(children: [
      _expensiveChild,    // same instance, Flutter skips diff
      Text('$_counter'),
    ]);
  }
}
```

---

## List Performance

### Large scrollable lists

```dart
// ✅ Use ListView.builder (lazy)
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, i) => ItemCard(item: items[i]),
)

// ✅ Add itemExtent when all items are same height
ListView.builder(
  itemExtent: 72.0,    // skip layout for off-screen items
  itemCount: items.length,
  itemBuilder: (context, i) => ItemCard(item: items[i]),
)

// ✅ Use SliverList for complex scroll views
CustomScrollView(
  slivers: [
    SliverAppBar(...),
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => ItemCard(item: items[i]),
        childCount: items.length,
      ),
    ),
  ],
)
```

### Caching list item widgets

```dart
class ItemCard extends StatelessWidget {
  final Item item;
  const ItemCard({super.key, required this.item});  // key enables reuseability

  @override
  Widget build(BuildContext context) => ...;
}
```

---

## Navigation Performance

When `NavigationRecord.isSlow == true` (> 300 ms):

```dart
// Defer expensive initialization
class DestinationPage extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    // Schedule after first frame instead of blocking push
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }
}

// Use lighter hero animations
Hero(
  tag: 'my_hero',
  child: Image(...),
  // Avoid complex clipping inside heroes
)
```

---

## Automated Suggestions

`ReportExporter._generateSuggestions()` automatically produces:

| Condition | Suggestion |
|---|---|
| `jankRate > 5%` | Add RepaintBoundary around expensive subtrees |
| `heapUsagePercent > 80%` | Check for retained objects or large image caches |
| `excessiveRebuilds.isNotEmpty` | Use const constructors or memoization |

Export and read suggestions:

```dart
final map = await PerfGuard.instance.takeSnapshot();
final suggestions = map['optimizationSuggestions'] as List;
for (final s in suggestions) {
  print('[${s['severity'].toUpperCase()}] ${s['message']}');
}
```

---

## Using the Performance Grader

The `PerformanceGrader` gives you a single letter that summarises each
area so you know where to focus:

```dart
final grader = PerformanceGrader(
  frameProfiler: PerfGuard.instance.frameProfiler,
  memoryProfiler: PerfGuard.instance.memoryProfiler,
  rebuildTracker: PerfGuard.instance.rebuildTracker,
  navigationTracker: PerfGuard.instance.navigationTracker,
);

print('Frames:   ${grader.gradeFrames().label}  ${grader.frameSummary()}');
print('Memory:   ${grader.gradeMemory().label}  ${grader.memorySummary()}');
print('Rebuilds: ${grader.gradeRebuilds().label}  ${grader.rebuildSummary()}');
print('Overall:  ${grader.overallGrade.label}');
```

**Fix lowest grade first.** If rebuilds are F and frames are B, fix
the excessive rebuilds — they are almost certainly causing the frame issues too.

---

## Network Optimization

When `NetworkProfiler` flags a slow request:
⚠ GET https://api.example.com/products → 2340ms

**Fix 1: Cache the response**
```dart
// Simple in-memory cache
final _cache = <String, dynamic>{};

Future<List<Product>> getProducts() async {
  if (_cache.containsKey('products')) {
    return _cache['products'];
  }
  final result = await api.fetchProducts();
  _cache['products'] = result;
  return result;
}
```

**Fix 2: Paginate**
```dart
// Don't load all items at once
Future<List<Product>> getProducts({int page = 1, int limit = 20}) =>
    api.fetchProducts(page: page, limit: limit);
```

**Fix 3: Show loading state immediately**
```dart
// Don't block UI — show loading indicator
@override
void initState() {
  super.initState();
  // Don't await here — let build() run first
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final data = await ap.track('load_products', api.getProducts);
    if (mounted) setState(() => _products = data);
  });
}
```

---

## Async Optimization

When `AsyncProfiler` flags a slow operation:
⚠ parse_large_json: 890ms

**Move to background isolate:**
```dart
// Before — blocks UI thread
final data = ap.trackSync('parse_json', () => jsonDecode(response));

// After — runs in separate isolate
final data = await ap.track(
  'parse_json',
  () => compute(jsonDecode, response),
);
```
