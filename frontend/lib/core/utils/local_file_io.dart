import 'dart:io';

Future<bool> localFileExistsAndNonEmpty(String path) async {
  final file = File(path);
  return await file.exists() && await file.length() > 0;
}

Future<void> deleteLocalFile(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Ignore deletion failures for temporary files
  }
}
