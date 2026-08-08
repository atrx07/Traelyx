import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});
