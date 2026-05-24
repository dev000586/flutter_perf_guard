import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../analysis/grader/performance_grader.dart';
import '../monitoring/async/async_profiler.dart';
import '../monitoring/image/image_cache_analyzer.dart';
import '../monitoring/navigation/navigation_tracker.dart';
import '../monitoring/network/network_profiler.dart';
import '../public_api/frame_profiler.dart';
import '../public_api/memory_profiler.dart';
import '../public_api/rebuild_tracker.dart';
import 'file_writer.dart'
if (dart.library.html) 'file_writer_web.dart';
import 'formatters/text_formatter.dart';

enum ReportFormat { json, text }

class ReportExporter {
  final FrameProfiler _frameProfiler;
  final MemoryProfiler _memoryProfiler;
  final RebuildTracker _rebuildTracker;
  final NavigationTracker _navigationTracker;
  final NetworkProfiler? _networkProfiler;
  final AsyncProfiler? _asyncProfiler;
  final ImageCacheAnalyzer _imageCacheAnalyzer = ImageCacheAnalyzer();

  final DateTime _sessionStart = DateTime.now();
  late final String _sessionId;

  ReportExporter({
    required FrameProfiler frameProfiler,
    required MemoryProfiler memoryProfiler,
    required RebuildTracker rebuildTracker,
    required NavigationTracker navigationTracker,
    NetworkProfiler? networkProfiler,
    AsyncProfiler? asyncProfiler,
  })  : _frameProfiler = frameProfiler,
        _memoryProfiler = memoryProfiler,
        _rebuildTracker = rebuildTracker,
        _navigationTracker = navigationTracker,
        _networkProfiler = networkProfiler,
        _asyncProfiler = asyncProfiler {
    _sessionId = 'session_${_sessionStart.millisecondsSinceEpoch}';
  }

  Future<Map<String, dynamic>> buildSnapshotMap() async {
    final grader = PerformanceGrader(
      frameProfiler: _frameProfiler,
      memoryProfiler: _memoryProfiler,
      rebuildTracker: _rebuildTracker,
      navigationTracker: _navigationTracker,
    );

    final now = DateTime.now();
    return {
      'sessionId': _sessionId,
      'startTime': _sessionStart.toIso8601String(),
      'endTime': now.toIso8601String(),
      'sessionDurationMs': now.difference(_sessionStart).inMilliseconds,
      'grade': grader.toJson(),
      'frame': _frameProfiler.toJson(),
      'memory': _memoryProfiler.toJson(),
      'rebuild': _rebuildTracker.toJson(),
      'navigation': _navigationTracker.toJson(),
      'imageCache': _imageCacheAnalyzer.toJson(),
      if (_networkProfiler != null) 'network': _networkProfiler!.toJson(),
      if (_asyncProfiler != null) 'async': _asyncProfiler!.toJson(),
      'optimizationSuggestions': _generateSuggestions(),
    };
  }

  Future<String> exportSnapshot({
    String? customPath,
    ReportFormat format = ReportFormat.text,
  }) async {
    String content;
    String extension;

    if (format == ReportFormat.text) {
      content = _buildTextReport();
      extension = 'txt';
    } else {
      final snapshot = await buildSnapshotMap();
      content = const JsonEncoder.withIndent('  ').convert(snapshot);
      extension = 'json';
    }

    if (kIsWeb) return content;

    return writeReportFile(content, customPath, extension: extension);
  }

  String _buildTextReport() {
    return TextFormatter(
      frameProfiler: _frameProfiler,
      memoryProfiler: _memoryProfiler,
      rebuildTracker: _rebuildTracker,
      navigationTracker: _navigationTracker,
      networkProfiler: _networkProfiler,
      asyncProfiler: _asyncProfiler,
      imageCacheAnalyzer: _imageCacheAnalyzer,
    ).format();
  }

  List<Map<String, dynamic>> _generateSuggestions() {
    final suggestions = <Map<String, dynamic>>[];
    final grader = PerformanceGrader(
      frameProfiler: _frameProfiler,
      memoryProfiler: _memoryProfiler,
      rebuildTracker: _rebuildTracker,
      navigationTracker: _navigationTracker,
    );

    if (grader.gradeFrames().score <= 3) {
      suggestions.add({
        'category': 'frame',
        'grade': grader.gradeFrames().label,
        'message': grader.frameSummary(),
      });
    }

    if (grader.gradeMemory().score <= 3) {
      suggestions.add({
        'category': 'memory',
        'grade': grader.gradeMemory().label,
        'message': grader.memorySummary(),
      });
    }

    for (final m in _rebuildTracker.excessiveRebuilds.take(5)) {
      suggestions.add({
        'category': 'rebuild',
        'grade': 'D',
        'widget': m.widgetType,
        'rebuildsPerSec': m.rebuildsPerSecond.toStringAsFixed(0),
        'file': m.location.fileInfo ?? 'run in debug mode',
        'location': m.location.ancestorPath ?? 'run in debug mode',
        'message':
        '${m.widgetType} rebuilding ${m.rebuildsPerSecond.toStringAsFixed(0)}x/sec'
            ' — add const or use RepaintBoundary',
      });
    }

    if (_networkProfiler != null) {
      for (final r in _networkProfiler!.slowRequests.take(3)) {
        suggestions.add({
          'category': 'network',
          'grade': 'D',
          'url': r.url,
          'durationMs': r.durationMs.toStringAsFixed(0),
          'message':
          '${r.method} ${r.url} took ${r.durationMs.toStringAsFixed(0)}ms — cache or paginate',
        });
      }
    }

    return suggestions;
  }
}