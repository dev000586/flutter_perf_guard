import 'package:flutter_perf_guard/src/core/bus/diagnostics_event_bus.dart';
import 'package:flutter_perf_guard/src/monitoring/network/network_profiler.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  final bus = DiagnosticsEventBus.instance;

  group('NetworkRequestRecord', () {
    test('isSlow is true for requests > 1000ms', () {
      final record = NetworkRequestRecord(
        url: 'https://example.com',
        method: 'GET',
        statusCode: 200,
        durationMs: 1500,
        timestamp: DateTime.now(),
      );
      expect(record.isSlow, isTrue);
    });

    test('isSlow is false for requests <= 1000ms', () {
      final record = NetworkRequestRecord(
        url: 'https://example.com',
        method: 'GET',
        statusCode: 200,
        durationMs: 999,
        timestamp: DateTime.now(),
      );
      expect(record.isSlow, isFalse);
    });

    test('hasFailed is true for status >= 400', () {
      for (final code in [400, 401, 403, 404, 500, 503]) {
        final record = NetworkRequestRecord(
          url: 'https://example.com',
          method: 'GET',
          statusCode: code,
          durationMs: 100,
          timestamp: DateTime.now(),
        );
        expect(record.hasFailed, isTrue,
            reason: 'status $code should be failed');
      }
    });

    test('hasFailed is false for status < 400', () {
      for (final code in [200, 201, 204, 301, 302]) {
        final record = NetworkRequestRecord(
          url: 'https://example.com',
          method: 'GET',
          statusCode: code,
          durationMs: 100,
          timestamp: DateTime.now(),
        );
        expect(record.hasFailed, isFalse,
            reason: 'status $code should not be failed');
      }
    });

    test('hasFailed is true when error is set', () {
      final record = NetworkRequestRecord(
        url: 'https://example.com',
        method: 'GET',
        durationMs: 50,
        timestamp: DateTime.now(),
        error: 'Connection refused',
      );
      expect(record.hasFailed, isTrue);
    });

    test('toJson contains all required keys', () {
      final record = NetworkRequestRecord(
        url: 'https://example.com/api',
        method: 'POST',
        statusCode: 201,
        durationMs: 250,
        responseSizeBytes: 1024,
        timestamp: DateTime.now(),
      );
      final json = record.toJson();
      expect(json.keys, containsAll([
        'url', 'method', 'statusCode',
        'durationMs', 'responseSizeKb',
        'timestamp', 'isSlow', 'hasFailed',
      ]));
    });

    test('toJson omits statusCode when null', () {
      final record = NetworkRequestRecord(
        url: 'https://example.com',
        method: 'GET',
        durationMs: 100,
        timestamp: DateTime.now(),
        error: 'Timeout',
      );
      final json = record.toJson();
      expect(json.containsKey('statusCode'), isFalse);
      expect(json['error'], equals('Timeout'));
    });

    test('responseSizeKb is correctly calculated', () {
      final record = NetworkRequestRecord(
        url: 'https://example.com',
        method: 'GET',
        statusCode: 200,
        durationMs: 100,
        responseSizeBytes: 2048,
        timestamp: DateTime.now(),
      );
      final json = record.toJson();
      expect(double.parse(json['responseSizeKb'] as String),
          closeTo(2.0, 0.01));
    });
  });

  group('NetworkProfiler', () {
    late NetworkProfiler profiler;

    setUp(() {
      // Create directly — do NOT call NetworkProfiler.install()
      // in unit tests as it sets HttpOverrides.global which is
      // not available in the Flutter test environment.
      profiler = NetworkProfiler(bus: bus);
    });

    tearDown(() {
      profiler = NetworkProfiler(bus: bus); // fresh instance
    });

    test('records is empty initially', () {
      expect(profiler.records, isEmpty);
    });

    test('slowRequests is empty initially', () {
      expect(profiler.slowRequests, isEmpty);
    });

    test('failedRequests is empty initially', () {
      expect(profiler.failedRequests, isEmpty);
    });

    test('_record adds to records', () {
      profiler.addRecord(NetworkRequestRecord(
        url: 'https://example.com',
        method: 'GET',
        statusCode: 200,
        durationMs: 100,
        timestamp: DateTime.now(),
      ));
      expect(profiler.records.length, equals(1));
    });

    test('slowRequests returns only slow records', () {
      profiler.addRecord(NetworkRequestRecord(
        url: 'https://fast.com',
        method: 'GET',
        statusCode: 200,
        durationMs: 100,
        timestamp: DateTime.now(),
      ));
      profiler.addRecord(NetworkRequestRecord(
        url: 'https://slow.com',
        method: 'GET',
        statusCode: 200,
        durationMs: 2000,
        timestamp: DateTime.now(),
      ));
      expect(profiler.slowRequests.length, equals(1));
      expect(profiler.slowRequests.first.url, equals('https://slow.com'));
    });

    test('failedRequests returns only failed records', () {
      profiler.addRecord(NetworkRequestRecord(
        url: 'https://ok.com',
        method: 'GET',
        statusCode: 200,
        durationMs: 100,
        timestamp: DateTime.now(),
      ));
      profiler.addRecord(NetworkRequestRecord(
        url: 'https://fail.com',
        method: 'GET',
        statusCode: 500,
        durationMs: 100,
        timestamp: DateTime.now(),
      ));
      expect(profiler.failedRequests.length, equals(1));
      expect(
          profiler.failedRequests.first.url, equals('https://fail.com'));
    });

    test('records capped at 200', () {
      for (int i = 0; i < 250; i++) {
        profiler.addRecord(NetworkRequestRecord(
          url: 'https://example.com/$i',
          method: 'GET',
          statusCode: 200,
          durationMs: 100,
          timestamp: DateTime.now(),
        ));
      }
      // List.of() returns a mutable copy so length check works fine
      expect(profiler.records.length, equals(200));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('plainEnglishSummary shows positive message when no issues', () {
      profiler.addRecord(NetworkRequestRecord(
        url: 'https://example.com',
        method: 'GET',
        statusCode: 200,
        durationMs: 100,
        timestamp: DateTime.now(),
      ));
      expect(profiler.plainEnglishSummary, contains('✅'));
    });

    test('plainEnglishSummary flags slow requests', () {
      profiler.addRecord(NetworkRequestRecord(
        url: 'https://slow.com/api',
        method: 'GET',
        statusCode: 200,
        durationMs: 3000,
        timestamp: DateTime.now(),
      ));
      final summary = profiler.plainEnglishSummary;
      expect(summary, contains('⚠'));
      expect(summary, contains('slow'));
    });

    test('plainEnglishSummary flags failed requests', () {
      profiler.addRecord(NetworkRequestRecord(
        url: 'https://fail.com/api',
        method: 'POST',
        statusCode: 404,
        durationMs: 100,
        timestamp: DateTime.now(),
      ));
      final summary = profiler.plainEnglishSummary;
      expect(summary, contains('❌'));
    });

    test('toJson returns totalRequests count', () {
      for (int i = 0; i < 5; i++) {
        profiler.addRecord(NetworkRequestRecord(
          url: 'https://example.com/$i',
          method: 'GET',
          statusCode: 200,
          durationMs: 100,
          timestamp: DateTime.now(),
        ));
      }
      final json = profiler.toJson();
      expect(json['totalRequests'], equals(5));
    });

    test('toJson when empty shows zero', () {
      final json = profiler.toJson();
      expect(json['totalRequests'], equals(0));
    });
  });
}

