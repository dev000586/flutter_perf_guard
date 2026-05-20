import 'dart:ui';

import 'package:equatable/equatable.dart';

/// Comprehensive metrics for a single rendered frame.
class FrameMetrics extends Equatable {
  /// Sequential frame number since app start.
  final int frameNumber;

  /// Time spent building the widget tree.
  final Duration buildDuration;

  /// Time spent rasterizing to the GPU.
  final Duration rasterDuration;

  /// Total frame wall-clock duration (build + raster + GPU submit).
  final Duration totalDuration;

  /// GPU frame submission timestamp.
  final Duration vsyncOverhead;

  /// Start timestamp (microseconds from epoch).
  final int timestampMicros;

  const FrameMetrics({
    required this.frameNumber,
    required this.buildDuration,
    required this.rasterDuration,
    required this.totalDuration,
    required this.vsyncOverhead,
    required this.timestampMicros,
  });

  /// Constructs [FrameMetrics] from a Flutter [FrameTiming] object.
  factory FrameMetrics.fromTiming(FrameTiming timing, int frameNumber) {
    return FrameMetrics(
      frameNumber: frameNumber,
      buildDuration: timing.buildDuration,
      rasterDuration: timing.rasterDuration,
      totalDuration: timing.totalSpan,
      vsyncOverhead: timing.vsyncOverhead,
      timestampMicros: timing.timestampInMicroseconds(
        FramePhase.vsyncStart,
      ),
    );
  }

  /// Instantaneous FPS derived from [totalDuration].
  double get fps =>
      totalDuration.inMicroseconds > 0
          ? 1000000 / totalDuration.inMicroseconds
          : 60.0;

  /// Whether this frame is considered janky (> 16 ms total).
  bool get isJank => totalDuration > const Duration(milliseconds: 16);

  /// Whether this frame is slow (> 8 ms total).
  bool get isSlow => totalDuration > const Duration(milliseconds: 8);

  /// Build fraction (0–1) of total frame time.
  double get buildFraction =>
      totalDuration.inMicroseconds > 0
          ? buildDuration.inMicroseconds / totalDuration.inMicroseconds
          : 0.0;

  /// Raster fraction (0–1) of total frame time.
  double get rasterFraction =>
      totalDuration.inMicroseconds > 0
          ? rasterDuration.inMicroseconds / totalDuration.inMicroseconds
          : 0.0;

  Map<String, dynamic> toJson() => {
        'frameNumber': frameNumber,
        'buildDurationMicros': buildDuration.inMicroseconds,
        'rasterDurationMicros': rasterDuration.inMicroseconds,
        'totalDurationMicros': totalDuration.inMicroseconds,
        'vsyncOverheadMicros': vsyncOverhead.inMicroseconds,
        'timestampMicros': timestampMicros,
        'fps': fps,
        'isJank': isJank,
        'isSlow': isSlow,
      };

  @override
  List<Object?> get props => [
        frameNumber,
        buildDuration,
        rasterDuration,
        totalDuration,
        vsyncOverhead,
        timestampMicros,
      ];

  @override
  String toString() =>
      'FrameMetrics(#$frameNumber, total=${totalDuration.inMilliseconds}ms, '
      'build=${buildDuration.inMilliseconds}ms, '
      'raster=${rasterDuration.inMilliseconds}ms, fps=${fps.toStringAsFixed(1)})';
}
