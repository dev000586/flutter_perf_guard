import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/bus/diagnostics_event_bus.dart';
import '../core/events/frame_event.dart';
import '../core/events/jank_event.dart';
import '../core/events/memory_event.dart';

/// Lightweight HUD overlay that shows real-time FPS, frame times, and
/// memory usage. Renders via a [CustomPainter] to avoid widget rebuilds
/// on every frame.
///
/// Wrap your app or a subtree:
/// ```dart
/// PerfGuardOverlay(
///   child: MyApp(),
/// )
/// ```
class PerfGuardOverlay extends StatefulWidget {
  final Widget child;
  final OverlayAlignment alignment;
  final bool showFps;
  final bool showMemory;
  final bool showJankAlert;
  final double opacity;

  const PerfGuardOverlay({
    required this.child, super.key,
    this.alignment = OverlayAlignment.topRight,
    this.showFps = true,
    this.showMemory = true,
    this.showJankAlert = true,
    this.opacity = 0.85,
  });

  @override
  State<PerfGuardOverlay> createState() => _PerfGuardOverlayState();
}

class _PerfGuardOverlayState extends State<PerfGuardOverlay> {
  final List<StreamSubscription> _subs = [];
  final _bus = DiagnosticsEventBus.instance;

  double _fps = 0.0;
  double _buildMs = 0.0;
  double _rasterMs = 0.0;
  double _heapMb = 0.0;
  double _rssMb = 0.0;
  bool _jankAlert = false;
  Timer? _jankAlertTimer;

  // FPS sliding window
  final List<double> _fpsWindow = [];
  static const _windowSize = 30;

  @override
  void initState() {
    super.initState();
    _subs.add(_bus.frameEvents.listen(_onFrame));
    _subs.add(_bus.memoryEvents.listen(_onMemory));
    _subs.add(_bus.jankEvents.listen(_onJank));
  }

  void _onFrame(FrameEvent event) {
    final m = event.metrics;
    _fpsWindow.add(m.fps);
    if (_fpsWindow.length > _windowSize) _fpsWindow.removeAt(0);
    final avgFps =
        _fpsWindow.fold(0.0, (s, f) => s + f) / _fpsWindow.length;

    if (mounted) {
      setState(() {
        _fps = avgFps;
        _buildMs = m.buildDuration.inMicroseconds / 1000.0;
        _rasterMs = m.rasterDuration.inMicroseconds / 1000.0;
      });
    }
  }

  void _onMemory(MemoryEvent event) {
    if (mounted) {
      setState(() {
        _heapMb = event.metrics.heapUsedMb;
        _rssMb = event.metrics.rssMb;
      });
    }
  }

  void _onJank(JankEvent event) {
    if (mounted) {
      setState(() => _jankAlert = true);
      _jankAlertTimer?.cancel();
      _jankAlertTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _jankAlert = false);
      });
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _jankAlertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug/profile mode unless explicitly enabled
    const shouldShow =
        kDebugMode || kProfileMode;

    if (!shouldShow) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: _isTop ? 8.0 : null,
          bottom: _isTop ? null : 8.0,
          left: _isLeft ? 8.0 : null,
          right: _isLeft ? null : 8.0,
          child: IgnorePointer(
            child: Opacity(
              opacity: widget.opacity,
              child: _OverlayPanel(
                fps: _fps,
                buildMs: _buildMs,
                rasterMs: _rasterMs,
                heapMb: _heapMb,
                rssMb: _rssMb,
                jankAlert: _jankAlert,
                showFps: widget.showFps,
                showMemory: widget.showMemory,
                showJankAlert: widget.showJankAlert,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _isTop =>
      widget.alignment == OverlayAlignment.topLeft ||
      widget.alignment == OverlayAlignment.topRight;

  bool get _isLeft =>
      widget.alignment == OverlayAlignment.topLeft ||
      widget.alignment == OverlayAlignment.bottomLeft;
}

class _OverlayPanel extends StatelessWidget {
  final double fps;
  final double buildMs;
  final double rasterMs;
  final double heapMb;
  final double rssMb;
  final bool jankAlert;
  final bool showFps;
  final bool showMemory;
  final bool showJankAlert;

  const _OverlayPanel({
    required this.fps,
    required this.buildMs,
    required this.rasterMs,
    required this.heapMb,
    required this.rssMb,
    required this.jankAlert,
    required this.showFps,
    required this.showMemory,
    required this.showJankAlert,
  });

  @override
  Widget build(BuildContext context) {
    final fpsColor = fps >= 55
        ? const Color(0xFF4CAF50)
        : fps >= 30
            ? const Color(0xFFFF9800)
            : const Color(0xFFF44336);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: jankAlert && showJankAlert
              ? const Color(0xFFF44336)
              : const Color(0x33FFFFFF),
          width: jankAlert && showJankAlert ? 1.5 : 0.5,
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.0,
          color: Colors.white,
          decoration: TextDecoration.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const Text(
              '⚡ PerfGuard',
              style: TextStyle(
                color: Color(0xFF64B5F6),
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
            const SizedBox(height: 4),
            if (showFps) ...[
              _MetricRow(
                label: 'FPS',
                value: fps.toStringAsFixed(1),
                valueColor: fpsColor,
              ),
              _MetricRow(
                label: 'Build',
                value: '${buildMs.toStringAsFixed(2)}ms',
                valueColor: buildMs > 8 ? const Color(0xFFFF9800) : Colors.white,
              ),
              _MetricRow(
                label: 'Raster',
                value: '${rasterMs.toStringAsFixed(2)}ms',
                valueColor:
                    rasterMs > 8 ? const Color(0xFFFF9800) : Colors.white,
              ),
            ],
            if (showMemory && heapMb > 0) ...[
              const SizedBox(height: 2),
              _MetricRow(
                label: 'Heap',
                value: '${heapMb.toStringAsFixed(1)}MB',
                valueColor: heapMb > 512
                    ? const Color(0xFFF44336)
                    : Colors.white,
              ),
              _MetricRow(
                label: 'RSS',
                value: '${rssMb.toStringAsFixed(1)}MB',
              ),
            ],
            if (showJankAlert && jankAlert) ...[
              const SizedBox(height: 4),
              const Text(
                '⚠ JANK',
                style: TextStyle(
                  color: Color(0xFFF44336),
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 9),
          ),
        ),
        Text(value, style: TextStyle(color: valueColor, fontSize: 10)),
      ],
    );
  }
}

/// Position of the overlay panel.
enum OverlayAlignment {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}
