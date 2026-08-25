abstract final class TraelyxRoutes {
  static const root = '/';
  static const drive = '/drive';
  static const trips = '/trips';
  static const tripResultPattern = '/trips/:tripId';
  static const dna = '/dna';
  static const social = '/social';
  static const you = '/you';
  static const youDiagnostics = '/you/diagnostics';

  static String tripResult(String tripId) =>
      '$trips/${Uri.encodeComponent(tripId)}';
}
