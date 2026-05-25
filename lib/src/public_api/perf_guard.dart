import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/bus/diagnostics_event_bus.dart';
import '../export/report_exporter.dart';
import '../monitoring/async/async_profiler.dart';
import '../monitoring/image/image_cache_analyzer.dart';
import '../monitoring/navigation/navigation_tracker.dart';
import '../monitoring/network/network_profiler.dart';
import '../monitoring/startup/startup_analyzer.dart';
import 'frame_profiler.dart';
import 'memory_profiler.dart';
import 'perf_guard_config.dart';
import 'performance_monitor.dart';
import 'rebuild_tracker.dart';
import 'timeline_recorder.dart';

/// Main entry point for flutter_perf_guard.
///
/// Initialize once in [main] or [runApp]:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await PerfGuard.initialize(config: PerfGuardConfig.full);
///   runApp(const MyApp());
/// }
/// ```
class PerfGuard {
  PerfGuard._();

  static PerfGuard? _instance;

  late final PerfGuardConfig _config;
  late final DiagnosticsEventBus _bus;
  late final PerformanceMonitor _monitor;
  late final FrameProfiler _frameProfiler;
  late final MemoryProfiler _memoryProfiler;
  late final RebuildTracker _rebuildTracker;
  late final TimelineRecorder _timelineRecorder;
  late final StartupAnalyzer _startupAnalyzer;
  late final NavigationTracker _navigationTracker;
  late final ReportExporter _exporter;
  late final NetworkProfiler _networkProfiler;
  late final AsyncProfiler _asyncProfiler;
  late final ImageCacheAnalyzer _imageCacheAnalyzer;

  bool _initialized = false;
  final Stopwatch _uptime = Stopwatch();

  // ─── Public accessors ──────────────────────────────────────────────────

  /// Global singleton. Call [initialize] before accessing.
  static PerfGuard get instance {
    assert(_instance != null,
        'PerfGuard.initialize() must be called before accessing PerfGuard.instance');
    return _instance!;
  }

  static bool get isInitialized => _instance?._initialized ?? false;

  PerfGuardConfig get config => _config;
  DiagnosticsEventBus get bus => _bus;
  PerformanceMonitor get monitor => _monitor;
  FrameProfiler get frameProfiler => _frameProfiler;
  MemoryProfiler get memoryProfiler => _memoryProfiler;
  RebuildTracker get rebuildTracker => _rebuildTracker;
  TimelineRecorder get timelineRecorder => _timelineRecorder;
  StartupAnalyzer get startupAnalyzer => _startupAnalyzer;
  NavigationTracker get navigationTracker => _navigationTracker;
  ReportExporter get exporter => _exporter;

  Duration get uptime => _uptime.elapsed;
  NetworkProfiler get networkProfiler => _networkProfiler;
  AsyncProfiler get asyncProfiler => _asyncProfiler;
  ImageCacheAnalyzer get imageCacheAnalyzer => _imageCacheAnalyzer;

  // ─── Lifecycle ─────────────────────────────────────────────────────────

  /// Initializes the PerfGuard toolkit.
  ///
  /// Safe to call multiple times – subsequent calls are no-ops unless
  /// [forceReinit] is true.
  static Future<void> initialize({
    PerfGuardConfig config = const PerfGuardConfig(),
    bool forceReinit = false,
  }) async {
    if (_instance != null && !forceReinit) return;

    // Dispose previous instance if reinitializing
    if (_instance != null) {
      await _instance!.dispose();
    }

    final guard = PerfGuard._();
    await guard._init(config);
    _instance = guard;
  }

  Future<void> _init(PerfGuardConfig config) async {
    _config = config;
    _bus = DiagnosticsEventBus.instance;
    _uptime.start();

    if (kDebugMode || config.showOverlayInRelease) {
      _log('PerfGuard initializing...');
    }

    // Core monitor
    _monitor = PerformanceMonitor(bus: _bus);

    // Profilers
    _frameProfiler = FrameProfiler(config: config, bus: _bus);
    _memoryProfiler = MemoryProfiler(config: config, bus: _bus);
    _rebuildTracker = RebuildTracker(config: config, bus: _bus);
    _timelineRecorder = TimelineRecorder(bus: _bus);
    _networkProfiler = NetworkProfiler(bus: _bus);
    _asyncProfiler = AsyncProfiler(bus: _bus);
    _imageCacheAnalyzer = ImageCacheAnalyzer();


    // Analyzers
    _startupAnalyzer = StartupAnalyzer(bus: _bus);
    _navigationTracker = NavigationTracker(bus: _bus);

    // Exporter
    _exporter = ReportExporter(
      frameProfiler: _frameProfiler,
      memoryProfiler: _memoryProfiler,
      rebuildTracker: _rebuildTracker,
      navigationTracker: _navigationTracker,
      networkProfiler: config.enableNetworkProfiler ? _networkProfiler : null,
      asyncProfiler: config.enableAsyncProfiler ? _asyncProfiler : null,
    );

    // Start enabled modules
    if (config.enableNetworkProfiler) {
      NetworkProfiler.install(
        profiler: _networkProfiler,
      );
    }

    if (config.enableFrameProfiler) {
      await _frameProfiler.start();
    }
    if (config.enableMemoryProfiler) {
      await _memoryProfiler.start();
    }
    if (config.enableRebuildTracker) {
      _rebuildTracker.install();
    }
    if (config.enableStartupAnalyzer) {
      _startupAnalyzer.markAppStart();
    }

    // Auto-export on critical events
    if (config.autoExportOnCritical) {
      _bus.criticalEvents.listen((_) async {
        await _exporter.exportSnapshot();
      });
    }

    _initialized = true;
    _log('PerfGuard initialized ($_activeModuleCount modules active)');
  }

  int get _activeModuleCount {
    int count = 0;
    if (_config.enableFrameProfiler) count++;
    if (_config.enableMemoryProfiler) count++;
    if (_config.enableRebuildTracker) count++;
    if (_config.enableJankDetector) count++;
    if (_config.enableStartupAnalyzer) count++;
    if (_config.enableNavigationTracker) count++;
    return count;
  }

  /// Pauses all active profilers (e.g. when app goes to background).
  void pause() {
    _frameProfiler.pause();
    _memoryProfiler.pause();
    _log('PerfGuard paused');
  }

  /// Resumes all paused profilers.
  void resume() {
    _frameProfiler.resume();
    _memoryProfiler.resume();
    _log('PerfGuard resumed');
  }

  /// Disposes all resources and stops all profilers.
  Future<void> dispose() async {
    await _frameProfiler.stop();
    await _memoryProfiler.stop();
    _rebuildTracker.uninstall();
    _timelineRecorder.stop();
    _uptime.stop();
    _initialized = false;
    _log('PerfGuard disposed');
  }

  // ─── Convenience shortcuts ─────────────────────────────────────────────

  /// Takes a performance snapshot and returns it as a JSON-serializable map.
  Future<Map<String, dynamic>> takeSnapshot() async {
    return _exporter.buildSnapshotMap();
  }

  /// Exports the current profiling report to the configured [exportDirectory].
  Future<String> exportReport({String? customPath, ReportFormat format = ReportFormat.text}) async {
    return _exporter.exportSnapshot(customPath: customPath, format: format);
  }

  void _log(String message) {
    if (_config.verbose || kDebugMode) {
      // ignore: avoid_print
      print('[PerfGuard] $message');
    }
  }
}
