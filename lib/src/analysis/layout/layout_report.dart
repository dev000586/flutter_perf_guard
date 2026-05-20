/// Report on layout pass overdraw and expensive layout operations.
class LayoutReport {
  final int totalLayoutPasses;
  final int excessivePasses;
  final List<LayoutHotspot> hotspots;
  final DateTime generatedAt;

  const LayoutReport({
    required this.totalLayoutPasses,
    required this.excessivePasses,
    required this.hotspots,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
        'totalLayoutPasses': totalLayoutPasses,
        'excessivePasses': excessivePasses,
        'hotspots': hotspots.map((h) => h.toJson()).toList(),
        'generatedAt': generatedAt.toIso8601String(),
      };
}

class LayoutHotspot {
  final String widgetType;
  final int layoutPassCount;
  final Duration averageLayoutTime;

  const LayoutHotspot({
    required this.widgetType,
    required this.layoutPassCount,
    required this.averageLayoutTime,
  });

  Map<String, dynamic> toJson() => {
        'widgetType': widgetType,
        'layoutPassCount': layoutPassCount,
        'averageLayoutTimeMs': averageLayoutTime.inMicroseconds / 1000,
      };
}
