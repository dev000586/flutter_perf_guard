import 'dart:io';

/// Returns the current process RSS in bytes using [ProcessInfo.currentRss].
/// Available on all native platforms (Android, iOS, macOS, Windows, Linux).
int getPlatformRss() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return 0;
  }
}
