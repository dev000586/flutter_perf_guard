import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_perf_guard/flutter_perf_guard.dart';

/// flutter_perf_guard Example App
///
/// Demonstrates:
/// - Initialization
/// - PerfGuardOverlay HUD
/// - DiagnosticsDashboard
/// - Manual jank simulation
/// - Memory pressure simulation
/// - Rebuild heatmap via RebuildTracker
/// - Snapshot export
/// - BenchmarkRunner

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Initialize PerfGuard ─────────────────────────────────────────────
  await PerfGuard.initialize(
    config: const PerfGuardConfig(
      enableFrameProfiler: true,
      enableMemoryProfiler: true,
      enableRebuildTracker: true,
      enableJankDetector: true,
      enableStartupAnalyzer: true,
      enableNavigationTracker: true,
      verbose: true,
      memorySamplingInterval: Duration(seconds: 1),
      frameHistorySize: 120,
    ),
  );

  PerfGuard.instance.startupAnalyzer.markAppStart();

  runApp(const PerfGuardExampleApp());
}

class PerfGuardExampleApp extends StatelessWidget {
  const PerfGuardExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PerfGuard Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      navigatorObservers: [
        PerfGuard.instance.navigationTracker,
      ],
      home: const PerfGuardOverlay(
        showFps: true,
        showMemory: true,
        showJankAlert: true,
        child: _ExampleHome(),
      ),
    );
  }
}

class _ExampleHome extends StatefulWidget {
  const _ExampleHome();

  @override
  State<_ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<_ExampleHome> {
  int _rebuildCounter = 0;
  bool _isJanking = false;
  bool _isLeaking = false;
  final List<List<int>> _leakedMemory = [];
  Timer? _jankTimer;
  Timer? _leakTimer;
  String? _lastExportPath;

  @override
  void dispose() {
    _jankTimer?.cancel();
    _leakTimer?.cancel();
    super.dispose();
  }

  // ── Jank simulation ─────────────────────────────────────────────────

  void _startJank() {
    setState(() => _isJanking = true);
    _jankTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      // Block the UI thread to simulate expensive work
      final sw = Stopwatch()..start();
      while (sw.elapsedMilliseconds < 30) {
        // busy wait – intentional for demo purposes only
        for (int i = 0; i < 10000; i++) {}
      }
      if (mounted) setState(() => _rebuildCounter++);
    });

    // Auto-stop after 2 seconds
    Future.delayed(const Duration(seconds: 2), _stopJank);
  }

  void _stopJank() {
    _jankTimer?.cancel();
    if (mounted) setState(() => _isJanking = false);
  }

  // ── Memory pressure simulation ────────────────────────────────────────

  void _startLeak() {
    setState(() => _isLeaking = true);
    _leakTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      // Allocate 1MB per tick
      _leakedMemory.add(List.filled(250000, math.Random().nextInt(255)));
    });

    // Auto-stop after 3 seconds and free memory
    Future.delayed(const Duration(seconds: 3), _stopLeak);
  }

  void _stopLeak() {
    _leakTimer?.cancel();
    _leakedMemory.clear();
    if (mounted) setState(() => _isLeaking = false);
  }

  // ── Rebuild storm ─────────────────────────────────────────────────────

  void _triggerRebuildStorm() {
    for (int i = 0; i < 10; i++) {
      Future.delayed(Duration(milliseconds: i * 16), () {
        if (mounted) setState(() => _rebuildCounter++);
      });
    }
  }

  // ── Export ────────────────────────────────────────────────────────────

  Future<void> _exportSnapshot() async {
    final path = await PerfGuard.instance.exportReport();
    if (mounted) {
      setState(() => _lastExportPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report exported to:\n$path')),
      );
    }
  }

  // ── Benchmark ─────────────────────────────────────────────────────────

  Future<void> _runBenchmark() async {
    final suite = BenchmarkSuite(name: 'ExampleBenchmarks')
      ..add('list_sort_1k', () {
        final list = List.generate(1000, (i) => math.Random().nextInt(10000));
        list.sort();
      })
      ..add('string_concat_100', () {
        var s = '';
        for (int i = 0; i < 100; i++) {
          s += 'x';
        }
        blackHole(s);  // marks s as "used", suppresses warning
      })
      ..addAsync('future_chain', () async {
        await Future.value(42);
      });

    const runner = BenchmarkRunner(
      defaultWarmupRuns: 2,
      defaultMeasuredRuns: 5,
    );
    final results = await runner.run(suite);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _BenchmarkResultsDialog(results: results),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ PerfGuard Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Open Dashboard',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const DiagnosticsDashboard()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status section
            _SectionCard(
              title: 'Status',
              child: Column(
                children: [
                  _StatusRow('Rebuild count', '$_rebuildCounter'),
                  _StatusRow(
                      'Jank simulation', _isJanking ? '🔴 ACTIVE' : '⚪ idle'),
                  _StatusRow(
                      'Memory leak sim', _isLeaking ? '🟠 ACTIVE' : '⚪ idle'),
                  if (_lastExportPath != null)
                    _StatusRow('Last export', _lastExportPath!),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Jank controls
            _SectionCard(
              title: 'Jank Simulation',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Blocks the UI thread for 30ms per frame, causing jank '
                    'events to appear in the dashboard.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isJanking ? null : _startJank,
                    icon: const Icon(Icons.warning_amber),
                    label: Text(
                        _isJanking ? 'Simulating Jank…' : 'Start Jank (2s)'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Memory controls
            _SectionCard(
              title: 'Memory Pressure',
              child: Column(
                children: [
                  const Text(
                    'Allocates ~1MB every 200ms for 3 seconds to trigger '
                    'the leak detector.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isLeaking ? null : _startLeak,
                    icon: const Icon(Icons.memory),
                    label: Text(
                        _isLeaking ? 'Allocating…' : 'Start Memory Pressure'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Rebuild controls
            _SectionCard(
              title: 'Rebuild Storm',
              child: Column(
                children: [
                  const Text(
                    'Triggers 10 rapid setState calls to generate rebuild '
                    'events visible in the Rebuilds tab.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _triggerRebuildStorm,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Trigger Rebuild Storm'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Benchmark
            _SectionCard(
              title: 'Runtime Benchmark',
              child: Column(
                children: [
                  const Text(
                    'Runs a suite of micro-benchmarks with warmup and '
                    'statistical analysis.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _runBenchmark,
                    icon: const Icon(Icons.speed),
                    label: const Text('Run Benchmark Suite'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Export
            _SectionCard(
              title: 'Profiling Report',
              child: Column(
                children: [
                  const Text(
                    'Exports the current session data as a JSON report with '
                    'optimization suggestions.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _exportSnapshot,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Snapshot Report'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF58A6FF),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          const SizedBox(width: 10,),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _BenchmarkResultsDialog extends StatelessWidget {
  final List<BenchmarkResult> results;

  const _BenchmarkResultsDialog({required this.results});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('Benchmark Results',
          style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: results
              .map((r) => ListTile(
                    title: Text(r.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'mean ${(r.mean.inMicroseconds / 1000.0).toStringAsFixed(2)}ms '
                      '| p95 ${(r.p95.inMicroseconds / 1000.0).toStringAsFixed(2)}ms '
                      '| ${r.opsPerSecond.toStringAsFixed(0)} ops/s',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

@pragma('vm:never-inline')
void blackHole(dynamic value) {}