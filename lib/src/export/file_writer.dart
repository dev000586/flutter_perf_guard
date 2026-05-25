import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> writeReportFile(
    String content,
    String? customPath, {
      String extension = 'txt',
    }) async {
  final String dirPath;
  if (customPath != null) {
    dirPath = customPath;
  } else {
    final appDir = await getApplicationDocumentsDirectory();
    dirPath = '${appDir.path}/perf_guard_reports';
  }

  Directory(dirPath).createSync(recursive: true);
  final filename =
      'perf_report_${DateTime.now().millisecondsSinceEpoch}.$extension';
  final file = File('$dirPath/$filename');
  await file.writeAsString(content);
  return file.path;
}