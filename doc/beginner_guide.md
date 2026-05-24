# Beginner Guide

This guide gets you from zero to a full performance report in 5 minutes,
with no prior knowledge of Flutter profiling required.

---

## What Does This Package Do?

It watches your app while it runs and tells you:

- **Which widgets are rebuilding too often** (and the exact file + line)
- **Which network requests are slow**
- **Whether memory is growing** (potential leak)
- **How smooth your animations are** (FPS)
- **An A–F grade** per category so you know where to focus
- **A readable text file** with numbered fix suggestions

---

## Step 1 — Add the Package

In your app's `pubspec.yaml`:

```yaml
dependencies:
  flutter_perf_guard: ^1.1.0
  path_provider: ^2.1.0
```

Run:

```bash
flutter pub get
```

---

## Step 2 — Initialize in main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_perf_guard/flutter_perf_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PerfGuard.initialize(
    config: const PerfGuardConfig(
      enableFrameProfiler: true,
      enableMemoryProfiler: true,
      enableRebuildTracker: true,   // shows file names (debug only)
      enableJankDetector: true,
      enableNetworkProfiler: true,  // tracks all HTTP requests
    ),
  );

  runApp(const MyApp());
}
```

---

## Step 3 — Add the Overlay

Wrap your `MaterialApp` child with `PerfGuardOverlay`:

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [
        PerfGuard.instance.navigationTracker, // track route transitions
      ],
      home: PerfGuardOverlay(  // shows live FPS in corner
        child: MyHomePage(),
      ),
    );
  }
}
```

You will now see a small HUD in the corner showing:
```
⚡ PerfGuard
FPS    59.8
Build  2.14ms
Raster 1.88ms
Heap   42.1MB
```

---

## Step 4 — Use Your App Normally

Navigate around, scroll lists, tap buttons, load data. The package
collects data automatically in the background.

If you have async operations you want measured, wrap them:

```dart
// Example: in your repository or API layer
final data = await PerfGuard.instance.asyncProfiler.track(
  'fetch_products',         // give it a name you'll recognise
  () => api.getProducts(),  // your actual operation
);
```

---

## Step 5 — Export the Report

Add a button anywhere in your app (e.g. debug settings screen):

```dart
ElevatedButton(
  onPressed: () async {
    final path = await PerfGuard.instance.exportReport(
      format: ReportFormat.text,
    );
    print('Report saved to: $path');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report: $path')),
    );
  },
  child: const Text('Export Performance Report'),
)
```

---

## Step 6 — Read the Report

Open the `.txt` file. **Ignore everything except "WHAT TO FIX".**

```
════════════════════════════════════════════════════════════
OVERALL GRADE : 🟡 C
════════════════════════════════════════════════════════════

...metrics...

WHAT TO FIX
════════════════════════════════════════════════════════════
1. REBUILD — ProductCard rebuilding 94x/sec
   File: lib/screens/home_screen.dart:142
   Location: HomeScreen > Column > ListView > ProductCard
   → Add const or use ValueListenableBuilder

2. NETWORK — GET https://api.example.com/products took 2340ms
   → Cache this response or paginate results

3. REBUILD — CounterWidget rebuilding 58x/sec
   File: lib/widgets/counter_widget.dart:38
   → Add const or use ValueListenableBuilder
════════════════════════════════════════════════════════════
```

Work through the list **top to bottom**. Fix item 1, test, export again,
check the grade improved, then move to item 2.

---

## Step 7 — Open the Dashboard (optional)

For a live view while your app is running:

```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const DiagnosticsDashboard()),
);
```

This opens a full-screen dashboard with 4 tabs:
- **FRAMES** — bar chart of frame durations (red = jank)
- **MEMORY** — heap trend over time
- **REBUILDS** — sorted list of widgets by rebuild count
- **LOG** — live event log

---

## Common Fixes for Beginners

### "ProductCard rebuilding 94x/sec"

Open the file at the line shown. The widget is probably inside a
`setState` scope that changes too often. Quickest fix:

```dart
// Add const to stop the widget rebuilding when parent changes
const ProductCard(product: product)
```

If `const` is not possible (because `product` is a variable):

```dart
// Extract to its own StatelessWidget with a key
ProductCard(
  key: ValueKey(product.id),  // tells Flutter this is the "same" widget
  product: product,
)
```

### "fetch_products took 2340ms"

Your network call is slow. Quickest fix — show a loading spinner while
waiting instead of blocking the screen:

```dart
@override
void initState() {
  super.initState();
  // Don't block the first frame
  WidgetsBinding.instance.addPostFrameCallback((_) => _load());
}

Future<void> _load() async {
  setState(() => _loading = true);
  _products = await repository.getAll();
  if (mounted) setState(() => _loading = false);
}
```

### "Heap growing steadily" / Leak suspected

The most common cause is a `StreamSubscription` or `AnimationController`
not being disposed. Check every `StatefulWidget` that uses them:

```dart
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _sub;
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kThemeAnimationDuration);
    _sub = someStream.listen(_onEvent);
  }

  @override
  void dispose() {
    _controller?.dispose(); // ← must have this
    _sub?.cancel();         // ← must have this
    super.dispose();
  }
}
```

### "FPS grade is D or F"

First check whether it's a build or raster problem. Look at the
FRAMES section:

```
Build  12.3ms   ← if this is high, the problem is in Dart widget code
Raster  2.1ms   ← if this is high, the problem is GPU/overdraw
```

**Build is high** → look at REBUILDS tab for the hot widgets

**Raster is high** → wrap expensive painted widgets with `RepaintBoundary`:

```dart
RepaintBoundary(
  child: MyExpensiveAnimatedWidget(),
)
```

---

## Grade Reference Card

| Grade | FPS | Heap | Action |
|-------|-----|------|--------|
| 🟢 A | ≥ 58 | < 50% | Nothing |
| 🟢 B | ≥ 55 | < 65% | Monitor |
| 🟡 C | ≥ 45 | < 80% | Investigate |
| 🟠 D | ≥ 30 | < 90% | Fix soon |
| 🔴 F | < 30 | ≥ 90% | Fix now |

---

## Frequently Asked Questions

**Q: Does this slow down my app?**

In debug mode: < 2% overhead. In release mode: frame profiler is active
(< 0.5% overhead), rebuild tracker is off, network profiler is off unless
explicitly enabled.

**Q: Why don't I see file names in the report?**

File names are only available in **debug mode** (`flutter run` without
`--profile` or `--release`). Run in debug, reproduce the issue, export.

**Q: My report says "No rebuild data"**

`RebuildTracker` only works in debug mode. Run with `flutter run`
(not `flutter run --profile`).

**Q: Network requests aren't being tracked**

Only requests made via `dart:io` `HttpClient` are intercepted. This
includes `http` and `dio` packages. Direct socket connections or
platform channel HTTP calls are not intercepted. Also, `NetworkProfiler`
is a no-op on Flutter Web.

**Q: The report file path — how do I access it on device?**

- **Android**: use Android Studio's Device File Explorer or
  `adb pull /data/user/0/com.your.app/app_flutter/perf_guard_reports/`
- **iOS**: use Xcode → Window → Devices → Download Container
- **macOS/Windows/Linux**: the path printed in the snackbar is directly
  accessible in Finder/Explorer

**Q: Can I send the report to my backend?**

Yes — use `takeSnapshot()` for a JSON map instead of a file:

```dart
final map = await PerfGuard.instance.takeSnapshot();
await myAnalytics.send(map); // send to your backend
```
