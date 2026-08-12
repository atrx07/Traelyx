import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _excludedDirectories = {'.dart_tool', '.git', '.idea', 'build'};

const _sensitiveExtensions = {'.jks', '.keystore', '.p12', '.pfx'};
const _textExtensions = {
  '.dart',
  '.gradle',
  '.json',
  '.kts',
  '.kt',
  '.md',
  '.properties',
  '.py',
  '.txt',
  '.yaml',
  '.yml',
  '.xml',
};

final _secretPatterns = <String, RegExp>{
  'private key block': RegExp(
    '-----BEGIN [A-Z ]*PRIVATE'
    ' KEY-----',
  ),
  'GitHub token': RegExp(r'gh[pousr]_[A-Za-z0-9]{30,}'),
  'AWS access key': RegExp(r'AKIA[0-9A-Z]{16}'),
  'Google API key': RegExp(r'AIza[0-9A-Za-z_-]{35}'),
};

void main() {
  final failures = <String>[];
  final files = _repositoryFiles(Directory.current).toList()
    ..sort((left, right) => left.path.compareTo(right.path));

  for (final file in files) {
    final normalizedPath = file.path.replaceAll('\\', '/');
    final lowerPath = normalizedPath.toLowerCase();
    final name = file.uri.pathSegments.last;
    final extension = _extension(name);

    if (_sensitiveExtensions.contains(extension) ||
        (name.startsWith('.env') && name != '.env.example') ||
        lowerPath.endsWith('/key.properties')) {
      failures.add('$normalizedPath: sensitive file must not be committed');
      continue;
    }

    if (extension == '.tripdebug' && !lowerPath.contains('tests/fixtures/')) {
      failures.add(
        '$normalizedPath: precise/private trip archive must stay outside the repository',
      );
      continue;
    }

    if (extension == '.json') {
      try {
        jsonDecode(file.readAsStringSync());
      } on FormatException catch (error) {
        failures.add('$normalizedPath: invalid JSON (${error.message})');
      }
    } else if (extension == '.yaml' || extension == '.yml') {
      try {
        loadYaml(file.readAsStringSync());
      } on YamlException catch (error) {
        failures.add('$normalizedPath: invalid YAML (${error.message})');
      }
    }

    if (_textExtensions.contains(extension)) {
      final contents = file.readAsStringSync();
      for (final entry in _secretPatterns.entries) {
        if (entry.value.hasMatch(contents)) {
          failures.add('$normalizedPath: possible ${entry.key}');
        }
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Repository validation failed:');
    for (final failure in failures) {
      stderr.writeln('  - $failure');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Repository validation passed: JSON/YAML parsed and no known secret '
    'patterns or sensitive filenames were found.',
  );
}

Iterable<File> _repositoryFiles(Directory root) sync* {
  for (final entity in root.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last;
    if (entity is Directory) {
      if (!_excludedDirectories.contains(name)) {
        yield* _repositoryFiles(entity);
      }
    } else if (entity is File) {
      yield entity;
    }
  }
}

String _extension(String name) {
  final separator = name.lastIndexOf('.');
  return separator <= 0 ? '' : name.substring(separator).toLowerCase();
}
