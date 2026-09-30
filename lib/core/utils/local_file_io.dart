import 'dart:io';

Future<bool> localFileExistsAndNonEmpty(String path) async {
  final file = File(path);
  return await file.exists() && await file.length() > 0;
}
