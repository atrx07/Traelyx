import 'package:flutter/material.dart';
import 'package:traelyx/app/traelyx_router.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';

class TraelyxApp extends StatelessWidget {
  const TraelyxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Traelyx',
      debugShowCheckedModeBanner: false,
      theme: TraelyxTheme.dark,
      routerConfig: traelyxRouter,
    );
  }
}
