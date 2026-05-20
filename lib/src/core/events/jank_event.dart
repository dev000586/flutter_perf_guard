import '../events/performance_event.dart';

/// Event emitted when a jank frame sequence is detected.
class JankEvent extends PerformanceEvent {
  /// Number of consecutive jank frames.
  final int consecutiveJankFrames;

  /// Duration of the worst frame in the sequence.
  final Duration worstFrameDuration;

  /// Average frame duration across the jank window.
  final Duration averageFrameDuration;

  /// Estimated dropped frames count.
  final int droppedFrames;

  /// Widget path hint if the culprit was identified.
  final String? culpritWidgetPath;

  const JankEvent({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.consecutiveJankFrames,
    required this.worstFrameDuration,
    required this.averageFrameDuration,
    required this.droppedFrames,
    this.culpritWidgetPath,
    super.severity = EventSeverity.critical,
  });

  /// FPS equivalent for the average frame duration.
  double get averageFps =>
      averageFrameDuration.inMicroseconds > 0
          ? 1000000 / averageFrameDuration.inMicroseconds
          : 0.0;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'severity': severity.label,
        'consecutiveJankFrames': consecutiveJankFrames,
        'worstFrameDurationMs': worstFrameDuration.inMicroseconds / 1000,
        'averageFrameDurationMs': averageFrameDuration.inMicroseconds / 1000,
        'droppedFrames': droppedFrames,
        'averageFps': averageFps,
        if (culpritWidgetPath != null) 'culpritWidgetPath': culpritWidgetPath,
      };

  @override
  List<Object?> get props => [
        ...super.props,
        consecutiveJankFrames,
        worstFrameDuration,
        averageFrameDuration,
        droppedFrames,
        culpritWidgetPath,
      ];
}
