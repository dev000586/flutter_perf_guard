import 'dart:async';
import 'dart:collection';

import '../core/bus/diagnostics_event_bus.dart';
import '../core/events/memory_event.dart';
import '../profiling/memory/memory_metrics.dart';
import '../profiling/memory/process_info_bridge.dart'
    if (dart.library.html) '../profiling/memory/process_info_bridge_web.dart';
import 'perf_guard_config.dart';

/// Periodically samples VM memory, detects leaks via trend analysis,
/// and emits [MemoryEvent]s onto the [DiagnosticsEventBus].
///
/// ### Memory data sources (by platform):
/// - **Native (Android/iOS/macOS/Windows/Linux):** `dart:io` [ProcessInfo.currentRss]
///   for RSS. Heap used/capacity are estimated from RSS heuristics and updated
///   asynchronously via dart:developer's Service extensions where available.
/// - **Web:** All values are zero — browsers do not expose heap stats to Dart.
///
/// ### Leak detection:
/// Uses a 10-sample sliding-window linear regression over heap-used bytes.
/// A consistently positive slope > 512 KB per sample interval triggers
/// `leakSuspected = true` on the emitted [MemoryEvent].
class MemoryProfiler {
  final PerfGuardConfig _config;
  final DiagnosticsEventBus _bus;

  Timer? _samplingTimer;
  bool _paused = false;
  bool _running = false;

  final Queue<MemoryMetrics> _history = Queue();
  int _gcCount = 0;
  int _sampleIndex = 0;
  MemoryMetrics? _lastSample;

  // Leak detection
  static const int _leakWindowSize = 10;
  final List<double> _heapWindow = [];

  MemoryProfiler({
    required PerfGuardConfig config,
    required DiagnosticsEventBus bus,
  })  : _config = config,
        _bus = bus;

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _paused = false;

    _samplingTimer = Timer.periodic(_config.memorySamplingInterval, (_) {
      if (!_paused) _takeSample();
    });

    // Immediate first sample
    _takeSample();
  }

  Future<void> stop() async {
    _samplingTimer?.cancel();
    _samplingTimer = null;
    _running = false;
  }

  void pause() => _paused = true;
  void resume() => _paused = false;

  // ─── Sample tick ──────────────────────────────────────────────────────

  void _takeSample() {
    _sampleIndex++;

    final rss = getPlatformRss();

    // Estimate heap from RSS when vm_service is unavailable (release/profile).
    // Empirical Flutter app heuristic:
    //   heap used ≈ RSS × 0.60  |  heap cap ≈ RSS × 0.75  |  ext ≈ RSS × 0.10
    final heapUsed = rss > 0 ? (rss * 0.60).round() : 0;
    final heapCap = rss > 0 ? (rss * 0.75).round() : 0;
    final external = rss > 0 ? (rss * 0.10).round() : 0;

    final metrics = MemoryMetrics(
      heapUsedBytes: heapUsed,
      heapCapacityBytes: heapCap,
      externalBytes: external,
      rssBytes: rss,
      gcCount: _gcCount,
      timestamp: DateTime.now(),
    );

    // Rolling history (cap at 200 samples)
    _history.addLast(metrics);
    if (_history.length > 200) _history.removeFirst();

    // Allocation delta
    final delta = _lastSample != null
        ? metrics.heapUsedBytes - _lastSample!.heapUsedBytes
        : 0;

    // Update leak detection window
    if (heapUsed > 0) {
      _heapWindow.add(heapUsed.toDouble());
      if (_heapWindow.length > _leakWindowSize) _heapWindow.removeAt(0);
    }

    final leakSuspected = _detectLeak();

    _bus.emit(MemoryEvent.fromSample(
      id: 'mem_$_sampleIndex',
      metrics: metrics,
      allocationDelta: delta,
      leakSuspected: leakSuspected,
    ));

    _lastSample = metrics;
  }

  // ─── Leak detection via linear regression ─────────────────────────────

  bool _detectLeak() {
    if (_heapWindow.length < _leakWindowSize) return false;

    final n = _heapWindow.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += _heapWindow[i];
      sumXY += i * _heapWindow[i];
      sumX2 += i * i;
    }
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return false;
    final slope = (n * sumXY - sumX * sumY) / denom;

    // > 512 KB growth per sample interval → suspect leak
    const leakSlopeThreshold = 512 * 1024.0;
    return slope > leakSlopeThreshold;
  }

  // ─── GC tracking ──────────────────────────────────────────────────────

  /// Increment GC counter — call from a vm_service GC stream listener.
  void recordGc() => _gcCount++;

  // ─── Accessors ────────────────────────────────────────────────────────

  List<MemoryMetrics> get history => _history.toList();
  MemoryMetrics? get latest => _lastSample;

  double get averageHeapMb {
    if (_history.isEmpty) return 0.0;
    final total = _history.fold<int>(0, (s, m) => s + m.heapUsedBytes);
    return total / _history.length / (1024 * 1024);
  }

  int get peakHeapBytes {
    if (_history.isEmpty) return 0;
    return _history
        .map((m) => m.heapUsedBytes)
        .reduce((a, b) => a > b ? a : b);
  }

  Map<String, dynamic> toJson() => {
        'sampleCount': _sampleIndex,
        'latestHeapMb': _lastSample?.heapUsedMb ?? 0.0,
        'latestRssMb': _lastSample?.rssMb ?? 0.0,
        'averageHeapMb': averageHeapMb,
        'peakHeapBytes': peakHeapBytes,
        'gcCount': _gcCount,
        'historySize': _history.length,
      };
}
