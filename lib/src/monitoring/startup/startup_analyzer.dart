import '../../core/bus/diagnostics_event_bus.dart';

/// Records startup milestones and computes time-to-interactive.
class StartupAnalyzer {

  DateTime? _appStartTime;
  final Map<String, Duration> _milestones = {};
  bool _firstFrameRecorded = false;

  StartupAnalyzer({required DiagnosticsEventBus bus});

  void markAppStart() {
    _appStartTime = DateTime.now();
    _milestone('app_start');
  }

  void markFirstFrame() {
    if (_firstFrameRecorded) return;
    _firstFrameRecorded = true;
    _milestone('first_frame');
  }

  void markNavigatorReady() => _milestone('navigator_ready');
  void markDataLoaded() => _milestone('data_loaded');
  void markInteractive() => _milestone('interactive');

  void _milestone(String name) {
    if (_appStartTime == null) return;
    _milestones[name] = DateTime.now().difference(_appStartTime!);
  }

  Duration? get timeToFirstFrame => _milestones['first_frame'];
  Duration? get timeToInteractive => _milestones['interactive'];

  Map<String, dynamic> toJson() => {
        'appStartTime': _appStartTime?.toIso8601String(),
        'milestones': _milestones
            .map((k, v) => MapEntry(k, v.inMicroseconds / 1000)),
      };
}
