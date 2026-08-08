import 'dart:convert';
import 'dart:io';

const _apkPaths = {
  'debug': 'build/app/outputs/flutter-apk/app-debug.apk',
  'release-validation': 'build/app/outputs/flutter-apk/app-release.apk',
};
const _reportPath = 'build/reports/apk-size.json';

void main() {
  final artifacts = <Map<String, Object>>[];
  for (final entry in _apkPaths.entries) {
    final apk = File(entry.value);
    if (!apk.existsSync()) {
      stderr.writeln('APK not found at ${entry.value}. Build all APKs first.');
      exitCode = 2;
      return;
    }

    final sizeBytes = apk.lengthSync();
    artifacts.add({
      'artifact': entry.value,
      'variant': entry.key,
      'size_bytes': sizeBytes,
      'size_megabytes': double.parse(
        (sizeBytes / (1024 * 1024)).toStringAsFixed(2),
      ),
    });
  }

  final report = <String, Object>{'artifacts': artifacts};

  final output = File(_reportPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(jsonEncode(report));
}
