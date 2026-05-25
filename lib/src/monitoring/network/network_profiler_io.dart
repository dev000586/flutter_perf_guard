import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/bus/diagnostics_event_bus.dart';

/// Hooks into [HttpOverrides.global] to intercept every HTTP request
/// and record URL, method, status, duration, and response size.
///
/// Install via [NetworkProfiler.install()] — call once at app startup.
/// Works on all native platforms. No-op on web (dart:io unavailable).
class NetworkProfiler {
  final List<NetworkRequestRecord> _records = [];

  NetworkProfiler({required DiagnosticsEventBus bus});

  static void install({
    required NetworkProfiler profiler,
  }) {
    HttpOverrides.global = _PerfGuardHttpOverrides(
      profiler,
    );
  }

  static void uninstall() {
    HttpOverrides.global = null;
  }

  void _record(NetworkRequestRecord record) {
    _records.add(record);
    if (_records.length > 200) _records.removeAt(0);
  }

  List<NetworkRequestRecord> get records => List.unmodifiable(_records);

  List<NetworkRequestRecord> get slowRequests =>
      _records.where((r) => r.isSlow).toList();

  List<NetworkRequestRecord> get failedRequests =>
      _records.where((r) => r.hasFailed).toList();

  Map<String, dynamic> toJson() {
    if (_records.isEmpty) {
      return {'totalRequests': 0, 'note': 'No requests recorded'};
    }

    final durations =
    _records.map((r) => r.durationMs).where((d) => d > 0).toList();
    final avgMs = durations.isEmpty
        ? 0.0
        : durations.reduce((a, b) => a + b) / durations.length;

    return {
      'totalRequests': _records.length,
      'slowRequests': slowRequests.length,
      'failedRequests': failedRequests.length,
      'averageDurationMs': avgMs.toStringAsFixed(1),
      'requests': _records.map((r) => r.toJson()).toList(),
    };
  }

  String get plainEnglishSummary {
    if (_records.isEmpty) return '✅ No network requests recorded';

    final slow = slowRequests;
    final failed = failedRequests;
    final buffer = StringBuffer();

    if (failed.isNotEmpty) {
      buffer.writeln('❌ ${failed.length} failed request(s)');
      for (final r in failed.take(3)) {
        buffer.writeln('   ${r.method} ${r.url} → ${r.statusCode}');
      }
    }

    if (slow.isNotEmpty) {
      buffer.writeln('⚠ ${slow.length} slow request(s) (> 1s)');
      for (final r in slow.take(3)) {
        buffer.writeln(
            '   ${r.method} ${r.url} → ${r.durationMs.toStringAsFixed(0)}ms');
        buffer.writeln('   Fix: Cache this response or paginate results');
      }
    }

    if (failed.isEmpty && slow.isEmpty) {
      buffer.write('✅ All ${_records.length} requests completed normally');
    }

    return buffer.toString().trimRight();
  }

  /// For testing only — directly adds a record without HTTP interception.
  @visibleForTesting
  void addRecord(NetworkRequestRecord record) => _record(record);
}

/// Records a single HTTP request/response cycle.
class NetworkRequestRecord {
  final String url;
  final String method;
  final int? statusCode;
  final double durationMs;
  final int? responseSizeBytes;
  final DateTime timestamp;
  final String? error;

  const NetworkRequestRecord({
    required this.url,
    required this.method,
    required this.durationMs,
    required this.timestamp,
    this.statusCode,
    this.responseSizeBytes,
    this.error,
  });

  /// Requests taking longer than 1 second are considered slow.
  bool get isSlow => durationMs > 1000;

  bool get hasFailed =>
      error != null || (statusCode != null && statusCode! >= 400);

  Map<String, dynamic> toJson() => {
    'url': url,
    'method': method,
    if (statusCode != null) 'statusCode': statusCode,
    'durationMs': durationMs.toStringAsFixed(1),
    if (responseSizeBytes != null)
      'responseSizeKb': (responseSizeBytes! / 1024).toStringAsFixed(1),
    'timestamp': timestamp.toIso8601String(),
    'isSlow': isSlow,
    'hasFailed': hasFailed,
    if (error != null) 'error': error,
  };
}

/// HttpOverrides implementation that wraps every HttpClient.
class _PerfGuardHttpOverrides extends HttpOverrides {
  final NetworkProfiler _profiler;

  _PerfGuardHttpOverrides(this._profiler);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _InstrumentedHttpClient(
      super.createHttpClient(context),
      _profiler,
    );
  }
}

/// Wraps [HttpClient] to intercept openUrl calls.
class _InstrumentedHttpClient implements HttpClient {
  final HttpClient _inner;
  final NetworkProfiler _profiler;

