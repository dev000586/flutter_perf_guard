import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Captures debug-only location info for a widget element.
/// In profile/release mode all fields are null.
class RebuildLocation {
  /// Full ancestor chain e.g. "HomeScreen > Column > ListView > ProductCard"
  final String? ancestorPath;

  /// File info if available e.g. "lib/screens/home_screen.dart:142"
  /// Only populated in debug mode via debugGetCreatorChain.
  final String? fileInfo;

  const RebuildLocation({
    this.ancestorPath,
    this.fileInfo,
  });


  /// Captures location from [element]. Only returns real data in debug mode.
  static RebuildLocation capture(Element element) {

    if (!kDebugMode) {
      return const RebuildLocation();
    }

    // ── Ancestor path ──────────────────────────────────────────────────
    final ancestors = <String>[];
    try {
      element.visitAncestorElements((ancestor) {
        final name = ancestor.widget.runtimeType.toString();
        // Skip private/internal Flutter framework widgets
        if (!name.startsWith('_') && ancestors.length < 8) {
          ancestors.add(name);
        }
        return ancestors.length < 8;
      });
    } catch (_) {
      // visitAncestorElements can throw if element is unmounted
    }
    final path = ancestors.reversed.join(' > ');

    // ── File info via debugGetCreatorChain ─────────────────────────────
    // debugGetCreatorChain returns a string like:
    // "ProductCard ← ListView ← Column ← HomeScreen ← ..."
    // It does NOT include file names — those are only in DiagnosticsNode.
    //
    // To get file info we use element.debugGetDiagnosticChain() which
    // returns List<DiagnosticsNode> — each node's toStringDeep() may
    // contain source location on supported platforms.
    String? fileInfo;
    try {
      // The creator chain string sometimes embeds source location
      // when Flutter's widget-creation tracking is enabled (default in debug).
      // Format varies: "WidgetName (file:///path/to/file.dart:line:col)"
      final chain = element.debugGetCreatorChain(12);
      // Extract lib/...dart:line pattern from the chain string
      final match = RegExp(r'(lib[/\\][^\s:)]+\.dart):(\d+)').firstMatch(chain);
      if (match != null) {
        fileInfo = '${match.group(1)}:${match.group(2)}';
      }
    } catch (_) {
      // debugGetCreatorChain not available in all configurations
    }

    return RebuildLocation(
      ancestorPath: path.isNotEmpty ? path : null,
      fileInfo: fileInfo,
    );
  }

  Map<String, dynamic> toJson() => {
    if (ancestorPath != null) 'ancestorPath': ancestorPath,
    if (fileInfo != null) 'fileInfo': fileInfo,
    if (ancestorPath == null && fileInfo == null)
      'note': 'Run in debug mode to see file location',
  };

  @override
  String toString() {
    if (fileInfo != null) return fileInfo!;
    if (ancestorPath != null) return ancestorPath!;
    return 'debug mode only';
  }
}
