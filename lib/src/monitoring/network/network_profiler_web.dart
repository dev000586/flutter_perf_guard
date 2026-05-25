import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../../core/bus/diagnostics_event_bus.dart';

class NetworkProfiler {
  final List<NetworkRequestRecord> _records = [];

  static NetworkProfiler? _instance;

  Timer? _pollTimer;

  NetworkProfiler({
    required DiagnosticsEventBus bus,
  });

  static void install({
    required NetworkProfiler profiler,
  }) {
    if (_instance != null) return;

    _instance = profiler;

    profiler._startMonitoring();
  }

  static void uninstall() {
    _instance?._pollTimer?.cancel();
    _instance = null;
  }

  void _startMonitoring() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 300),
          (_) => _collectEntries(),
    );
  }

  void _collectEntries() {
    final entries =
    web.window.performance.getEntriesByType('resource');

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];

      if (entry is! web.PerformanceResourceTiming) {
        continue;
      }

      final url = entry.name;

      // Skip Flutter/dev assets only
      if (url.contains('flutter.js')) continue;
      if (url.contains('main.dart.js')) continue;
      if (url.contains('canvaskit')) continue;
      if (url.contains('favicon')) continue;
      if (url.contains('localhost')) continue;
      if (url.contains('flutter_service_worker')) continue;
      if (url.contains('.js')) continue;
      if (url.contains('.dart')) continue;
      if (url.contains('.png')) continue;
      if (url.contains('.jpg')) continue;
      if (url.contains('.svg')) continue;

      // Avoid duplicates
      final alreadyExists = _records.any(
            (r) =>
        r.url == url &&
            (r.durationMs - entry.duration).abs() < 1,
      );

      if (alreadyExists) continue;

      final record = NetworkRequestRecord(
        url: url,
        method: 'GET',
        statusCode: 200,
        durationMs: entry.duration,
        responseSizeBytes: entry.transferSize.toInt(),
        timestamp: DateTime.now(),
      );

      _records.add(record);

      debugPrint(
        '[PerfGuard][WEB] ${record.method} ${record.url} '
            '${record.durationMs.toStringAsFixed(1)}ms',
      );
    }
  }

  void _record(NetworkRequestRecord record) {
    _records.add(record);

    if (_records.length > 200) {
      _records.removeAt(0);
    }
  }

  List<NetworkRequestRecord> get records =>
      List.unmodifiable(_records);

  List<NetworkRequestRecord> get slowRequests =>
      _records.where((r) => r.isSlow).toList();

  List<NetworkRequestRecord> get failedRequests =>
      _records.where((r) => r.hasFailed).toList();

  Map<String, dynamic> toJson() {
    if (_records.isEmpty) {
      return {
        'totalRequests': 0,
        'note': 'No requests recorded',
      };
    }

    final durations =
    _records.map((r) => r.durationMs).toList();

    final avgMs = durations.isEmpty
        ? 0.0
        : durations.reduce((a, b) => a + b) /
        durations.length;

    return {
      'totalRequests': _records.length,
      'slowRequests': slowRequests.length,
      'failedRequests': failedRequests.length,
      'averageDurationMs': avgMs.toStringAsFixed(1),
      'requests': _records.map((r) => r.toJson()).toList(),
    };
  }

  String get plainEnglishSummary {
    if (_records.isEmpty) {
      return '✅ No network requests recorded';
    }

    final slow = slowRequests;
    final failed = failedRequests;

    final buffer = StringBuffer();

    if (failed.isNotEmpty) {
      buffer.writeln(
        '❌ ${failed.length} failed request(s)',
      );
    }

    if (slow.isNotEmpty) {
      buffer.writeln(
        '⚠ ${slow.length} slow request(s) (>1s)',
      );
    }

    if (failed.isEmpty && slow.isEmpty) {
      buffer.write(
        '✅ All ${_records.length} requests completed normally',
      );
    }

    return buffer.toString().trimRight();
  }

  @visibleForTesting
  void addRecord(NetworkRequestRecord record) {
    _record(record);
  }
}

class NetworkRequestRecord {
  final String url;
  final String method;
  final int? statusCode;
  final double durationMs;
  final int? responseSizeBytes;
  final DateTime timestamp;
  final String? error;

  const NetworkRequestRecord({
    required this.url,
    required this.method,
    required this.durationMs,
    required this.timestamp,
    this.statusCode,
    this.responseSizeBytes,
    this.error,
  });

  bool get isSlow => durationMs > 1000;

  bool get hasFailed =>
      error != null ||
          (statusCode != null && statusCode! >= 400);

  Map<String, dynamic> toJson() => {
    'url': url,
    'method': method,
    if (statusCode != null)
      'statusCode': statusCode,
    'durationMs': durationMs.toStringAsFixed(1),
    if (responseSizeBytes != null)
      'responseSizeKb':
      (responseSizeBytes! / 1024)
          .toStringAsFixed(1),
    'timestamp': timestamp.toIso8601String(),
    'isSlow': isSlow,
    'hasFailed': hasFailed,
    if (error != null)
      'error': error,
  };
}