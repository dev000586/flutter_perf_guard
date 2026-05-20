/// Configuration for the flutter_perf_guard toolkit.
///
/// Pass a [PerfGuardConfig] to [PerfGuard.initialize] to customize which
/// modules are active, thresholds, sampling rates, and export settings.
class PerfGuardConfig {
  // ─── Module toggles ────────────────────────────────────────────────────

  /// Enable frame timing profiling.
  final bool enableFrameProfiler;

  /// Enable memory profiling and leak detection.
  final bool enableMemoryProfiler;

  /// Enable widget rebuild tracking.
  final bool enableRebuildTracker;

  /// Enable jank detection.
  final bool enableJankDetector;

  /// Enable the real-time performance dashboard overlay.
  final bool enableDashboard;

  /// Enable startup performance analyzer.
  final bool enableStartupAnalyzer;

  /// Enable navigation performance tracking.
  final bool enableNavigationTracker;

  /// Enable async task profiling.
  final bool enableAsyncProfiler;

  /// Enable network request profiling.
  final bool enableNetworkProfiler;

  /// Enable repaint boundary analyzer.
  final bool enableRepaintAnalyzer;

  /// Enable layout overdraw analysis.
  final bool enableOverdrawAnalyzer;

  // ─── Thresholds ────────────────────────────────────────────────────────

  /// Frame duration above which a frame is marked as janky.
  final Duration jankThreshold;

  /// Frame duration above which a frame is marked as slow.
  final Duration slowFrameThreshold;

  /// Consecutive jank frames before a [JankEvent] is emitted.
  final int consecutiveJankFramesThreshold;

  /// Heap usage fraction (0–1) above which a memory warning is emitted.
  final double memoryWarningThreshold;

  /// Heap usage fraction (0–1) above which a memory critical event is emitted.
  final double memoryCriticalThreshold;

  /// Rebuild count per second above which a widget is flagged excessive.
  final double excessiveRebuildRatePerSecond;

  // ─── Sampling ──────────────────────────────────────────────────────────

  /// How often to sample memory metrics.
  final Duration memorySamplingInterval;

  /// Maximum number of frame metrics to keep in the rolling buffer.
  final int frameHistorySize;

  /// Maximum number of rebuild records to keep per widget type.
  final int rebuildHistorySize;

  // ─── Export ────────────────────────────────────────────────────────────

  /// Whether to auto-export reports when a critical event is detected.
  final bool autoExportOnCritical;

  /// Directory path where exported reports are stored.
  final String exportDirectory;

  // ─── Debug ─────────────────────────────────────────────────────────────

  /// Whether verbose logging is enabled.
  final bool verbose;

  /// Whether to show the debug overlay in release builds.
  /// ⚠ Enable only for internal/enterprise testing – never for public releases.
  final bool showOverlayInRelease;

  const PerfGuardConfig({
    this.enableFrameProfiler = true,
    this.enableMemoryProfiler = true,
    this.enableRebuildTracker = true,
    this.enableJankDetector = true,
    this.enableDashboard = true,
    this.enableStartupAnalyzer = true,
    this.enableNavigationTracker = true,
    this.enableAsyncProfiler = false,
    this.enableNetworkProfiler = false,
    this.enableRepaintAnalyzer = false,
    this.enableOverdrawAnalyzer = false,
    this.jankThreshold = const Duration(milliseconds: 16),
    this.slowFrameThreshold = const Duration(milliseconds: 8),
    this.consecutiveJankFramesThreshold = 3,
    this.memoryWarningThreshold = 0.80,
    this.memoryCriticalThreshold = 0.92,
    this.excessiveRebuildRatePerSecond = 60.0,
    this.memorySamplingInterval = const Duration(seconds: 2),
    this.frameHistorySize = 300,
    this.rebuildHistorySize = 100,
    this.autoExportOnCritical = false,
    this.exportDirectory = '/tmp/perf_guard_reports',
    this.verbose = false,
    this.showOverlayInRelease = false,
  });

