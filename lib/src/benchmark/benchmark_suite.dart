/// A named collection of benchmarks.
class BenchmarkSuite {
  final String name;
  final String? description;
  final List<BenchmarkEntry> benchmarks = [];

  BenchmarkSuite({required this.name, this.description});

  /// Adds a synchronous benchmark.
  void add(String name, void Function() body, {String? description}) {
    benchmarks.add(BenchmarkEntry.sync(
      name: name,
      body: body,
      description: description,
    ));
  }

  /// Adds an asynchronous benchmark.
  void addAsync(String name, Future<void> Function() body,
      {String? description}) {
    benchmarks.add(BenchmarkEntry.async(
      name: name,
      asyncBody: body,
      description: description,
    ));
  }
}

/// A single named benchmark entry inside a [BenchmarkSuite].
class BenchmarkEntry {
  final String name;
  final String? description;
  final void Function()? body;
  final Future<void> Function()? asyncBody;

  bool get isAsync => asyncBody != null;

  const BenchmarkEntry._({
    required this.name,
    this.description,
    this.body,
    this.asyncBody,
  });

  factory BenchmarkEntry.sync({
    required String name,
    required void Function() body,
    String? description,
  }) =>
      BenchmarkEntry._(name: name, body: body, description: description);

  factory BenchmarkEntry.async({
    required String name,
    required Future<void> Function() asyncBody,
    String? description,
  }) =>
      BenchmarkEntry._(
          name: name, asyncBody: asyncBody, description: description);
}