  _InstrumentedHttpClient(this._inner, this._profiler);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final sw = Stopwatch()..start();
    final timestamp = DateTime.now();

    try {
      return _InstrumentedRequest(
        await _inner.openUrl(method, url),
        method: method,
        url: url.toString(),
        timestamp: timestamp,
        sw: sw,
        profiler: _profiler,
      );
    } catch (e) {
      sw.stop();
      _profiler._record(NetworkRequestRecord(
        url: url.toString(),
        method: method,
        durationMs: sw.elapsedMicroseconds / 1000.0,
        timestamp: timestamp,
        error: e.toString(),
      ));
      rethrow;
    }
  }

  // ─── Delegate all other methods to _inner ──────────────────────────────

  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set autoUncompress(bool v) => _inner.autoUncompress = v;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? v) => _inner.connectionTimeout = v;

  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set idleTimeout(Duration v) => _inner.idleTimeout = v;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? v) => _inner.maxConnectionsPerHost = v;

  @override
  String? get userAgent => _inner.userAgent;

  @override
  set userAgent(String? v) => _inner.userAgent = v;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials c) =>
      _inner.addCredentials(url, realm, c);

  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials c) =>
      _inner.addProxyCredentials(host, port, realm, c);

  @override
  set authenticate(Future<bool> Function(Uri, String, String?)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
      Future<bool> Function(String, int, String, String?)? f) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(bool Function(X509Certificate, String, int)? f) =>
      _inner.badCertificateCallback = f;

  @override
  set findProxy(String Function(Uri)? f) => _inner.findProxy = f;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      openUrl('DELETE', Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      openUrl('GET', Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      openUrl('HEAD', Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      openUrl('PATCH', Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      openUrl('POST', Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      openUrl('PUT', Uri(host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  set connectionFactory(
      Future<ConnectionTask<Socket>> Function(
          Uri url, String? proxyHost, int? proxyPort)?
      f) {
    _inner.connectionFactory = f;
  }

  @override
  set keyLog(Function(String line)? callback) {
    _inner.keyLog = callback;
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    return openUrl(
      method,
      Uri(
        scheme: port == 443 ? 'https' : 'http',
        host: host,
        port: port,
        path: path,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Function.apply(
      _inner.noSuchMethod,
      [invocation],
    );
  }
}

/// Wraps [HttpClientRequest] to capture response timing and status.
class _InstrumentedRequest implements HttpClientRequest {
  final HttpClientRequest _inner;
  @override
  final String method;
  final String url;
  final DateTime timestamp;
  final Stopwatch sw;
  final NetworkProfiler profiler;

  _InstrumentedRequest(
      this._inner, {
        required this.method,
        required this.url,
        required this.timestamp,
        required this.sw,
        required this.profiler,
      });

  @override
  Future<HttpClientResponse> close() async {
    try {
      final response = await _inner.close();

      sw.stop();

      int? size;
      final contentLength = response.contentLength;

      if (contentLength > 0) {
        size = contentLength;
      }

      profiler._record(NetworkRequestRecord(
        url: url,
        method: method,
        statusCode: response.statusCode,
        durationMs: sw.elapsedMicroseconds / 1000.0,
        responseSizeBytes: size,
        timestamp: timestamp,
      ));

      return response;
    } catch (e) {
      sw.stop();

      profiler._record(NetworkRequestRecord(
        url: url,
        method: method,
        durationMs: sw.elapsedMicroseconds / 1000.0,
        timestamp: timestamp,
        error: e.toString(),
      ));

      rethrow;
    }
  }

  // Delegate everything else
  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? st]) => _inner.addError(error, st);

  @override
  Future addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  Future flush() => _inner.flush();

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  Uri get uri => _inner.uri;

  @override
  void write(Object? obj) => _inner.write(obj);

  @override
  void writeAll(Iterable objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void writeln([Object? obj = '']) => _inner.writeln(obj);

  @override
  bool get bufferOutput => _inner.bufferOutput;

  @override
  set bufferOutput(bool v) => _inner.bufferOutput = v;

  @override
  int get contentLength => _inner.contentLength;

  @override
  set contentLength(int v) => _inner.contentLength = v;

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding v) => _inner.encoding = v;

  @override
  bool get followRedirects => _inner.followRedirects;

  @override
  set followRedirects(bool v) => _inner.followRedirects = v;

  @override
  int get maxRedirects => _inner.maxRedirects;

  @override
  set maxRedirects(int v) => _inner.maxRedirects = v;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  set persistentConnection(bool v) => _inner.persistentConnection = v;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _inner.abort(exception, stackTrace);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Function.apply(
      _inner.noSuchMethod,
      [invocation],
    );
  }
}
