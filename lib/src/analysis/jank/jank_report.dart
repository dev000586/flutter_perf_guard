import 'package:equatable/equatable.dart';

/// Aggregated report on jank events over a profiling session.
class JankReport extends Equatable {
  final int totalJankEvents;
  final int totalJankFrames;
  final int totalDroppedFrames;
  final Duration worstJankDuration;
  final double averageJankFps;
  final List<JankSegment> segments;
  final DateTime generatedAt;

  const JankReport({
    required this.totalJankEvents,
    required this.totalJankFrames,
    required this.totalDroppedFrames,
    required this.worstJankDuration,
    required this.averageJankFps,
    required this.segments,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'totalJankEvents': totalJankEvents,
        'totalJankFrames': totalJankFrames,
        'totalDroppedFrames': totalDroppedFrames,
        'worstJankMs': worstJankDuration.inMicroseconds / 1000,
        'averageJankFps': averageJankFps,
        'segments': segments.map((s) => s.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        totalJankEvents,
        totalJankFrames,
        totalDroppedFrames,
        worstJankDuration,
        generatedAt,
      ];
}

class JankSegment extends Equatable {
  final DateTime start;
  final Duration duration;
  final int frameCount;
  final int droppedFrames;
  final String? suspectedWidget;

  const JankSegment({
    required this.start,
    required this.duration,
    required this.frameCount,
    required this.droppedFrames,
    this.suspectedWidget,
  });

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'durationMs': duration.inMicroseconds / 1000,
        'frameCount': frameCount,
        'droppedFrames': droppedFrames,
        if (suspectedWidget != null) 'suspectedWidget': suspectedWidget,
      };

  @override
  List<Object?> get props =>
      [start, duration, frameCount, droppedFrames, suspectedWidget];
}
