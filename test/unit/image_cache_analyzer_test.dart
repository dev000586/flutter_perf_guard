import 'package:flutter/painting.dart';
import 'package:flutter_perf_guard/src/monitoring/image/image_cache_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageCacheSnapshot', () {
    late ImageCacheSnapshot snapshot;

    setUp(() {
      snapshot = ImageCacheSnapshot(
        currentCount: 10,
        maxCount: 100,
        currentSizeBytes: 10 * 1024 * 1024, // 10MB
        maxSizeBytes: 100 * 1024 * 1024,     // 100MB
        pendingCount: 2,
        liveCount: 8,
        timestamp: DateTime.now(),
      );
    });

    test('usagePercent is correct', () {
      expect(snapshot.usagePercent, closeTo(0.10, 0.001));
    });

    test('currentSizeMb is correct', () {
      expect(snapshot.currentSizeMb, closeTo(10.0, 0.01));
    });

    test('maxSizeMb is correct', () {
      expect(snapshot.maxSizeMb, closeTo(100.0, 0.01));
    });

    test('toJson contains all required keys', () {
      final json = snapshot.toJson();
      expect(json.keys, containsAll([
        'currentCount',
        'maxCount',
        'currentSizeMb',
        'maxSizeMb',
        'usagePercent',
        'liveImageCount',
        'timestamp',
      ]));
    });

    test('toJson usagePercent is formatted as string with %', () {
      final json = snapshot.toJson();
      expect(json['usagePercent'], equals('10.0'));
    });

    test('usagePercent is 0 when maxSizeBytes is 0', () {
      final snap = ImageCacheSnapshot(
        currentCount: 0,
        maxCount: 0,
        currentSizeBytes: 0,
        maxSizeBytes: 0,
        pendingCount: 0,
        liveCount: 0,
        timestamp: DateTime.now(),
      );
      expect(snap.usagePercent, equals(0.0));
    });
  });

  group('ImageCacheAnalyzer', () {
    late ImageCacheAnalyzer analyzer;

    setUp(() {
      analyzer = ImageCacheAnalyzer();
    });

    testWidgets('snapshot returns current cache state', (tester) async {
      final snap = analyzer.snapshot();
      expect(snap, isNotNull);
      expect(snap.currentCount, greaterThanOrEqualTo(0));
      expect(snap.maxCount, greaterThan(0));
      expect(snap.maxSizeBytes, greaterThan(0));
    });

    testWidgets('plainEnglishSummary returns non-empty string',
            (tester) async {
          final summary = analyzer.plainEnglishSummary;
          expect(summary, isNotEmpty);
        });

    testWidgets('plainEnglishSummary shows healthy for empty cache',
            (tester) async {
          PaintingBinding.instance.imageCache.clear();
          final summary = analyzer.plainEnglishSummary;
          expect(summary, contains('✅'));
        });

    testWidgets('toJson returns valid map', (tester) async {
      final json = analyzer.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json.containsKey('currentCount'), isTrue);
    });

    testWidgets('clearCache empties the cache', (tester) async {
      analyzer.clearCache();
      final snap = analyzer.snapshot();
      expect(snap.currentCount, equals(0));
    });
  });
}