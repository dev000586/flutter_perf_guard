import '../../profiling/rebuild/rebuild_metrics.dart';
import '../events/performance_event.dart';

/// Event emitted when a widget rebuild is recorded.
class RebuildEvent extends PerformanceEvent {
  final RebuildMetrics metrics;

  /// Whether this rebuild was unnecessary (same state, same constraints).
  final bool isUnnecessary;

  const RebuildEvent({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.metrics,
    required this.isUnnecessary,
    super.severity,
  });

  factory RebuildEvent.fromWidget({
    required String id,
    required RebuildMetrics metrics,
    required bool isUnnecessary,
  }) {
    return RebuildEvent(
      id: id,
      timestamp: DateTime.now(),
      source: 'RebuildTracker',
      metrics: metrics,
      isUnnecessary: isUnnecessary,
      severity: isUnnecessary
          ? EventSeverity.warning
          : metrics.rebuildCount > 60
              ? EventSeverity.critical
              : EventSeverity.info,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'severity': severity.label,
        'metrics': metrics.toJson(),
        'isUnnecessary': isUnnecessary,
      };

  @override
  List<Object?> get props => [...super.props, metrics, isUnnecessary];
}
