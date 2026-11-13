import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

const _databaseName = 'hisabflow_vault.db';
final _store = StoreRef<String, String>.main();

Future<Database> _database() => databaseFactoryWeb.openDatabase(_databaseName);

Future<String?> readEnvelope() async {
  final database = await _database();
  try {
    return await _store.record('document').get(database);
  } finally {
    await database.close();
  }
}

Future<void> writeEnvelope(String value) async {
  final database = await _database();
  try {
    await _store.record('document').put(database, value);
  } finally {
    await database.close();
  }
}

Future<void> deleteEnvelope() async {
  final database = await _database();
  try {
    await _store.record('document').delete(database);
  } finally {
    await database.close();
  }
}
