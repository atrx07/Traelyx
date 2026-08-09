import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_router.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

class TraelyxApp extends StatelessWidget {
  const TraelyxApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Traelyx',
      debugShowCheckedModeBanner: false,
      theme: TraelyxTheme.dark,
      routerConfig: router ?? traelyxRouter,
    );
  }
}
