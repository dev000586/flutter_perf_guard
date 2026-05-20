/// Report on repaint boundary effectiveness.
class RepaintReport {
  final int totalRepaintBoundaries;
  final int effectiveBoundaries;
  final int ineffectiveBoundaries;
  final List<RepaintZone> zones;
  final DateTime generatedAt;

  const RepaintReport({
    required this.totalRepaintBoundaries,
    required this.effectiveBoundaries,
    required this.ineffectiveBoundaries,
    required this.zones,
    required this.generatedAt,
  });

  double get effectivenessRate => totalRepaintBoundaries > 0
      ? effectiveBoundaries / totalRepaintBoundaries
      : 0.0;

  Map<String, dynamic> toJson() => {
        'totalRepaintBoundaries': totalRepaintBoundaries,
        'effectiveBoundaries': effectiveBoundaries,
        'ineffectiveBoundaries': ineffectiveBoundaries,
        'effectivenessRate': effectivenessRate,
        'zones': zones.map((z) => z.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };
}

class RepaintZone {
  final String widgetType;
  final int repaintCount;
  final bool hasIsolation;

  const RepaintZone({
    required this.widgetType,
    required this.repaintCount,
    required this.hasIsolation,
  });

  Map<String, dynamic> toJson() => {
        'widgetType': widgetType,
        'repaintCount': repaintCount,
        'hasIsolation': hasIsolation,
      };
}
