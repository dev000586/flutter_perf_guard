import 'package:flutter/painting.dart';

/// Analyzes Flutter's image cache for hit rate, size pressure,
/// and oversized images.
class ImageCacheAnalyzer {
  /// Takes a snapshot of the current image cache state.
  ImageCacheSnapshot snapshot() {
    final cache = PaintingBinding.instance.imageCache;
    return ImageCacheSnapshot(
      currentCount: cache.currentSize,
      maxCount: cache.maximumSize,
      currentSizeBytes: cache.currentSizeBytes,
      maxSizeBytes: cache.maximumSizeBytes,
      pendingCount: cache.currentSizeBytes > 0 ? cache.currentSize : 0,
      liveCount: cache.liveImageCount,
      timestamp: DateTime.now(),
    );
  }

  /// Reduces image cache to [maxBytes] to free memory pressure.
  void trimCacheTo(int maxBytes) {
    PaintingBinding.instance.imageCache.maximumSizeBytes = maxBytes;
  }

  /// Clears the entire image cache.
  void clearCache() {
    PaintingBinding.instance.imageCache.clear();
  }

  String get plainEnglishSummary {
    final snap = snapshot();
    final pct = snap.usagePercent;
    final mb = (snap.currentSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final maxMb =
    (snap.maxSizeBytes / (1024 * 1024)).toStringAsFixed(1);

    if (pct < 0.5) {
      return '✅ Image cache healthy — ${mb}MB / ${maxMb}MB '
          '(${snap.currentCount} images)';
    } else if (pct < 0.85) {
      return '⚠ Image cache filling up — ${mb}MB / ${maxMb}MB '
          '(${snap.currentCount} images)\n'
          '   Fix: Use cacheWidth/cacheHeight on Image widgets to '
          'decode at display size';
    } else {
      return '❌ Image cache almost full — ${mb}MB / ${maxMb}MB\n'
          '   Fix: Reduce PaintingBinding.instance.imageCache.maximumSizeBytes\n'
          '   or add cacheWidth/cacheHeight to large Image widgets';
    }
  }

  Map<String, dynamic> toJson() {
    final snap = snapshot();
    return snap.toJson();
  }
}

class ImageCacheSnapshot {
  final int currentCount;
  final int maxCount;
  final int currentSizeBytes;
  final int maxSizeBytes;
  final int pendingCount;
  final int liveCount;
  final DateTime timestamp;

  const ImageCacheSnapshot({
    required this.currentCount,
    required this.maxCount,
    required this.currentSizeBytes,
    required this.maxSizeBytes,
    required this.pendingCount,
    required this.liveCount,
    required this.timestamp,
  });

  double get usagePercent =>
      maxSizeBytes > 0 ? currentSizeBytes / maxSizeBytes : 0.0;

  double get currentSizeMb => currentSizeBytes / (1024 * 1024);
  double get maxSizeMb => maxSizeBytes / (1024 * 1024);

  Map<String, dynamic> toJson() => {
    'currentCount': currentCount,
    'maxCount': maxCount,
    'currentSizeMb': currentSizeMb.toStringAsFixed(2),
    'maxSizeMb': maxSizeMb.toStringAsFixed(2),
    'usagePercent': (usagePercent * 100).toStringAsFixed(1),
    'liveImageCount': liveCount,
    'timestamp': timestamp.toIso8601String(),
  };
}