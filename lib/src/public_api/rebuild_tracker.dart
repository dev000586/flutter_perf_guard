import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/bus/diagnostics_event_bus.dart';
import '../core/events/rebuild_event.dart';
import '../profiling/rebuild/rebuild_location.dart';
import '../profiling/rebuild/rebuild_metrics.dart';
import 'perf_guard_config.dart';

/// Intercepts [Element.rebuild] via [debugOnRebuildDirtyWidget] to track
/// widget rebuild frequency, duration, and detect excessive rebuilds.
///
/// Only active in debug mode or when explicitly enabled.
class RebuildTracker {
  final PerfGuardConfig _config;
  final DiagnosticsEventBus _bus;

  bool _installed = false;
  final Map<String, RebuildMetrics> _metricsMap = HashMap();
  int _rebuildIndex = 0;

  // Saved original callback so we can restore it on uninstall
  RebuildedCallback? _previousCallback;

  RebuildTracker({
    required PerfGuardConfig config,
    required DiagnosticsEventBus bus,
  })  : _config = config,
        _bus = bus;

  // ─── Install / uninstall ───────────────────────────────────────────────

  void install() {
    if (_installed) return;
    if (!kDebugMode) {
      debugPrint('[RebuildTracker] Only active in debug mode.');
      return;
    }
    _previousCallback = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = _onRebuild;
    _installed = true;
  }

  void uninstall() {
    if (!_installed) return;
    debugOnRebuildDirtyWidget = _previousCallback;
    _installed = false;
  }

  // ─── Rebuild hook ──────────────────────────────────────────────────────

  void _onRebuild(Element element, bool builtOnce) {
    // Call original if set
    _previousCallback?.call(element, builtOnce);

    final widgetType = element.widget.runtimeType.toString();
    final widgetKey = element.widget.key?.toString();
    final now = DateTime.now();

    // Measure rebuild duration via microtask timing
    final sw = Stopwatch()..start();

    // Schedule post-frame to capture duration after rebuild completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sw.stop();
      final rebuildTime = sw.elapsed;
      _processRebuild(
        widgetType: widgetType,
        widgetKey: widgetKey,
        rebuildTime: rebuildTime,
        at: now,
        element: element,
      );
    });
  }

  void _processRebuild({
    required String widgetType,
    required String? widgetKey,
    required Duration rebuildTime,
    required DateTime at,
    required Element element,
  }) {
    _rebuildIndex++;
    final key = widgetKey != null ? '$widgetType[$widgetKey]' : widgetType;

    final existing = _metricsMap[key];
    final metrics = existing != null
        ? existing.increment(rebuildTime: rebuildTime, at: at)
        : RebuildMetrics(
            widgetType: widgetType,
            widgetKey: widgetKey,
            rebuildCount: 1,
            totalRebuildTime: rebuildTime,
            averageRebuildTime: rebuildTime,
            treeDepth: _getDepth(element),
            hasRepaintBoundary: _hasRepaintBoundary(element),
            triggeredBySetState: true,
            firstSeen: at,
            lastSeen: at,
            location: RebuildLocation.capture(element)    //File name may not be available by latest flutter sdk.
          );

    _metricsMap[key] = metrics;

    // Trim history per widget
    if (_metricsMap.length > _config.rebuildHistorySize * 10) {
      _pruneOldEntries();
    }

    // Emit event
    final isUnnecessary = _isUnnecessaryRebuild(metrics);
    final event = RebuildEvent.fromWidget(
      id: 'rebuild_$_rebuildIndex',
      metrics: metrics,
      isUnnecessary: isUnnecessary,
    );
    _bus.emit(event);
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  int _getDepth(Element element) {
    var depth = 0;

    element.visitAncestorElements((ancestor) {
      depth++;
      return true;
    });

    return depth;
  }

  bool _hasRepaintBoundary(Element element) {
    bool found = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is RepaintBoundary) {
        found = true;
        return false; // stop visiting
      }
      return true;
    });
    return found;
  }

  bool _isUnnecessaryRebuild(RebuildMetrics metrics) {
    // Heuristic: very fast rebuild with high count is likely unnecessary
    return metrics.averageRebuildTime < const Duration(microseconds: 100) &&
        metrics.rebuildCount > 10;
  }

  void _pruneOldEntries() {
    final entries = _metricsMap.entries.toList()
      ..sort((a, b) => a.value.lastSeen.compareTo(b.value.lastSeen));
    final toRemove = entries.take(entries.length ~/ 4);
    for (final e in toRemove) {
      _metricsMap.remove(e.key);
    }
  }

  // ─── Accessors ──────────────────────────────────────────────────────────

  bool get isInstalled => _installed;

  List<RebuildMetrics> get allMetrics => _metricsMap.values.toList();

  List<RebuildMetrics> get hotWidgets {
    final list = allMetrics
      ..sort((a, b) => b.rebuildCount.compareTo(a.rebuildCount));
    return list.take(20).toList();
  }

  List<RebuildMetrics> get excessiveRebuilds =>
      allMetrics.where((m) => m.isExcessive).toList();

  Map<String, dynamic> toJson() => {
        'trackedWidgets': _metricsMap.length,
        'totalRebuildEvents': _rebuildIndex,
        'excessiveRebuildCount': excessiveRebuilds.length,
        'hotWidgets':
            hotWidgets.take(10).map((m) => m.toJson()).toList(),
      };

  void reset() {
    _metricsMap.clear();
    _rebuildIndex = 0;
  }
}

// Type alias matching Flutter's internal callback signature
typedef RebuildedCallback = void Function(Element element, bool builtOnce);
