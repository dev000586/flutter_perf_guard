import 'package:equatable/equatable.dart';
import 'rebuild_location.dart';

/// Metrics tracking rebuild frequency and cost for a specific widget.
class RebuildMetrics extends Equatable {
  /// The widget's runtime type name.
  final String widgetType;

  /// Key string if the widget has a [Key].
  final String? widgetKey;

  /// Number of rebuilds observed in the current sampling window.
  final int rebuildCount;

  /// Total time spent in [Element.rebuild] for this widget.
  final Duration totalRebuildTime;

  /// Average rebuild duration.
  final Duration averageRebuildTime;

  /// Depth in the widget tree.
  final int treeDepth;

  /// Whether this widget has a [RepaintBoundary] ancestor.
  final bool hasRepaintBoundary;

  /// Whether rebuilds were triggered by setState (vs inherited widget).
  final bool triggeredBySetState;

  /// Timestamp of first rebuild in this window.
  final DateTime firstSeen;

  /// Timestamp of most recent rebuild.
  final DateTime lastSeen;

  /// Debug-mode location info (file, line, ancestor path).
  final RebuildLocation location;

  const RebuildMetrics(
      {required this.widgetType,
      required this.rebuildCount,
      required this.totalRebuildTime,
      required this.averageRebuildTime,
      required this.treeDepth,
      required this.hasRepaintBoundary,
      required this.triggeredBySetState,
      required this.firstSeen,
      required this.lastSeen,
      this.widgetKey,
      this.location = const RebuildLocation()});

  /// Rebuilds per second during the sampling window.
  double get rebuildsPerSecond {
    final windowMs = lastSeen.difference(firstSeen).inMilliseconds;
    if (windowMs <= 0) return 0.0;
    return rebuildCount / (windowMs / 1000.0);
  }

  /// Whether this widget's rebuild rate is considered excessive (> 60/s).
  bool get isExcessive => rebuildsPerSecond > 60;

  Map<String, dynamic> toJson() => {
        'widgetType': widgetType,
        if (widgetKey != null) 'widgetKey': widgetKey,
        'rebuildCount': rebuildCount,
        'totalRebuildTimeMs': totalRebuildTime.inMicroseconds / 1000,
        'averageRebuildTimeMs': averageRebuildTime.inMicroseconds / 1000,
        'treeDepth': treeDepth,
        'hasRepaintBoundary': hasRepaintBoundary,
        'triggeredBySetState': triggeredBySetState,
        'rebuildsPerSecond': rebuildsPerSecond,
        'isExcessive': isExcessive,
        'location': location.toJson(),
        'firstSeen': firstSeen.toIso8601String(),
        'lastSeen': lastSeen.toIso8601String(),
      };

  RebuildMetrics increment({
    required Duration rebuildTime,
    required DateTime at,
  }) {
    final newTotal = totalRebuildTime + rebuildTime;
    final newCount = rebuildCount + 1;
    return RebuildMetrics(
      widgetType: widgetType,
      widgetKey: widgetKey,
      rebuildCount: newCount,
      totalRebuildTime: newTotal,
      averageRebuildTime: newCount > 0
          ? Duration(microseconds: newTotal.inMicroseconds ~/ newCount)
          : Duration.zero,
      treeDepth: treeDepth,
      hasRepaintBoundary: hasRepaintBoundary,
      triggeredBySetState: triggeredBySetState,
      firstSeen: firstSeen,
      lastSeen: at,
      location: location,
    );
  }

  @override
  List<Object?> get props => [
        widgetType,
        widgetKey,
        rebuildCount,
        totalRebuildTime,
        treeDepth,
        triggeredBySetState,
      ];
}
