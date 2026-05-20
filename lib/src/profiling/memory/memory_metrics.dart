import 'package:equatable/equatable.dart';

/// Point-in-time memory snapshot.
///
/// All byte values are raw integers. Use the convenience getters
/// ([heapUsedMb], [rssMb], etc.) for human-readable output.
class MemoryMetrics extends Equatable {
  /// Current heap usage in bytes (estimated from RSS on native; 0 on web).
  final int heapUsedBytes;

  /// Maximum heap capacity in bytes (estimated from RSS on native; 0 on web).
  final int heapCapacityBytes;

  /// External / native memory in bytes (estimated from RSS on native; 0 on web).
  final int externalBytes;

  /// Resident Set Size from [ProcessInfo.currentRss] (native) or 0 (web).
  final int rssBytes;

  /// Number of GC events observed since the profiler started.
  final int gcCount;

  /// Timestamp of this snapshot.
  final DateTime timestamp;

  const MemoryMetrics({
    required this.heapUsedBytes,
    required this.heapCapacityBytes,
    required this.externalBytes,
    required this.rssBytes,
    required this.gcCount,
    required this.timestamp,
  });

  // ─── Computed ────────────────────────────────────────────────────────────

  /// Fraction of heap used (0.0–1.0).
  double get heapUsagePercent =>
      heapCapacityBytes > 0 ? heapUsedBytes / heapCapacityBytes : 0.0;

  /// Heap used in megabytes.
  double get heapUsedMb => heapUsedBytes / (1024 * 1024);

  /// Heap capacity in megabytes.
  double get heapCapacityMb => heapCapacityBytes / (1024 * 1024);

  /// External memory in megabytes.
  double get externalMb => externalBytes / (1024 * 1024);

  /// RSS in megabytes.
  double get rssMb => rssBytes / (1024 * 1024);

  // ─── Serialization ───────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'heapUsedBytes': heapUsedBytes,
        'heapCapacityBytes': heapCapacityBytes,
        'externalBytes': externalBytes,
        'rssBytes': rssBytes,
        'gcCount': gcCount,
        'timestamp': timestamp.toIso8601String(),
        'heapUsagePercent': heapUsagePercent,
        'heapUsedMb': heapUsedMb,
        'rssMb': rssMb,
      };

  // ─── Mutation ────────────────────────────────────────────────────────────

  MemoryMetrics copyWith({
    int? heapUsedBytes,
    int? heapCapacityBytes,
    int? externalBytes,
    int? rssBytes,
    int? gcCount,
    DateTime? timestamp,
  }) =>
      MemoryMetrics(
        heapUsedBytes: heapUsedBytes ?? this.heapUsedBytes,
        heapCapacityBytes: heapCapacityBytes ?? this.heapCapacityBytes,
        externalBytes: externalBytes ?? this.externalBytes,
        rssBytes: rssBytes ?? this.rssBytes,
        gcCount: gcCount ?? this.gcCount,
        timestamp: timestamp ?? this.timestamp,
      );

  // ─── Equatable ───────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        heapUsedBytes,
        heapCapacityBytes,
        externalBytes,
        rssBytes,
        gcCount,
        timestamp,
      ];

  @override
  String toString() =>
      'MemoryMetrics(heap=${heapUsedMb.toStringAsFixed(1)}MB/'
      '${heapCapacityMb.toStringAsFixed(1)}MB, '
      'ext=${externalMb.toStringAsFixed(1)}MB, '
      'rss=${rssMb.toStringAsFixed(1)}MB)';
}
