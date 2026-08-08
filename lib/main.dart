import 'package:flutter/material.dart';

void main() {
  runApp(const TraelyxBootstrapApp());
}

class TraelyxBootstrapApp extends StatelessWidget {
  const TraelyxBootstrapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traelyx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('Traelyx bootstrap'))),
    );
  }
}
