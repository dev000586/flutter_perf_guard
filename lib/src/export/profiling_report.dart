import 'dart:convert';

/// A complete profiling report snapshot capturing state of all profilers.
class ProfilingReport {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final Duration sessionDuration;
  final Map<String, dynamic> frameStats;
  final Map<String, dynamic> memoryStats;
  final Map<String, dynamic> rebuildStats;
  final Map<String, dynamic> startupStats;
  final Map<String, dynamic> navigationStats;
  final List<Map<String, dynamic>> criticalEvents;
  final List<Map<String, dynamic>> optimizationSuggestions;

  const ProfilingReport({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.sessionDuration,
    required this.frameStats,
    required this.memoryStats,
    required this.rebuildStats,
    required this.startupStats,
    required this.navigationStats,
    required this.criticalEvents,
    required this.optimizationSuggestions,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'sessionDurationMs': sessionDuration.inMilliseconds,
        'frame': frameStats,
        'memory': memoryStats,
        'rebuild': rebuildStats,
        'startup': startupStats,
        'navigation': navigationStats,
        'criticalEvents': criticalEvents,
        'optimizationSuggestions': optimizationSuggestions,
        'generatedBy': 'flutter_perf_guard v1.0.0',
      };

  String toJsonString({bool pretty = true}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toJson())
      : jsonEncode(toJson());
}
