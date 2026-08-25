import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/database/database_providers.dart';
import 'package:traelyx/features/drive_dna/data/drive_dna_repository.dart';
import 'package:traelyx/features/drive_dna/domain/drive_dna_models.dart';

final driveDnaRepositoryProvider = Provider<DriveDnaRepository>((ref) {
  return DriftDriveDnaRepository(ref.watch(appDatabaseProvider));
});

final driveDnaProvider = StreamProvider.autoDispose<DriveDnaSnapshot?>((ref) {
  return ref.watch(driveDnaRepositoryProvider).watchLatest();
});
