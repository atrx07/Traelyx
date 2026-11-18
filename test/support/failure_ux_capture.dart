import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

Widget failureUxBoundary(Widget child) =>
    RepaintBoundary(key: const ValueKey('failure-ux-boundary'), child: child);

Future<void>? _fonts;

ThemeData failureUxTheme() {
  final base = TraelyxTheme.dark;
  final texts = base.textTheme.apply(fontFamily: 'FailureUxRoboto');
  return base.copyWith(
    textTheme: texts,
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: 'FailureUxRoboto',
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(texts.labelLarge),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(texts.labelLarge),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(texts.labelLarge),
      ),
    ),
  );
}

/// Installed SDK fonts make synthetic captures readable without app changes.
Future<void> loadFailureUxFonts() => _fonts ??= () async {
  final config = File('.dart_tool/package_config.json');
  final packages =
      jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final flutter = (packages['packages'] as List)
      .cast<Map<String, dynamic>>()
      .singleWhere((p) => p['name'] == 'flutter');
  final packageRoot = Uri.directory(
    config.absolute.uri.resolve(flutter['rootUri'] as String).toFilePath(),
  );
  final root = packageRoot.resolve('../../bin/cache/artifacts/material_fonts/');
  final text = FontLoader('FailureUxRoboto');
  for (final name in [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
  ]) {
    text.addFont(
      File.fromUri(
        root.resolve(name),
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await text.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File.fromUri(
        root.resolve('materialicons-regular.otf'),
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  await icons.load();
}();

/// Synthetic production-widget render, never a device screenshot or golden.
Future<void> captureFailureUx(WidgetTester tester, String name) async {
  if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(name)) {
    throw ArgumentError('Invalid synthetic capture name');
  }
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('failure-ux-boundary')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Synthetic capture unavailable');
      final output = File('build/reports/failure-ux-v1/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
