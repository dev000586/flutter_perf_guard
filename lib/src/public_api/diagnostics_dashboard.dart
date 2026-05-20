import 'dart:async';

import 'package:flutter/material.dart';

import '../core/bus/diagnostics_event_bus.dart';
import '../core/events/frame_event.dart';
import '../core/events/jank_event.dart';
import '../core/events/memory_event.dart';
import '../core/events/rebuild_event.dart';
import '../profiling/frame/frame_metrics.dart';
import '../profiling/memory/memory_metrics.dart';
import '../profiling/rebuild/rebuild_metrics.dart';

/// Full-screen real-time performance dashboard.
///
/// Push this route from your debug/settings menu:
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(builder: (_) => const DiagnosticsDashboard()),
/// );
/// ```
class DiagnosticsDashboard extends StatefulWidget {
  const DiagnosticsDashboard({super.key});

  @override
  State<DiagnosticsDashboard> createState() => _DiagnosticsDashboardState();
}

class _DiagnosticsDashboardState extends State<DiagnosticsDashboard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _bus = DiagnosticsEventBus.instance;
  final List<StreamSubscription> _subs = [];

  // Frame data
  final List<FrameMetrics> _recentFrames = [];
  double _currentFps = 0.0;
  int _jankCount = 0;

  // Memory data
  final List<MemoryMetrics> _memoryHistory = [];

  // Rebuild data
  final List<RebuildMetrics> _topRebuilds = [];

  // Events log
  final List<String> _eventLog = [];

  static const _maxPoints = 60;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _subs.add(_bus.frameEvents.listen(_onFrame));
    _subs.add(_bus.memoryEvents.listen(_onMemory));
    _subs.add(_bus.rebuildEvents.listen(_onRebuild));
    _subs.add(_bus.jankEvents.listen(_onJank));
  }

  void _onFrame(FrameEvent e) {
    if (!mounted) return;
    setState(() {
      _recentFrames.add(e.metrics);
      if (_recentFrames.length > _maxPoints) _recentFrames.removeAt(0);
      _currentFps = e.metrics.fps;
      _eventLog.insert(0,
          '[FRAME] #${e.metrics.frameNumber} ${e.metrics.totalDuration.inMilliseconds}ms');
      if (_eventLog.length > 200) _eventLog.removeLast();
    });
  }

  void _onMemory(MemoryEvent e) {
    if (!mounted) return;
    setState(() {
      _memoryHistory.add(e.metrics);
      if (_memoryHistory.length > _maxPoints) _memoryHistory.removeAt(0);
      if (e.leakSuspected) {
        _eventLog.insert(0,
            '[MEM ⚠] Potential leak – heap ${e.metrics.heapUsedMb.toStringAsFixed(1)}MB');
      }
    });
  }

  void _onRebuild(RebuildEvent e) {
    if (!mounted) return;
    setState(() {
      final idx = _topRebuilds
          .indexWhere((m) => m.widgetType == e.metrics.widgetType);
      if (idx >= 0) {
        _topRebuilds[idx] = e.metrics;
      } else {
        _topRebuilds.add(e.metrics);
      }
      _topRebuilds.sort((a, b) => b.rebuildCount.compareTo(a.rebuildCount));
      if (_topRebuilds.length > 20) _topRebuilds.removeLast();
    });
  }

  void _onJank(JankEvent e) {
    if (!mounted) return;
    setState(() {
      _jankCount++;
      _eventLog.insert(0,
          '[JANK 🔴] ${e.consecutiveJankFrames} frames, worst ${e.worstFrameDuration.inMilliseconds}ms');
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          '⚡ PerfGuard Dashboard',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF58A6FF),
          labelColor: const Color(0xFF58A6FF),
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'FRAMES'),
            Tab(text: 'MEMORY'),
            Tab(text: 'REBUILDS'),
            Tab(text: 'LOG'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FrameTab(
            frames: _recentFrames,
            currentFps: _currentFps,
            jankCount: _jankCount,
          ),
          _MemoryTab(history: _memoryHistory),
          _RebuildTab(rebuilds: _topRebuilds),
          _EventLogTab(events: _eventLog),
        ],
      ),
    );
  }
}

// ─── Frame Tab ────────────────────────────────────────────────────────────────

class _FrameTab extends StatelessWidget {
  final List<FrameMetrics> frames;
  final double currentFps;
  final int jankCount;

  const _FrameTab({
    required this.frames,
    required this.currentFps,
    required this.jankCount,
  });

  @override
  Widget build(BuildContext context) {
    final jankFrames = frames.where((f) => f.isJank).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              _StatCard(
                label: 'FPS',
                value: currentFps.toStringAsFixed(1),
                color: currentFps >= 55
                    ? const Color(0xFF4CAF50)
                    : currentFps >= 30
                        ? const Color(0xFFFF9800)
                        : const Color(0xFFF44336),
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Jank Events',
                value: jankCount.toString(),
                color: jankCount > 0
                    ? const Color(0xFFF44336)
                    : const Color(0xFF4CAF50),
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Jank Frames',
                value: jankFrames.toString(),
                color: jankFrames > 0
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF4CAF50),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Frame chart
          const Text(
            'Frame Durations (ms)',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _FrameBarChart(frames: frames),
          ),
        ],
      ),
    );
  }
}

class _FrameBarChart extends StatelessWidget {
  final List<FrameMetrics> frames;

  const _FrameBarChart({required this.frames});

