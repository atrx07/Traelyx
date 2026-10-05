import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:traelyx/app/traelyx_router.dart';
import 'package:traelyx/app/traelyx_routes.dart';
import 'package:traelyx/core/theme/traelyx_theme.dart';
import 'package:traelyx/features/account/domain/account_callback.dart';
import 'package:traelyx/features/guardian/guardian_notice_link.dart';

class TraelyxApp extends StatefulWidget {
  const TraelyxApp({super.key, this.router, this.appLinks});

  final GoRouter? router;
  final Stream<Uri>? appLinks;

  @override
  State<TraelyxApp> createState() => _TraelyxAppState();
}

class _TraelyxAppState extends State<TraelyxApp> {
  StreamSubscription<Uri>? _appLinkSubscription;

  GoRouter get _router => widget.router ?? traelyxRouter;

  @override
  void initState() {
    super.initState();
    _subscribeToAppLinks();
  }

  @override
  void didUpdateWidget(covariant TraelyxApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appLinks != widget.appLinks) {
      _appLinkSubscription?.cancel();
      _subscribeToAppLinks();
    }
  }

  void _subscribeToAppLinks() {
    _appLinkSubscription = widget.appLinks?.listen((uri) {
      if (isAccountCallback(uri)) _router.go(TraelyxRoutes.youAccount);
      if (isGuardianNoticeLink(uri)) _router.go(TraelyxRoutes.socialGuardian);
    });
  }

  @override
  void dispose() {
    _appLinkSubscription?.cancel();
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
