import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/placeholder_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      for (final entry in appScreens.entries)
        GoRoute(
          path: entry.key,
          builder: (context, state) => PlaceholderScreen(title: entry.value),
        ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Страница не найдена'))),
  );
  ref.onDispose(router.dispose);
  return router;
});
