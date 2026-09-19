import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes the export beside the database and returns where it went.
Future<String> saveExport(String contents, String filename) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsString(contents);
  return file.path;
}
