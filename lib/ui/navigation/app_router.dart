import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/finance_screens.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/snapshots/new',
        redirect: (context, state) => '/snapshots',
      ),
      GoRoute(
        path: '/snapshots/:id',
        builder: (context, state) =>
            SnapshotScreen(id: state.pathParameters['id']!),
      ),
      for (final entry in appScreens.entries.where(
        (e) => e.key != "/snapshots/new",
      ))
        GoRoute(
          path: entry.key,
          builder: (context, state) => FinanceScreen(section: entry.key),
        ),
    ],
    errorBuilder: (context, state) =>
        const Scaffold(body: Center(child: Text('Страница не найдена'))),
  );
  ref.onDispose(router.dispose);
  return router;
});
