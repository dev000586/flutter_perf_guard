import 'dart:convert';
import 'dart:io' show File, Directory;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../public_api/frame_profiler.dart';
import '../public_api/memory_profiler.dart';
import '../public_api/rebuild_tracker.dart';
import 'profiling_report.dart';

/// Assembles [ProfilingReport]s from all active profilers and writes them
/// to disk (native) or returns JSON strings (web).
class ReportExporter {
  final FrameProfiler _frameProfiler;
  final MemoryProfiler _memoryProfiler;
  final RebuildTracker _rebuildTracker;

  final DateTime _sessionStart = DateTime.now();
  late final String _sessionId;

  ReportExporter({
    required FrameProfiler frameProfiler,
    required MemoryProfiler memoryProfiler,
    required RebuildTracker rebuildTracker,
  })  :
        _frameProfiler = frameProfiler,
        _memoryProfiler = memoryProfiler,
        _rebuildTracker = rebuildTracker {
    _sessionId =
        'session_${_sessionStart.millisecondsSinceEpoch}';
  }

  /// Builds the current snapshot as a raw JSON map.
  Future<Map<String, dynamic>> buildSnapshotMap() async {
    final now = DateTime.now();
    return {
      'sessionId': _sessionId,
      'startTime': _sessionStart.toIso8601String(),
      'endTime': now.toIso8601String(),
      'sessionDurationMs': now.difference(_sessionStart).inMilliseconds,
      'frame': _frameProfiler.toJson(),
      'memory': _memoryProfiler.toJson(),
      'rebuild': _rebuildTracker.toJson(),
      'optimizationSuggestions': _generateSuggestions(),
    };
  }

  /// Exports the current snapshot to a JSON file and returns the file path.
  /// On web, returns the JSON string directly (file writes unsupported).
  Future<String> exportSnapshot({String? customPath}) async {
    final snapshot = await buildSnapshotMap();
    final json = const JsonEncoder.withIndent('  ').convert(snapshot);

    if (kIsWeb) {
      return json;
    }

    // Use app documents directory — always writable on all platforms.
    // Falls back to customPath if explicitly provided.
    final String dirPath;
    if (customPath != null) {
      dirPath = customPath;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      dirPath = '${appDir.path}/perf_guard_reports';
    }

    final directory = Directory(dirPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    final filename = 'perf_report_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('$dirPath/$filename');
    await file.writeAsString(json);
    return file.path;
  }

  List<Map<String, dynamic>> _generateSuggestions() {
    final suggestions = <Map<String, dynamic>>[];

    // Frame suggestions
    final jankRate = _frameProfiler.jankRate;
    if (jankRate > 0.05) {
      suggestions.add({
        'category': 'frame',
        'severity': 'critical',
        'message': 'High jank rate (${(jankRate * 100).toStringAsFixed(1)}%). '
            'Consider adding RepaintBoundary around expensive subtrees.',
        'metric': 'jankRate',
        'value': jankRate,
      });
    }

    // Memory suggestions
    final latestMem = _memoryProfiler.latest;
    if (latestMem != null && latestMem.heapUsagePercent > 0.80) {
      suggestions.add({
        'category': 'memory',
        'severity': 'warning',
        'message':
            'Heap usage at ${(latestMem.heapUsagePercent * 100).toStringAsFixed(0)}%. '
            'Check for retained objects or large image caches.',
        'metric': 'heapUsagePercent',
        'value': latestMem.heapUsagePercent,
      });
    }

    // Rebuild suggestions
    final excessiveRebuilds = _rebuildTracker.excessiveRebuilds;
    if (excessiveRebuilds.isNotEmpty) {
      suggestions.add({
        'category': 'rebuild',
        'severity': 'warning',
        'message':
            '${excessiveRebuilds.length} widget(s) rebuilding excessively. '
            'Top offender: ${excessiveRebuilds.first.widgetType}. '
            'Use const constructors or memoization.',
        'metric': 'excessiveRebuildCount',
        'value': excessiveRebuilds.length,
        'offenders': excessiveRebuilds
            .take(5)
            .map((m) => m.widgetType)
            .toList(),
      });
    }

    return suggestions;
  }
}
