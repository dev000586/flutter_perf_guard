import 'dart:async';
import 'dart:convert';
import '../core/bus/diagnostics_event_bus.dart';
import '../core/events/performance_event.dart';

/// Captures a rolling or bounded timeline of performance events for
/// offline analysis, export, and frame-by-frame playback.
class TimelineRecorder {
  final DiagnosticsEventBus _bus;

  StreamSubscription<PerformanceEvent>? _sub;
  final List<Map<String, dynamic>> _entries = [];
  bool _recording = false;
  DateTime? _startTime;
  int _maxEntries;

  TimelineRecorder({
    required DiagnosticsEventBus bus,
    int maxEntries = 10000,
  })  : _bus = bus,
        _maxEntries = maxEntries;

  bool get isRecording => _recording;
  int get entryCount => _entries.length;
  DateTime? get startTime => _startTime;

  // ─── Control ──────────────────────────────────────────────────────────

  void start({int? maxEntries}) {
    if (_recording) return;
    if (maxEntries != null) _maxEntries = maxEntries;
    _entries.clear();
    _startTime = DateTime.now();
    _recording = true;
    _sub = _bus.allEvents.listen(_record);
  }

  void stop() {
    _recording = false;
    _sub?.cancel();
    _sub = null;
  }

  void clear() {
    _entries.clear();
    _startTime = null;
  }

  // ─── Recording ────────────────────────────────────────────────────────

  void _record(PerformanceEvent event) {
    if (_entries.length >= _maxEntries) {
      _entries.removeAt(0);
    }
    double offsetMs = 0.0;
    try {
      offsetMs = _startTime != null
          ? event.timestamp.difference(_startTime!).inMicroseconds / 1000.0
          : 0.0;
    } catch (_) {
      offsetMs = 0.0;
    }
    _entries.add({
      'offsetMs': offsetMs,
      ...event.toJson(),
    });
  }

  // ─── Export ───────────────────────────────────────────────────────────

  /// Returns the timeline as a JSON string suitable for DevTools or export.
  String exportJson({bool pretty = false}) {
    final data = {
      'startTime': _startTime?.toIso8601String(),
      'durationMs': _startTime != null
          ? DateTime.now().difference(_startTime!).inMilliseconds
          : 0,
      'entryCount': _entries.length,
      'entries': _entries,
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(data)
        : jsonEncode(data);
  }

  /// Snapshot of the current timeline entries.
  List<Map<String, dynamic>> get entries => List.unmodifiable(_entries);

  /// Filters entries by event type string.
  List<Map<String, dynamic>> entriesByType(String type) =>
      _entries.where((e) => e['type'] == type || e['source'] == type).toList();

  Map<String, dynamic> toJson() => {
        'recording': _recording,
        'entryCount': _entries.length,
        'startTime': _startTime?.toIso8601String(),
        'maxEntries': _maxEntries,
      };
}
