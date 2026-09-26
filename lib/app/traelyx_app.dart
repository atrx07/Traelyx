import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/domain/account_callback.dart';

class TraelyxApp extends StatefulWidget {
  const TraelyxApp({super.key, this.router, this.accountLinks});

  final GoRouter? router;
  final Stream<Uri>? accountLinks;

  @override
  State<TraelyxApp> createState() => _TraelyxAppState();
}

class _TraelyxAppState extends State<TraelyxApp> {
  StreamSubscription<Uri>? _accountLinkSubscription;

  GoRouter get _router => widget.router ?? traelyxRouter;

  @override
  void initState() {
    super.initState();
    _subscribeToAccountLinks();
  }

  @override
  void didUpdateWidget(covariant TraelyxApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountLinks != widget.accountLinks) {
      _accountLinkSubscription?.cancel();
      _subscribeToAccountLinks();
    }
  }

  void _subscribeToAccountLinks() {
    _accountLinkSubscription = widget.accountLinks?.listen((uri) {
      if (isAccountCallback(uri)) _router.go(TraelyxRoutes.youAccount);
    });
  }

  @override
  void dispose() {
    _accountLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Traelyx',
      debugShowCheckedModeBanner: false,
      theme: TraelyxTheme.dark,
      routerConfig: _router,
    );
  }
}
