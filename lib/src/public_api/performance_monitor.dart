import 'dart:async';

import '../core/bus/diagnostics_event_bus.dart';
import '../core/events/jank_event.dart';
import '../core/events/memory_event.dart';
import '../core/events/performance_event.dart';

/// High-level orchestration facade that aggregates metrics from all profilers
/// and surfaces subscription points for consumers (overlays, dashboards, etc).
class PerformanceMonitor {
  final DiagnosticsEventBus _bus;

  final List<StreamSubscription> _subs = [];
  final _alertHandlers = <void Function(PerformanceEvent)>[];
  final _jankHandlers = <void Function(JankEvent)>[];

  PerformanceMonitor({
    required DiagnosticsEventBus bus,
  })  :_bus = bus {
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    // Forward critical events to registered handlers
    _subs.add(_bus.criticalEvents.listen((event) {
      for (final h in _alertHandlers) {
        h(event);
      }
    }));

    _subs.add(_bus.jankEvents.listen((event) {
      for (final h in _jankHandlers) {
        h(event);
      }
    }));
  }

  // ─── Registration ──────────────────────────────────────────────────────

  /// Registers a callback invoked on any warning/critical event.
  void onAlert(void Function(PerformanceEvent event) handler) {
    _alertHandlers.add(handler);
  }

  /// Registers a callback invoked specifically on jank events.
  void onJank(void Function(JankEvent event) handler) {
    _jankHandlers.add(handler);
  }

  // ─── Typed stream accessors ────────────────────────────────────────────

  Stream<PerformanceEvent> get allEvents => _bus.allEvents;
  Stream<JankEvent> get jankStream => _bus.jankEvents;
  Stream<MemoryEvent> get memoryStream => _bus.memoryEvents;

  // ─── Dispose ──────────────────────────────────────────────────────────

  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _alertHandlers.clear();
    _jankHandlers.clear();
  }
}
