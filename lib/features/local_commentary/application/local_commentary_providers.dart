import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:traelyx/core/platform/recorder_providers.dart';
import 'package:traelyx/features/local_commentary/application/local_commentary_service.dart';
import 'package:traelyx/features/local_commentary/data/local_model_platform.dart';
import 'package:traelyx/features/local_commentary/domain/local_commentary.dart';

final localCommentaryServiceProvider = Provider<LocalCommentaryService>((ref) {
  final service = LocalCommentaryService(
    catalog: () async => LocalModelCatalog.parse(
      await rootBundle.loadString(
        'docs/reference/local-commentary-catalog-v1.json',
      ),
    ),
    device: const LocalModelPlatform().device,
    runtime: const UnavailableLocalRuntime(),
    source: const UnavailableLocalSource(),
    isRecorderIdle: () async {
      final status =
          (await ref.read(recorderBridgeProvider).getStatus()).lifecycle;
      return status.contractVersion == 1 &&
          status.state == 'idle' &&
          !status.active &&
          status.tripId == null &&
          status.errorCode == null;
    },
  );
  ref.onDispose(service.cancel);
  return service;
});
