import 'package:equatable/equatable.dart';

/// Base class for all performance events flowing through the diagnostics bus.
abstract class PerformanceEvent extends Equatable {
  /// Unique event identifier.
  final String id;

  /// Timestamp when this event was captured.
  final DateTime timestamp;

  /// Source tag identifying the component that emitted this event.
  final String source;

  /// Optional severity level.
  final EventSeverity severity;

  const PerformanceEvent({
    required this.id,
    required this.timestamp,
    required this.source,
    this.severity = EventSeverity.info,
  });

  /// Converts this event to a JSON-serializable map.
  Map<String, dynamic> toJson();

  @override
  List<Object?> get props => [id, timestamp, source, severity];
}

/// Severity levels for performance events.
enum EventSeverity {
  /// Informational – no action needed.
  info,

  /// Warning – performance degradation observed.
  warning,

  /// Critical – severe performance issue requiring immediate attention.
  critical,
}

/// Extension helpers on [EventSeverity].
extension EventSeverityX on EventSeverity {
  bool get isInfo => this == EventSeverity.info;
  bool get isWarning => this == EventSeverity.warning;
  bool get isCritical => this == EventSeverity.critical;

  String get label {
    switch (this) {
      case EventSeverity.info:
        return 'INFO';
      case EventSeverity.warning:
        return 'WARNING';
      case EventSeverity.critical:
        return 'CRITICAL';
    }
  }
}