  @override
  Widget build(BuildContext context) {
    if (frames.isEmpty) {
      return const Center(
        child: Text('Waiting for frames…',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return CustomPaint(
      painter: _FrameChartPainter(frames: frames),
      child: Container(),
    );
  }
}

class _FrameChartPainter extends CustomPainter {
  final List<FrameMetrics> frames;

  static final _goodPaint = Paint()..color = const Color(0xFF4CAF50);
  static final _slowPaint = Paint()..color = const Color(0xFFFF9800);
  static final _jankPaint = Paint()..color = const Color(0xFFF44336);
  static final _gridPaint = Paint()
    ..color = const Color(0x33FFFFFF)
    ..strokeWidth = 0.5;
  static final _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );

  const _FrameChartPainter({required this.frames});

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.isEmpty) return;

    const maxMs = 50.0;
    final barWidth = size.width / frames.length;
    const jankLine = 16.0;
    const slowLine = 8.0;

    // Grid lines
    for (final ms in [8.0, 16.0, 33.0]) {
      final y = size.height - (ms / maxMs * size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }

    // Bars
    for (int i = 0; i < frames.length; i++) {
      final ms = frames[i].totalDuration.inMicroseconds / 1000.0;
      final barHeight = (ms / maxMs * size.height).clamp(1.0, size.height);
      final x = i * barWidth;
      final y = size.height - barHeight;

      final paint = ms > jankLine
          ? _jankPaint
          : ms > slowLine
              ? _slowPaint
              : _goodPaint;

      canvas.drawRect(
        Rect.fromLTWH(x + 1, y, barWidth - 2, barHeight),
        paint,
      );
    }

    // 16ms label
    _textPainter.text = const TextSpan(
      text: '16ms',
      style: TextStyle(color: Color(0xFFF44336), fontSize: 9),
    );
    _textPainter.layout();
    final jankY = size.height - (jankLine / maxMs * size.height);
    _textPainter.paint(canvas, Offset(2, jankY - 12));
  }

  @override
  bool shouldRepaint(_FrameChartPainter old) => old.frames != frames;
}

// ─── Memory Tab ───────────────────────────────────────────────────────────────

class _MemoryTab extends StatelessWidget {
  final List<MemoryMetrics> history;

  const _MemoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    final latest = history.isNotEmpty ? history.last : null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest != null) ...[
            Row(
              children: [
                _StatCard(
                  label: 'Heap',
                  value: '${latest.heapUsedMb.toStringAsFixed(1)}MB',
                  color: latest.heapUsagePercent > 0.85
                      ? const Color(0xFFF44336)
                      : const Color(0xFF4CAF50),
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'RSS',
                  value: '${latest.rssMb.toStringAsFixed(1)}MB',
                  color: Colors.white70,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'External',
                  value: '${latest.externalMb.toStringAsFixed(1)}MB',
                  color: Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Heap usage bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: latest.heapUsagePercent.clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF30363D),
                valueColor: AlwaysStoppedAnimation(
                  latest.heapUsagePercent > 0.85
                      ? const Color(0xFFF44336)
                      : const Color(0xFF4CAF50),
                ),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(latest.heapUsagePercent * 100).toStringAsFixed(0)}% of '
              '${latest.heapCapacityMb.toStringAsFixed(0)}MB capacity',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Heap Usage Over Time',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Expanded(child: _MemoryLineChart(history: history)),
        ],
      ),
    );
  }
}

class _MemoryLineChart extends StatelessWidget {
  final List<MemoryMetrics> history;

  const _MemoryLineChart({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Text('Collecting memory samples…',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return CustomPaint(
      painter: _MemoryChartPainter(history: history),
      child: Container(),
    );
  }
}

class _MemoryChartPainter extends CustomPainter {
  final List<MemoryMetrics> history;

  _MemoryChartPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;

    final maxHeap = history
        .map((m) => m.heapCapacityBytes.toDouble())
        .reduce((a, b) => a > b ? a : b);

    final paint = Paint()
      ..color = const Color(0xFF58A6FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = const Color(0x2058A6FF)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < history.length; i++) {
      final x = i / (history.length - 1) * size.width;
      final y =
          size.height - (history[i].heapUsedBytes / maxHeap * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MemoryChartPainter old) => old.history != history;
}

// ─── Rebuild Tab ──────────────────────────────────────────────────────────────

class _RebuildTab extends StatelessWidget {
  final List<RebuildMetrics> rebuilds;

  const _RebuildTab({required this.rebuilds});

  @override
  Widget build(BuildContext context) {
    if (rebuilds.isEmpty) {
      return const Center(
        child: Text('No rebuild data yet.',
            style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rebuilds.length,
      itemBuilder: (context, i) {
        final m = rebuilds[i];
        return _RebuildRow(metrics: m, rank: i + 1);
      },
    );
  }
}

class _RebuildRow extends StatelessWidget {
  final RebuildMetrics metrics;
  final int rank;

  const _RebuildRow({required this.metrics, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isExcessive = metrics.isExcessive;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isExcessive
              ? const Color(0xFFF44336)
              : const Color(0xFF30363D),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  isExcessive ? const Color(0x33F44336) : const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                color: isExcessive
                    ? const Color(0xFFF44336)
                    : Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics.widgetType,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${metrics.rebuildCount} rebuilds · '
                  '${metrics.rebuildsPerSecond.toStringAsFixed(1)}/s · '
                  'avg ${metrics.averageRebuildTime.inMicroseconds / 1000.0}ms',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          if (isExcessive)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text('⚠', style: TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
  }
}

// ─── Event Log Tab ────────────────────────────────────────────────────────────

class _EventLogTab extends StatelessWidget {
  final List<String> events;

  const _EventLogTab({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text('No events yet.', style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          events[i],
          style: TextStyle(
            color: events[i].contains('JANK') || events[i].contains('MEM ⚠')
                ? const Color(0xFFF44336)
                : const Color(0xFFE6EDF3),
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
