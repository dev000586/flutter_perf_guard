import 'dart:async';
import 'dart:collection';

import 'package:flutter/scheduler.dart';

import '../core/bus/diagnostics_event_bus.dart';
import '../core/events/frame_event.dart';
import '../core/events/jank_event.dart';
import '../core/events/performance_event.dart';
import '../profiling/frame/frame_metrics.dart';
import 'perf_guard_config.dart';

/// Hooks into Flutter's [SchedulerBinding.addTimingsCallback] to collect
/// per-frame build and raster durations, detect jank, and emit events.
class FrameProfiler {
  final PerfGuardConfig _config;
  final DiagnosticsEventBus _bus;

  bool _running = false;
  bool _paused = false;
  int _frameNumber = 0;
  int _consecutiveJankFrames = 0;
  final Queue<FrameMetrics> _history = Queue();
  final List<Duration> _jankWindow = [];

  // Running stats
  int _totalFrames = 0;
  int _jankFrames = 0;
  int _slowFrames = 0;
  Duration _totalFrameTime = Duration.zero;
  Duration _worstFrame = Duration.zero;

  StreamSubscription<FrameEvent>? _selfSub;

  FrameProfiler({required PerfGuardConfig config, required DiagnosticsEventBus bus})
      : _config = config,
        _bus = bus;

  // ─── Lifecycle ────────────────────────────────────────────────────────

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _paused = false;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _selfSub = _bus.frameEvents.listen(_onFrameEvent);
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    await _selfSub?.cancel();
    _selfSub = null;
  }

  void pause() => _paused = true;
  void resume() => _paused = false;

  // ─── Callback ─────────────────────────────────────────────────────────

  void _onTimings(List<FrameTiming> timings) {
    if (_paused || !_running) return;
    for (final timing in timings) {
      _processFrame(timing);
    }
  }

  void _processFrame(FrameTiming timing) {
    _frameNumber++;
    final metrics = FrameMetrics.fromTiming(timing, _frameNumber);

    // Rolling history
    _history.addLast(metrics);
    if (_history.length > _config.frameHistorySize) {
      _history.removeFirst();
    }

    // Running stats
    _totalFrames++;
    _totalFrameTime += metrics.totalDuration;
    if (metrics.isJank) {
      _jankFrames++;
      _consecutiveJankFrames++;
      _jankWindow.add(metrics.totalDuration);
      if (metrics.totalDuration > _worstFrame) {
        _worstFrame = metrics.totalDuration;
      }
    } else {
      // Emit jank group if we had consecutive jank frames
      if (_consecutiveJankFrames >= _config.consecutiveJankFramesThreshold) {
        _emitJankEvent();
      }
      _consecutiveJankFrames = 0;
      _jankWindow.clear();
    }

    if (metrics.isSlow) _slowFrames++;

    // Emit frame event
    final event = FrameEvent.fromTimings(
      id: 'frame_$_frameNumber',
      timing: timing,
      frameNumber: _frameNumber,
    );
    _bus.emit(event);
  }

  void _emitJankEvent() {
    if (_jankWindow.isEmpty) return;

    final totalMicros = _jankWindow.fold<int>(
        0, (sum, d) => sum + d.inMicroseconds);
    final avg = Duration(microseconds: totalMicros ~/ _jankWindow.length);
    final worst = _jankWindow.reduce((a, b) => a > b ? a : b);
    final dropped = (_jankWindow.length * (avg.inMilliseconds / 16.0)).round();

    final event = JankEvent(
      id: 'jank_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      source: 'FrameProfiler',
      consecutiveJankFrames: _consecutiveJankFrames,
      worstFrameDuration: worst,
      averageFrameDuration: avg,
      droppedFrames: dropped,
      severity: EventSeverity.critical,
    );
    _bus.emit(event);
  }

  void _onFrameEvent(FrameEvent event) {
    // Hook for subclasses or listeners – intentionally lightweight.
  }

  // ─── Computed stats ───────────────────────────────────────────────────

  /// Current rolling FPS based on the last [windowSize] frames.
  double currentFps({int windowSize = 60}) {
    final frames = _history.toList();
    if (frames.isEmpty) return 0.0;
    final window = frames.length > windowSize
        ? frames.sublist(frames.length - windowSize)
        : frames;
    final totalMicros = window.fold<int>(
        0, (sum, m) => sum + m.totalDuration.inMicroseconds);
    if (totalMicros <= 0) return 0.0;
    return window.length / (totalMicros / 1000000.0);
  }

  /// Average frame time across all recorded frames.
  Duration get averageFrameTime {
    if (_totalFrames == 0) return Duration.zero;
    return Duration(
        microseconds: _totalFrameTime.inMicroseconds ~/ _totalFrames);
  }

  /// Jank rate as a fraction (0–1).
  double get jankRate =>
      _totalFrames > 0 ? _jankFrames / _totalFrames : 0.0;

  /// All recorded [FrameMetrics] in chronological order.
  List<FrameMetrics> get history => _history.toList();

  int get totalFrames => _totalFrames;
  int get jankFrames => _jankFrames;
  int get slowFrames => _slowFrames;
  Duration get worstFrameDuration => _worstFrame;

  Map<String, dynamic> toJson() => {
        'totalFrames': _totalFrames,
        'jankFrames': _jankFrames,
        'slowFrames': _slowFrames,
        'jankRate': jankRate,
        'currentFps': currentFps(),
        'averageFrameTimeMs': averageFrameTime.inMicroseconds / 1000,
        'worstFrameMs': _worstFrame.inMicroseconds / 1000,
        'historySize': _history.length,
      };
}
