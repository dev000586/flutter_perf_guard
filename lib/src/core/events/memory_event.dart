import '../../profiling/memory/memory_metrics.dart';
import '../events/performance_event.dart';

/// Event emitted when a memory sample is collected.
class MemoryEvent extends PerformanceEvent {
  final MemoryMetrics metrics;

  /// Whether a potential leak was detected since the last GC.
  final bool leakSuspected;

  /// Allocation delta since last event in bytes.
  final int allocationDelta;

  const MemoryEvent({
    required super.id,
    required super.timestamp,
    required super.source,
    required this.metrics,
    required this.leakSuspected,
    required this.allocationDelta,
    super.severity,
  });

  factory MemoryEvent.fromSample({
    required String id,
    required MemoryMetrics metrics,
    required int allocationDelta,
    required bool leakSuspected,
  }) {
    return MemoryEvent(
      id: id,
      timestamp: DateTime.now(),
      source: 'MemoryProfiler',
      metrics: metrics,
      leakSuspected: leakSuspected,
      allocationDelta: allocationDelta,
      severity: leakSuspected
          ? EventSeverity.critical
          : metrics.heapUsagePercent > 0.85
              ? EventSeverity.warning
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
        'leakSuspected': leakSuspected,
        'allocationDelta': allocationDelta,
      };

  @override
  List<Object?> get props => [
        ...super.props,
        metrics,
        leakSuspected,
        allocationDelta,
      ];
}
