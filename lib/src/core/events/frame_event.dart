import 'package:flutter/scheduler.dart';

import '../../profiling/frame/frame_metrics.dart';
import '../events/performance_event.dart';

/// Event emitted after each rendered frame, carrying timing diagnostics.
class FrameEvent extends PerformanceEvent {
  /// Full frame metrics for this rendered frame.
  final FrameMetrics metrics;

  /// Whether this frame was classified as a jank frame (> 16 ms build/raster).
  final bool isJank;

  /// Whether this frame exceeded the slow-frame threshold (> 8 ms).
  final bool isSlow;

  const FrameEvent({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.metrics,
    required this.isJank,
    required this.isSlow,
    super.severity,
  });

  factory FrameEvent.fromTimings({
    required String id,
    required FrameTiming timing,
    required int frameNumber,
  }) {
    final metrics = FrameMetrics.fromTiming(timing, frameNumber);
    final isJank = metrics.totalDuration > const Duration(milliseconds: 16);
    final isSlow = metrics.totalDuration > const Duration(milliseconds: 8);

    return FrameEvent(
      id: id,
      timestamp: DateTime.now(),
      source: 'FrameProfiler',
      metrics: metrics,
      isJank: isJank,
      isSlow: isSlow,
      severity: isJank ? EventSeverity.warning : EventSeverity.info,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'severity': severity.label,
        'metrics': metrics.toJson(),
        'isJank': isJank,
        'isSlow': isSlow,
      };

  @override
  List<Object?> get props => [...super.props, metrics, isJank, isSlow];
}