  /// A minimal config suitable for profiling with lowest overhead.
  static const PerfGuardConfig minimal = PerfGuardConfig(
    enableFrameProfiler: true,
    enableMemoryProfiler: false,
    enableRebuildTracker: false,
    enableJankDetector: true,
    enableDashboard: false,
    enableStartupAnalyzer: false,
    enableNavigationTracker: false,
    enableAsyncProfiler: false,
    enableNetworkProfiler: false,
  );

  /// Full config with all modules enabled.
  static const PerfGuardConfig full = PerfGuardConfig(
    enableFrameProfiler: true,
    enableMemoryProfiler: true,
    enableRebuildTracker: true,
    enableJankDetector: true,
    enableDashboard: true,
    enableStartupAnalyzer: true,
    enableNavigationTracker: true,
    enableAsyncProfiler: true,
    enableNetworkProfiler: true,
    enableRepaintAnalyzer: true,
    enableOverdrawAnalyzer: true,
  );

  PerfGuardConfig copyWith({
    bool? enableFrameProfiler,
    bool? enableMemoryProfiler,
    bool? enableRebuildTracker,
    bool? enableJankDetector,
    bool? enableDashboard,
    bool? enableStartupAnalyzer,
    bool? enableNavigationTracker,
    bool? enableAsyncProfiler,
    bool? enableNetworkProfiler,
    bool? enableRepaintAnalyzer,
    bool? enableOverdrawAnalyzer,
    Duration? jankThreshold,
    Duration? slowFrameThreshold,
    int? consecutiveJankFramesThreshold,
    double? memoryWarningThreshold,
    double? memoryCriticalThreshold,
    double? excessiveRebuildRatePerSecond,
    Duration? memorySamplingInterval,
    int? frameHistorySize,
    int? rebuildHistorySize,
    bool? autoExportOnCritical,
    String? exportDirectory,
    bool? verbose,
    bool? showOverlayInRelease,
  }) {
    return PerfGuardConfig(
      enableFrameProfiler: enableFrameProfiler ?? this.enableFrameProfiler,
      enableMemoryProfiler: enableMemoryProfiler ?? this.enableMemoryProfiler,
      enableRebuildTracker: enableRebuildTracker ?? this.enableRebuildTracker,
      enableJankDetector: enableJankDetector ?? this.enableJankDetector,
      enableDashboard: enableDashboard ?? this.enableDashboard,
      enableStartupAnalyzer: enableStartupAnalyzer ?? this.enableStartupAnalyzer,
      enableNavigationTracker:
          enableNavigationTracker ?? this.enableNavigationTracker,
      enableAsyncProfiler: enableAsyncProfiler ?? this.enableAsyncProfiler,
      enableNetworkProfiler: enableNetworkProfiler ?? this.enableNetworkProfiler,
      enableRepaintAnalyzer: enableRepaintAnalyzer ?? this.enableRepaintAnalyzer,
      enableOverdrawAnalyzer:
          enableOverdrawAnalyzer ?? this.enableOverdrawAnalyzer,
      jankThreshold: jankThreshold ?? this.jankThreshold,
      slowFrameThreshold: slowFrameThreshold ?? this.slowFrameThreshold,
      consecutiveJankFramesThreshold: consecutiveJankFramesThreshold ??
          this.consecutiveJankFramesThreshold,
      memoryWarningThreshold:
          memoryWarningThreshold ?? this.memoryWarningThreshold,
      memoryCriticalThreshold:
          memoryCriticalThreshold ?? this.memoryCriticalThreshold,
      excessiveRebuildRatePerSecond:
          excessiveRebuildRatePerSecond ?? this.excessiveRebuildRatePerSecond,
      memorySamplingInterval:
          memorySamplingInterval ?? this.memorySamplingInterval,
      frameHistorySize: frameHistorySize ?? this.frameHistorySize,
      rebuildHistorySize: rebuildHistorySize ?? this.rebuildHistorySize,
      autoExportOnCritical: autoExportOnCritical ?? this.autoExportOnCritical,
      exportDirectory: exportDirectory ?? this.exportDirectory,
      verbose: verbose ?? this.verbose,
      showOverlayInRelease: showOverlayInRelease ?? this.showOverlayInRelease,
    );
  }
}
