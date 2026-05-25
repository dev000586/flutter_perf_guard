import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_perf_guard/flutter_perf_guard.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PerfGuard.initialize(
    config: const PerfGuardConfig(
      enableFrameProfiler: true,
      enableMemoryProfiler: true,
      enableRebuildTracker: true,
      enableJankDetector: true,
      enableStartupAnalyzer: true,
      enableNavigationTracker: true,
      enableNetworkProfiler: true,
      enableAsyncProfiler: true,
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
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF58A6FF),
          surface: Color(0xFF0D1117),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
      ),
      navigatorObservers: [
        PerfGuard.instance.navigationTracker,
      ],
      initialRoute: '/',
      routes: {
        '/': (_) => const PerfGuardOverlay(
              showFps: true,
              showMemory: true,
              showJankAlert: true,
              child: _HomeScreen(),
            ),
        '/dashboard': (_) => const DiagnosticsDashboard(),
        '/network': (_) => const _NetworkDemoScreen(),
        '/async': (_) => const _AsyncDemoScreen(),
        '/image': (_) => const _ImageCacheDemoScreen(),
        '/grader': (_) => const _GraderScreen(),
        '/benchmark': (_) => const _BenchmarkScreen(),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _HomeScreen extends StatefulWidget {
  const _HomeScreen();

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  int _rebuildCounter = 0;
  bool _isJanking = false;
  bool _isLeaking = false;
  String? _lastExportPath;
  String? _overallGrade;

  final List<List<int>> _leakedMemory = [];
  Timer? _jankTimer;
  Timer? _leakTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfGuard.instance.startupAnalyzer.markFirstFrame();
      PerfGuard.instance.startupAnalyzer.markInteractive();
    });
  }

  @override
  void dispose() {
    _jankTimer?.cancel();
    _leakTimer?.cancel();
    super.dispose();
  }

  // ── Jank simulation ───────────────────────────────────────────────────────

  void _startJank() {
    setState(() => _isJanking = true);
    _jankTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final sw = Stopwatch()..start();
      while (sw.elapsedMilliseconds < 30) {
        for (int i = 0; i < 10000; i++) {}
      }
      if (mounted) setState(() => _rebuildCounter++);
    });
    Future.delayed(const Duration(seconds: 2), _stopJank);
  }

  void _stopJank() {
    _jankTimer?.cancel();
    if (mounted) setState(() => _isJanking = false);
  }

  // ── Memory pressure ───────────────────────────────────────────────────────

  void _startLeak() {
    setState(() => _isLeaking = true);
    _leakTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _leakedMemory.add(List.filled(250000, math.Random().nextInt(255)));
    });
    Future.delayed(const Duration(seconds: 3), _stopLeak);
  }

  void _stopLeak() {
    _leakTimer?.cancel();
    _leakedMemory.clear();
    if (mounted) setState(() => _isLeaking = false);
  }

  // ── Rebuild storm ─────────────────────────────────────────────────────────

  void _triggerRebuildStorm() {
    for (int i = 0; i < 10; i++) {
      Future.delayed(Duration(milliseconds: i * 16), () {
        if (mounted) setState(() => _rebuildCounter++);
      });
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportTextReport() async {
    try {
      final path = await PerfGuard.instance.exportReport(
        format: ReportFormat.text,
      );
      if (!mounted) return;
      setState(() => _lastExportPath = path);
      _showSnack('📄 Text report saved to:\n$path');
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  Future<void> _exportJsonReport() async {
    try {
      final path = await PerfGuard.instance.exportReport(
        format: ReportFormat.json,
      );
      if (!mounted) return;
      setState(() => _lastExportPath = path);
      _showSnack('📊 JSON report saved to:\n$path');
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  // ── Grade ─────────────────────────────────────────────────────────────────

  void _checkGrade() {
    final grader = PerformanceGrader(
      frameProfiler: PerfGuard.instance.frameProfiler,
      memoryProfiler: PerfGuard.instance.memoryProfiler,
      rebuildTracker: PerfGuard.instance.rebuildTracker,
      navigationTracker: PerfGuard.instance.navigationTracker,
    );
    setState(() {
      _overallGrade =
          '${grader.overallGrade.emoji} ${grader.overallGrade.label}';
    });
    Navigator.of(context).pushNamed('/grader');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ PerfGuard Demo'),
        backgroundColor: const Color(0xFF161B22),
        actions: [
          // Grade badge
          if (_overallGrade != null)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF30363D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _overallGrade!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Live Dashboard',
            onPressed: () => Navigator.of(context).pushNamed('/dashboard'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Status ────────────────────────────────────────────────────
          _SectionCard(
            title: 'Session Status',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _StatusRow('Rebuild count        ', '$_rebuildCounter'),
                _StatusRow('Jank sim               ',
                    _isJanking ? '🔴 ACTIVE' : '⚪ idle'),
                _StatusRow(
                    'Memory sim         ', _isLeaking ? '🟠 ACTIVE' : '⚪ idle'),
                _StatusRow('Network requests',
                    '${PerfGuard.instance.networkProfiler.records.length}'),
                if (_lastExportPath != null)
                  _StatusRow('Last export          ', _lastExportPath ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Navigation shortcuts ───────────────────────────────────────
          _SectionCard(
            title: 'Screens',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _NavChip(
                  label: '📊 Dashboard',
                  onTap: () => Navigator.of(context).pushNamed('/dashboard'),
                ),
                _NavChip(
                  label: '🌐 Network',
                  onTap: () => Navigator.of(context).pushNamed('/network'),
                ),
                _NavChip(
                  label: '⏱ Async',
                  onTap: () => Navigator.of(context).pushNamed('/async'),
                ),
                _NavChip(
                  label: '🖼 Image Cache',
                  onTap: () => Navigator.of(context).pushNamed('/image'),
                ),
                _NavChip(
                  label: '🏎 Benchmark',
                  onTap: () => Navigator.of(context).pushNamed('/benchmark'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Performance grade ──────────────────────────────────────────
          _SectionCard(
            title: 'Performance Grade',
            child: Column(
              children: [
                const Text(
                  'Grade your app A–F across Frames, Memory, Rebuilds '
                  'and Navigation with plain English summaries.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _checkGrade,
                  icon: const Icon(Icons.grade),
                  label: const Text('Check Performance Grade'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Jank ──────────────────────────────────────────────────────
          _SectionCard(
            title: 'Jank Simulation',
            child: Column(
              children: [
                const Text(
                  'Blocks the UI thread 30ms/frame for 2 seconds. '
                  'Watch FPS drop in the overlay.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isJanking ? null : _startJank,
                  icon: const Icon(Icons.warning_amber),
                  label:
                      Text(_isJanking ? 'Simulating Jank…' : 'Start Jank (2s)'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Memory ────────────────────────────────────────────────────
          _SectionCard(
            title: 'Memory Pressure',
            child: Column(
              children: [
                const Text(
                  'Allocates ~1MB every 200ms for 3 seconds to '
                  'trigger the leak detector.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isLeaking ? null : _startLeak,
                  icon: const Icon(Icons.memory),
                  label: Text(
                      _isLeaking ? 'Allocating…' : 'Start Memory Pressure'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Rebuild ───────────────────────────────────────────────────
          _SectionCard(
            title: 'Rebuild Storm',
            child: Column(
              children: [
                const Text(
                  'Triggers 10 rapid setState calls. Check the '
                  'Rebuilds tab in the Dashboard.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _triggerRebuildStorm,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Trigger Rebuild Storm'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Export ────────────────────────────────────────────────────
          _SectionCard(
            title: 'Export Report',
            child: Column(
              children: [
                const Text(
                  'Export a human-readable .txt or structured .json '
                  'report to the app documents folder.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _exportTextReport,
                        icon: const Icon(Icons.text_snippet),
                        label: const Text('Export .txt'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F6FEB)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _exportJsonReport,
                        icon: const Icon(Icons.data_object),
                        label: const Text('Export .json'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF388BFD)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NETWORK DEMO SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkDemoScreen extends StatefulWidget {
  const _NetworkDemoScreen();

  @override
  State<_NetworkDemoScreen> createState() => _NetworkDemoScreenState();
}

class _NetworkDemoScreenState extends State<_NetworkDemoScreen> {
  bool _loading = false;
  String _status = '';

  Future<void> _makeFastRequest() async {
    setState(() { _loading = true; _status = 'Making request…'; });
    try {
      Uri uri = Uri.parse('https://jsonplaceholder.typicode.com/todos/1');
      final int statusCode;
      if(kIsWeb){
        final res = await http.get(
          uri,
        );
        statusCode = res.statusCode;
      }else {
        final client = HttpClient();
        final req = await client.getUrl(
          uri,
        );
        final res = await req.close();
        await res.drain<void>();
        statusCode = res.statusCode;
      }
        if (mounted) {
          setState(() {
            _loading = false;
            _status = '✅ GET /todos/1 — status $statusCode';
          });
        }

    } catch (e) {
      if (mounted) setState(() { _loading = false; _status = '❌ $e'; });
    }
  }

  Future<void> _makeSlowRequest() async {
    setState(() {
      _loading = true;
      _status = 'Making slow request…';
    });

    try {
      Uri uri = Uri.parse('https://httpbin.org/delay/2');

      final int statusCode;

      if (kIsWeb) {
        final res = await http.get(uri);
        statusCode = res.statusCode;
      } else {
        final client = HttpClient();
        final req = await client.getUrl(uri);
        final res = await req.close();
        await res.drain<void>();
        statusCode = res.statusCode;
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _status =
          '⚠ GET /delay/2 — status $statusCode (flagged as slow)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = '❌ $e';
        });
      }
    }
  }

  Future<void> _makeFailedRequest() async {
    setState(() {
      _loading = true;
      _status = 'Making 404 request…';
    });

    try {
      Uri uri = Uri.parse('https://httpbin.org/status/404');

      final int statusCode;

      if (kIsWeb) {
        final res = await http.get(uri);
        statusCode = res.statusCode;
      } else {
        final client = HttpClient();
        final req = await client.getUrl(uri);
        final res = await req.close();
        await res.drain<void>();
        statusCode = res.statusCode;
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _status =
          '❌ GET /status/404 — status $statusCode (recorded as failed)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = '❌ $e';
        });
      }
    }
  }

  Future<void> _makePostRequest() async {
    setState(() {
      _loading = true;
      _status = 'Making POST request…';
    });

    try {
      Uri uri = Uri.parse(
        'https://jsonplaceholder.typicode.com/posts',
      );

      final int statusCode;

      if (kIsWeb) {
        final res = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: '{"title":"test","body":"hello","userId":1}',
        );

        statusCode = res.statusCode;
      } else {
        final client = HttpClient();
        final req = await client.postUrl(uri);

        req.headers.set('Content-Type', 'application/json');
        req.write('{"title":"test","body":"hello","userId":1}');

        final res = await req.close();
        await res.drain<void>();

        statusCode = res.statusCode;
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _status = '✅ POST /posts — status $statusCode';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = '❌ $e';
        });
      }
    }
  }

  Future<void> _makeServerErrorRequest() async {
    setState(() {
      _loading = true;
      _status = 'Making 500 request…';
    });

    try {
      Uri uri = Uri.parse('https://httpbin.org/status/500');

      final int statusCode;

      if (kIsWeb) {
        final res = await http.get(uri);
        statusCode = res.statusCode;
      } else {
        final client = HttpClient();
        final req = await client.getUrl(uri);
        final res = await req.close();
        await res.drain<void>();
        statusCode = res.statusCode;
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _status =
          '❌ GET /status/500 — status $statusCode (recorded as failed)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = '❌ $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final np = PerfGuard.instance.networkProfiler;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌐 Network Profiler'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _SectionCard(
            title: 'Simulate Requests',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Simulates HTTP requests and records them into the '
                      'NetworkProfiler without requiring real network access. '
                      'Slow (>1s) and failed (>=400) requests are flagged.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_status.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RequestButton(
                      label: '⚡ Fast GET',
                      color: const Color(0xFF238636),
                      loading: _loading,
                      onTap: _loading ? null : _makeFastRequest,
                    ),
                    _RequestButton(
                      label: '🐢 Slow GET (2s)',
                      color: Colors.orange,
                      loading: _loading,
                      onTap: _loading ? null : _makeSlowRequest,
                    ),
                    _RequestButton(
                      label: '❌ 404 GET',
                      color: Colors.red,
                      loading: _loading,
                      onTap: _loading ? null : _makeFailedRequest,
                    ),
                    _RequestButton(
                      label: '📤 POST',
                      color: const Color(0xFF1F6FEB),
                      loading: _loading,
                      onTap: _loading ? null : _makePostRequest,
                    ),
                    _RequestButton(
                      label: '💥 500 Error',
                      color: Colors.deepOrange,
                      loading: _loading,
                      onTap: _loading ? null : _makeServerErrorRequest,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if(!kIsWeb)
          // Live summary
          _SectionCard(
            title: 'Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusRow('Total requests  ', '${np.records.length}'),
                _StatusRow('Slow (> 1s)       ', '${np.slowRequests.length}'),
                _StatusRow(
                    'Failed (>= 400)', '${np.failedRequests.length}'),
                const SizedBox(height: 8),
                Text(
                  np.plainEnglishSummary,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if(!kIsWeb)
          // Request log
          _SectionCard(
            title: 'Request Log',
            child: np.records.isEmpty
                ? const Text(
              'No requests yet — tap buttons above.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
                : Column(
              children: np.records.reversed
                  .take(10)
                  .map((r) => _RequestTile(record: r))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// Small button widget for the request grid
class _RequestButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final Future<void> Function()? onTap;

  const _RequestButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
}

class _RequestTile extends StatelessWidget {
  final NetworkRequestRecord record;

  const _RequestTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final color = record.hasFailed
        ? Colors.red
        : record.isSlow
            ? Colors.orange
            : const Color(0xFF4CAF50);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  record.method,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${record.durationMs.toStringAsFixed(0)}ms',
                style: TextStyle(color: color, fontSize: 11),
              ),
              if (record.statusCode != null) ...[
                const SizedBox(width: 6),
                Text(
                  'HTTP ${record.statusCode}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            record.url,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ASYNC DEMO SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _AsyncDemoScreen extends StatefulWidget {
  const _AsyncDemoScreen();

  @override
  State<_AsyncDemoScreen> createState() => _AsyncDemoScreenState();
}

class _AsyncDemoScreenState extends State<_AsyncDemoScreen> {
  bool _loading = false;
  String _lastResult = '';

  Future<void> _runFastOp() async {
    setState(() => _loading = true);
    final ap = PerfGuard.instance.asyncProfiler;
    await ap.track('fast_json_parse', () async {
      await Future.delayed(const Duration(milliseconds: 50));
      return '{"result": "ok"}';
    });
    if (mounted) {
      setState(() {
        _loading = false;
        _lastResult = 'fast_json_parse: ~50ms';
      });
    }
  }

  Future<void> _runSlowOp() async {
    setState(() => _loading = true);
    final ap = PerfGuard.instance.asyncProfiler;
    await ap.track('slow_db_query', () async {
      // Simulate a slow database query
      await Future.delayed(const Duration(milliseconds: 800));
      return 'data';
    });
    if (mounted) {
      setState(() {
        _loading = false;
        _lastResult = 'slow_db_query: ~800ms (will be flagged)';
      });
    }
  }

  Future<void> _runFailingOp() async {
    setState(() => _loading = true);
    final ap = PerfGuard.instance.asyncProfiler;
    try {
      await ap.track('failing_api_call', () async {
        await Future.delayed(const Duration(milliseconds: 100));
        throw Exception('Simulated API failure');
      });
    } catch (_) {
      // Expected — AsyncProfiler records it as failed
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _lastResult = 'failing_api_call: recorded as failed';
      });
    }
  }

  void _runSyncOp() {
    final ap = PerfGuard.instance.asyncProfiler;
    ap.trackSync('sort_large_list', () {
      final list = List.generate(10000, (i) => math.Random().nextInt(100000));
      list.sort();
      return list.length;
    });
    setState(() => _lastResult = 'sort_large_list: completed');
  }

  @override
  Widget build(BuildContext context) {
    final ap = PerfGuard.instance.asyncProfiler;

    return Scaffold(
      appBar: AppBar(
        title: const Text('⏱ Async Profiler'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _SectionCard(
            title: 'Track Operations',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Wrap any async or sync operation with asyncProfiler.track()'
                  ' to measure its duration. Slow operations (> 500ms) are flagged.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                if (_lastResult.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '→ $_lastResult',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                          fontSize: 12),
                    ),
                  ),
                _AsyncOpButton(
                  label: '⚡ Fast Op (~50ms)',
                  color: const Color(0xFF238636),
                  loading: _loading,
                  onTap: _runFastOp,
                ),
                const SizedBox(height: 6),
                _AsyncOpButton(
                  label: '🐢 Slow Op (~800ms) — flagged',
                  color: Colors.orange,
                  loading: _loading,
                  onTap: _runSlowOp,
                ),
                const SizedBox(height: 6),
                _AsyncOpButton(
                  label: '❌ Failing Op — recorded as error',
                  color: Colors.red,
                  loading: _loading,
                  onTap: _runFailingOp,
                ),
                const SizedBox(height: 6),
                _AsyncOpButton(
                  label: '🔄 Sync Sort (10k items)',
                  color: Colors.purple,
                  loading: false,
                  onTap: _runSyncOp,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Async Summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusRow('Total ops           ', '${ap.records.length}'),
                _StatusRow('Slow (>500ms) ', '${ap.slowOperations.length}'),
                _StatusRow(
                    'Failed                ', '${ap.failedOperations.length}'),
                const SizedBox(height: 8),
                Text(
                  ap.plainEnglishSummary,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Operation Log (${ap.records.length})',
            child: ap.records.isEmpty
                ? const Text(
                    'No operations yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  )
                : Column(
                    children: ap.records.reversed
                        .take(8)
                        .map((r) => _AsyncOpTile(record: r))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AsyncOpButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _AsyncOpButton({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: color),
        child: Text(label),
      );
}

class _AsyncOpTile extends StatelessWidget {
  final AsyncOperationRecord record;

  const _AsyncOpTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final isSlow = record.duration > const Duration(milliseconds: 500);
    final color = record.error != null
        ? Colors.red
        : isSlow
            ? Colors.orange
            : const Color(0xFF4CAF50);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              record.name,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            record.error != null
                ? '❌ error'
                : '${record.duration.inMilliseconds}ms',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE CACHE DEMO SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _ImageCacheDemoScreen extends StatefulWidget {
  const _ImageCacheDemoScreen();

  @override
  State<_ImageCacheDemoScreen> createState() => _ImageCacheDemoScreenState();
}

class _ImageCacheDemoScreenState extends State<_ImageCacheDemoScreen> {
  final List<String> _loadedUrls = [];
  ImageCacheSnapshot? _snap;

  static const _imageUrls = [
    'https://picsum.photos/seed/1/400/300',
    'https://picsum.photos/seed/2/400/300',
    'https://picsum.photos/seed/3/400/300',
    'https://picsum.photos/seed/4/400/300',
    'https://picsum.photos/seed/5/400/300',
    'https://picsum.photos/seed/6/400/300',
  ];

  void _loadImages() {
    setState(() {
      _loadedUrls.addAll(_imageUrls.where((u) => !_loadedUrls.contains(u)));
    });
    Future.delayed(const Duration(milliseconds: 500), _refreshSnap);
  }

  void _clearCache() {
    PerfGuard.instance.imageCacheAnalyzer.clearCache();
    setState(() {
      _loadedUrls.clear();
      _snap = null;
    });
    _refreshSnap();
  }

  void _refreshSnap() {
    setState(() {
      _snap = PerfGuard.instance.imageCacheAnalyzer.snapshot();
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshSnap();
  }

  @override
  Widget build(BuildContext context) {
    final ia = PerfGuard.instance.imageCacheAnalyzer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🖼 Image Cache'),
        backgroundColor: const Color(0xFF161B22),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSnap,
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _SectionCard(
            title: 'Cache Stats',
            child: Column(
              children: [
                if (_snap != null) ...[
                  _StatusRow('Cached images', '${_snap!.currentCount}'),
                  _StatusRow('Cache size        ',
                      '${_snap!.currentSizeMb.toStringAsFixed(2)}MB'),
                  _StatusRow('Max size           ',
                      '${_snap!.maxSizeMb.toStringAsFixed(1)}MB'),
                  _StatusRow('Usage               ',
                      '${(_snap!.usagePercent * 100).toStringAsFixed(0)}%'),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _snap!.usagePercent.clamp(0.0, 1.0),
                      backgroundColor: const Color(0xFF30363D),
                      valueColor: AlwaysStoppedAnimation(
                        _snap!.usagePercent > 0.85
                            ? Colors.red
                            : const Color(0xFF4CAF50),
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  ia.plainEnglishSummary,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Controls',
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loadImages,
                    icon: const Icon(Icons.download),
                    label: const Text('Load Images'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear Cache'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_loadedUrls.isNotEmpty)
            _SectionCard(
              title: 'Loaded Images (${_loadedUrls.length})',
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                ),
                itemCount: _loadedUrls.length,
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    _loadedUrls[i],
                    cacheWidth: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF30363D),
                      child: Icon(Icons.broken_image, color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERFORMANCE GRADER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _GraderScreen extends StatelessWidget {
  const _GraderScreen();

  @override
  Widget build(BuildContext context) {
    final grader = PerformanceGrader(
      frameProfiler: PerfGuard.instance.frameProfiler,
      memoryProfiler: PerfGuard.instance.memoryProfiler,
      rebuildTracker: PerfGuard.instance.rebuildTracker,
      navigationTracker: PerfGuard.instance.navigationTracker,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Performance Grade'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Overall grade card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              children: [
                Text(
                  grader.overallGrade.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                Text(
                  grader.overallGrade.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const Text(
                  'Overall Grade',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Per-category cards
          _GradeCard(
            category: 'Frames',
            grade: grader.gradeFrames(),
            summary: grader.frameSummary(),
          ),
          _GradeCard(
            category: 'Memory',
            grade: grader.gradeMemory(),
            summary: grader.memorySummary(),
          ),
          _GradeCard(
            category: 'Rebuilds',
            grade: grader.gradeRebuilds(),
            summary: grader.rebuildSummary(),
          ),
          _GradeCard(
            category: 'Navigation',
            grade: grader.gradeNavigation(),
            summary: grader.navigationSummary(),
          ),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final String category;
  final PerformanceGrade grade;
  final String summary;

  const _GradeCard({
    required this.category,
    required this.grade,
    required this.summary,
  });

  Color get _gradeColor {
    switch (grade) {
      case PerformanceGrade.A:
      case PerformanceGrade.B:
        return const Color(0xFF4CAF50);
      case PerformanceGrade.C:
        return const Color(0xFFFFEB3B);
      case PerformanceGrade.D:
        return const Color(0xFFFF9800);
      case PerformanceGrade.F:
        return const Color(0xFFF44336);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gradeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grade letter
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _gradeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gradeColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              grade.label,
              style: TextStyle(
                color: _gradeColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    color: Color(0xFF58A6FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BENCHMARK SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _BenchmarkScreen extends StatefulWidget {
  const _BenchmarkScreen();

  @override
  State<_BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _BenchmarkScreenState extends State<_BenchmarkScreen> {
  bool _running = false;
  List<BenchmarkResult> _results = [];

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results = [];
    });

    final suite = BenchmarkSuite(name: 'ExampleBenchmarks')
      ..add('list_sort_1k', () {
        final list = List.generate(1000, (i) => math.Random().nextInt(10000));
        list.sort();
        blackhole(list.last);
      })
      ..add('string_buffer_100', () {
        final buf = StringBuffer();
        for (int i = 0; i < 100; i++) {
          buf.write('x');
        }
        blackhole(buf.toString());
      })
      ..add('map_lookup_1k', () {
        final map = {for (int i = 0; i < 1000; i++) 'key_$i': i};
        blackhole(map['key_500']);
      })
      ..addAsync('future_microtask', () async {
        await Future.microtask(() => 42);
      });

    const runner = BenchmarkRunner(
      defaultWarmupRuns: 3,
      defaultMeasuredRuns: 10,
    );

    final results = await runner.run(suite);
    if (mounted) {
      setState(() {
        _results = results;
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏎 Benchmark Runner'),
        backgroundColor: const Color(0xFF161B22),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _SectionCard(
            title: 'Run Benchmarks',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Runs list sort, string buffer, map lookup, and async '
                  'benchmarks with warmup + statistical analysis '
                  '(mean, p95, p99, ops/s).',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_running ? 'Running…' : 'Run Suite'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_results.isNotEmpty)
            _SectionCard(
              title: 'Results',
              child: Column(
                children: _results
                    .map((r) => _BenchmarkResultTile(result: r))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _BenchmarkResultTile extends StatelessWidget {
  final BenchmarkResult result;

  const _BenchmarkResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.name,
            style: const TextStyle(
                color: Color(0xFF58A6FF),
                fontWeight: FontWeight.bold,
                fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              _StatChip('mean',
                  '${(result.mean.inMicroseconds / 1000).toStringAsFixed(2)}ms'),
              _StatChip('p95',
                  '${(result.p95.inMicroseconds / 1000).toStringAsFixed(2)}ms'),
              _StatChip('p99',
                  '${(result.p99.inMicroseconds / 1000).toStringAsFixed(2)}ms'),
              _StatChip('ops/s', result.opsPerSecond.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.all(14),
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
            const SizedBox(height: 10),
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
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: const Color(0xFF21262D),
      side: const BorderSide(color: Color(0xFF30363D)),
      onPressed: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UTILITIES
// ─────────────────────────────────────────────────────────────────────────────

/// Prevents dead-code elimination by the compiler.
@pragma('vm:never-inline')
void blackhole(dynamic value) {}
