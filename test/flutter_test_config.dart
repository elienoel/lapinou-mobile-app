import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Les tests s'exécutent sur la VM Dart (pas de plateforme mobile), donc sqflite
/// a besoin du backend FFI plutôt que de son canal de plateforme habituel. On
/// utilise la variante « no isolate » : la variante par défaut exécute les
/// requêtes sur un isolate séparé, ce qui bloque indéfiniment sous le faux
/// event loop des `testWidgets` (TimeoutException sur `_RawReceivePort`).
/// Chaque fichier de test repart d'une base vide pour rester indépendant.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  final dbPath = join(await databaseFactory.getDatabasesPath(), 'lapinou_offline.db');
  final file = File(dbPath);
  if (await file.exists()) {
    await file.delete();
  }

  await testMain();
}
