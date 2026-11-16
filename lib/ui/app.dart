import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/app_router.dart';
import 'security/session_gate.dart';

class DeltaApp extends ConsumerWidget {
  const DeltaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Delta',
    builder: (context, child) =>
        SessionGate(child: child ?? const SizedBox.shrink()),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
    darkTheme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.teal,
    ),
    routerConfig: ref.watch(appRouterProvider),
  );
}
