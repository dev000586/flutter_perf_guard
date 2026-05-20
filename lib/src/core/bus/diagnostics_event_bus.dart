import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../events/frame_event.dart';
import '../events/jank_event.dart';
import '../events/memory_event.dart';
import '../events/performance_event.dart';
import '../events/rebuild_event.dart';

/// Central event bus for all performance diagnostics events.
///
/// Uses a [PublishSubject] internally so multiple independent subscribers
/// can each receive every event. Thread-safe via zone-based stream isolation.
///
/// Usage:
/// ```dart
/// final bus = DiagnosticsEventBus.instance;
/// bus.frameEvents.listen((e) => print('Frame: ${e.metrics.totalDuration}'));
/// bus.emit(frameEvent);
/// ```
class DiagnosticsEventBus {
  DiagnosticsEventBus._();

  static final DiagnosticsEventBus _instance = DiagnosticsEventBus._();

  /// Singleton accessor.
  static DiagnosticsEventBus get instance => _instance;

  // ─── Internal subjects ──────────────────────────────────────────────────

  final PublishSubject<PerformanceEvent> _allEvents =
      PublishSubject<PerformanceEvent>();

  // ─── Typed streams ──────────────────────────────────────────────────────

  /// Stream of every [PerformanceEvent] regardless of type.
  Stream<PerformanceEvent> get allEvents => _allEvents.stream;

  /// Stream of [FrameEvent]s only.
  Stream<FrameEvent> get frameEvents =>
      _allEvents.stream.whereType<FrameEvent>();

  /// Stream of [MemoryEvent]s only.
  Stream<MemoryEvent> get memoryEvents =>
      _allEvents.stream.whereType<MemoryEvent>();

  /// Stream of [RebuildEvent]s only.
  Stream<RebuildEvent> get rebuildEvents =>
      _allEvents.stream.whereType<RebuildEvent>();

  /// Stream of [JankEvent]s only.
  Stream<JankEvent> get jankEvents =>
      _allEvents.stream.whereType<JankEvent>();

  /// Stream of warning-or-above events only.
  Stream<PerformanceEvent> get criticalEvents => _allEvents.stream.where(
        (e) => e.severity == EventSeverity.warning ||
            e.severity == EventSeverity.critical,
      );

  // ─── Emission ───────────────────────────────────────────────────────────

  /// Emits a [PerformanceEvent] to all subscribers.
  void emit(PerformanceEvent event) {
    if (!_allEvents.isClosed) {
      _allEvents.add(event);
    }
  }

  /// Emits multiple events at once.
  void emitAll(Iterable<PerformanceEvent> events) {
    for (final event in events) {
      emit(event);
    }
  }

  // ─── Filtering helpers ──────────────────────────────────────────────────

  /// Returns a stream filtered by [source] identifier.
  Stream<PerformanceEvent> fromSource(String source) =>
      allEvents.where((e) => e.source == source);

  /// Returns a typed stream of events from a specific source.
  Stream<T> fromSourceTyped<T extends PerformanceEvent>(String source) =>
      allEvents.whereType<T>().where((e) => e.source == source);

  // ─── Buffer / replay ────────────────────────────────────────────────────

  /// Creates a buffered stream of the last [count] events of type [T].
  Stream<List<T>> bufferedWindow<T extends PerformanceEvent>(int count) =>
      _allEvents.stream
          .whereType<T>()
          .bufferCount(count, 1)
          .map((list) => list.toList());

  // ─── Lifecycle ──────────────────────────────────────────────────────────

  /// Disposes the event bus and closes all streams.
  void dispose() {
    _allEvents.close();
  }
}
