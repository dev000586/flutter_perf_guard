import 'dart:collection';
import 'package:flutter/widgets.dart';
import '../../core/bus/diagnostics_event_bus.dart';

/// Tracks navigation transition durations and emits events for slow routes.
class NavigationTracker extends NavigatorObserver {

  final Queue<NavigationRecord> _history = Queue();
  DateTime? _transitionStart;
  String? _fromRoute;
  String? _toRoute;

  NavigationTracker({required DiagnosticsEventBus bus});

  @override
  void didPush(Route route, Route? previousRoute) {
    _transitionStart = DateTime.now();
    _fromRoute = previousRoute?.settings.name ?? '/';
    _toRoute = route.settings.name ?? route.runtimeType.toString();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _recordTransition('pop');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _transitionStart = DateTime.now();
    _fromRoute = oldRoute?.settings.name;
    _toRoute = newRoute?.settings.name;
    _recordTransition('replace');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _recordTransition(String type) {
    if (_transitionStart == null) return;
    final duration = DateTime.now().difference(_transitionStart!);
    final record = NavigationRecord(
      type: type,
      fromRoute: _fromRoute,
      toRoute: _toRoute,
      duration: duration,
      timestamp: DateTime.now(),
    );
    _history.addLast(record);
    if (_history.length > 100) _history.removeFirst();
    _transitionStart = null;
  }

  List<NavigationRecord> get history => _history.toList();

  Map<String, dynamic> toJson() => {
        'transitionCount': _history.length,
        'history': _history.map((r) => r.toJson()).toList(),
      };
}

class NavigationRecord {
  final String type;
  final String? fromRoute;
  final String? toRoute;
  final Duration duration;
  final DateTime timestamp;

  const NavigationRecord({
    required this.type,
    required this.duration, required this.timestamp, this.fromRoute,
    this.toRoute,
  });

  bool get isSlow => duration > const Duration(milliseconds: 300);

  Map<String, dynamic> toJson() => {
        'type': type,
        'fromRoute': fromRoute,
        'toRoute': toRoute,
        'durationMs': duration.inMicroseconds / 1000,
        'isSlow': isSlow,
        'timestamp': timestamp.toIso8601String(),
      };
}
