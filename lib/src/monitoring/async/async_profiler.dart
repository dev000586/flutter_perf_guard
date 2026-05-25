import 'dart:async';
import '../../core/bus/diagnostics_event_bus.dart';

/// Zone-based async operation profiler.
///
/// Wrap any async operation with [AsyncProfiler.track] to measure its
/// duration and record it. Automatically detects operations exceeding
/// the slow threshold and flags them in the report.
class AsyncProfiler {
  final List<AsyncOperationRecord> _records = [];

  /// Operations longer than this are flagged as slow.
  final Duration slowThreshold;

  AsyncProfiler({
    required DiagnosticsEventBus bus,
    this.slowThreshold = const Duration(milliseconds: 500),
  });

  /// Tracks a named async operation.
  ///
  /// ```dart
  /// final result = await asyncProfiler.track(
  ///   'fetch_products',
  ///   () => api.getProducts(),
  /// );
  /// ```
  Future<T> track<T>(String name, Future<T> Function() operation) async {
    final sw = Stopwatch()..start();
    final timestamp = DateTime.now();
    String? error;

    try {
      final result = await operation();
      sw.stop();
      return result;
    } catch (e) {
      sw.stop();
      error = e.toString();
      rethrow;
    } finally {
      _record(AsyncOperationRecord(
        name: name,
        duration: sw.elapsed,
        timestamp: timestamp,
        error: error,
      ));
    }
  }

  /// Tracks a synchronous operation that may be expensive.
  T trackSync<T>(String name, T Function() operation) {
    final sw = Stopwatch()..start();
    final timestamp = DateTime.now();
    String? error;

    try {
      final result = operation();
      sw.stop();
      return result;
    } catch (e) {
      sw.stop();
      error = e.toString();
      rethrow;
    } finally {
      _record(AsyncOperationRecord(
        name: name,
        duration: sw.elapsed,
        timestamp: timestamp,
        error: error,
      ));
    }
  }

  void _record(AsyncOperationRecord record) {
    _records.add(record);
    if (_records.length > 500) _records.removeAt(0);
  }

  List<AsyncOperationRecord> get records => List.unmodifiable(_records);

  List<AsyncOperationRecord> get slowOperations =>
      _records.where((r) => r.duration > slowThreshold).toList();

  List<AsyncOperationRecord> get failedOperations =>
      _records.where((r) => r.error != null).toList();

  String get plainEnglishSummary {
    if (_records.isEmpty) return '✅ No async operations recorded';

    final slow = slowOperations;
    final failed = failedOperations;
    final buffer = StringBuffer();

    if (failed.isNotEmpty) {
      buffer.writeln('❌ ${failed.length} failed operation(s)');
      for (final r in failed.take(3)) {
        buffer.writeln('   ${r.name}: ${r.error}');
      }
    }

    if (slow.isNotEmpty) {
      buffer.writeln(
          '⚠ ${slow.length} slow operation(s) (> ${slowThreshold.inMilliseconds}ms)');
      for (final r in slow.take(3)) {
        buffer.writeln(
            '   ${r.name}: ${r.duration.inMilliseconds}ms');
        buffer.writeln('   Fix: Show loading indicator or cache the result');
      }
    }

    if (failed.isEmpty && slow.isEmpty) {
      buffer.write('✅ All ${_records.length} operations completed normally');
    }

    return buffer.toString().trimRight();
  }

  Map<String, dynamic> toJson() {
    if (_records.isEmpty) return {'totalOperations': 0};

    final durations = _records.map((r) => r.duration.inMilliseconds).toList();
    final avg = durations.reduce((a, b) => a + b) / durations.length;

    return {
      'totalOperations': _records.length,
      'slowOperations': slowOperations.length,
      'failedOperations': failedOperations.length,
      'averageDurationMs': avg.toStringAsFixed(1),
      'operations': _records.map((r) => r.toJson()).toList(),
    };
  }

  void reset() => _records.clear();
}

class AsyncOperationRecord {
  final String name;
  final Duration duration;
  final DateTime timestamp;
  final String? error;

  const AsyncOperationRecord({
    required this.name,
    required this.duration,
    required this.timestamp,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'durationMs': duration.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
    if (error != null) 'error': error,
  };
}