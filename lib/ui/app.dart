import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation/app_router.dart';
import 'delta_theme.dart';
import 'theme_settings.dart';
import 'security/session_gate.dart';

class DeltaApp extends ConsumerWidget {
  const DeltaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Delta',
    debugShowCheckedModeBanner: false,
    builder: (context, child) =>
        SessionGate(child: child ?? const SizedBox.shrink()),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: deltaTheme(Brightness.light),
    darkTheme: deltaTheme(Brightness.dark),
    themeMode:
        ref.watch(themePreferenceProvider).value?.mode ?? ThemeMode.system,
    routerConfig: ref.watch(appRouterProvider),
  );
}
