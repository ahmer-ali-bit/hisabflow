import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _file() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return File('${directory.path}/hisabflow.vault');
}

Future<String?> readEnvelope() async {
  final file = await _file();
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeEnvelope(String value) async {
  final file = await _file();
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(value, flush: true);
  // Renaming over the existing file is atomic on the same filesystem. Never
  // delete the old vault first: a crash in between would destroy the only copy.
  await temporary.rename(file.path);
}

Future<void> deleteEnvelope() async {
  final file = await _file();
  if (await file.exists()) await file.delete();
}
